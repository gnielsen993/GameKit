//
//  StackGameView.swift
//  gamekit
//
//  Chrome + lifecycle shell for the Stack game. Hosts StackBoardCanvas
//  inside a TimelineView (time source for camera ease + FX), owns the
//  visual-effect state spawned from engine events, drives the arcade loop,
//  wires tap-to-drop input, shows the idle screen and the VideoModeBanner
//  game-over surface, and routes per-drop haptics plus the game-over
//  slow-mo with full settings/Reduce Motion gating.
//
//  Architecture invariants:
//    - Video Mode adopted (ARCADE-08 amendment 2026-07-02): the engine is
//      pure normalized-coordinate and the canvas rescales per frame, so a
//      PiP reflow cannot desync state. Wrapped with .videoModeAware() in
//      HomeView; branch layouts live in StackGameView+VideoMode.swift.
//      Off-path (Video Mode disabled) stays byte-identical (DESIGN §7.6).
//    - scenePhase .inactive AND .background both call vm.pause() (Pitfall P1).
//    - hapticsEnabled is the FIRST guard on both .sensoryFeedback triggers (D-10).
//    - VideoModeBanner fires its own .error haptic — no duplicate here (D-08).
//    - Game-over pre-roll (500ms grayscale drain) runs only when
//      animationsEnabled && !reduceMotion; instant cut otherwise (D-09).
//    - All FX (camera ease, trim fall, pulses, flashes) are gated by
//      animationsEnabled && !reduceMotion — gated off, everything snaps.
//    - NEVER screen shake (any setting, any preset).
//

import SwiftUI
import SwiftData
import DesignKit

struct StackGameView: View {

    // MARK: - Environment

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) var settingsStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.videoModeStore) var videoModeStore
    @Environment(\.dismiss) var dismiss

    // MARK: - View state

    @State var vm = StackViewModel()
    @State private var didInjectStats = false
    @State var showBanner: Bool = false

    // FX state — spawned from engine counter-triggers, drawn by the canvas.
    @State private var lastPlacementAt: Date?
    @State private var fallingPieces: [FallingTrimPiece] = []
    @State private var perfectPulses: [PerfectPulse] = []
    @State private var landingFlash: LandingFlash?
    @State private var settleGlide: SettleGlide?

    var theme: Theme { themeManager.theme(using: colorScheme) }

    /// Single gate for every time-based visual effect (D-09).
    var fxEnabled: Bool { settingsStore.animationsEnabled && !reduceMotion }

    // MARK: - Body

    var body: some View {
        Group {
            if videoModeStore.isEnabled {
                // Large/Small-zone branch layouts — StackGameView+VideoMode.swift.
                videoModeLayout
            } else {
                // Off-path — byte-identical to pre-adoption Stack (DESIGN §7.6).
                coreStack(scoreAlignment: .topTrailing)
                    .navigationTitle(String(localized: "Stack"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { backChevron }
            }
        }
        .navigationBarBackButtonHidden(true)
        // Tap anywhere: starts from idle, drops the block while running.
        .onTapGesture {
            switch vm.state {
            case .idle:    vm.start()
            case .running: vm.pendingDrop = true
            default:       break
            }
        }
        // Arcade loop (CONTEXT D-01 / ArcadeLoopDriver contract)
        .arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt: dt) }
        // Lifecycle — BOTH .inactive and .background pause (Pitfall P1)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:                  vm.resume()
            case .inactive, .background:   vm.pause()
            @unknown default:              vm.pause()
            }
        }
        // Placement → camera ease timestamp + landing flash; restart → clear FX.
        .onChange(of: vm.placed.count) { old, new in
            if new > old {
                let stamp = Date()
                lastPlacementAt = stamp
                if fxEnabled {
                    landingFlash = LandingFlash(rowIndex: new - 1, spawn: stamp)
                }
            } else {
                clearFX()
            }
        }
        // Perfect drop → expanding pulse ring + settle glide from the
        // rendered drop position to the snapped center (no teleport).
        .onChange(of: vm.perfectCount) { _, _ in
            guard fxEnabled, !vm.placed.isEmpty else { return }
            let now = Date()
            perfectPulses = perfectPulses.filter { !$0.isExpired(at: now) }
                + [PerfectPulse(rowIndex: vm.placed.count - 1, spawn: now)]
            settleGlide = SettleGlide(rowIndex: vm.placed.count - 1,
                                      fromCenterX: vm.lastDropCenterX,
                                      fromCenterZ: vm.lastDropCenterZ,
                                      spawn: now)
        }
        // Trim drop → severed overhang piece falls off the tower.
        .onChange(of: vm.dropCount) { _, _ in
            guard fxEnabled, let piece = makeTrimPiece() else { return }
            let now = Date()
            fallingPieces = fallingPieces.filter { !$0.isExpired(at: now) } + [piece]
        }
        // Game-over pre-roll gate (D-09): 500ms before banner when animations on
        .onChange(of: vm.state) { _, newState in
            if newState == .gameOver {
                // The missed block falls off the tower instead of vanishing.
                if fxEnabled, let top = vm.placed.last {
                    let axis = vm.frame.axis
                    let fallsPositive = axis == .x
                        ? vm.lastDropCenterX >= top.centerX
                        : vm.lastDropCenterZ >= top.centerZ
                    fallingPieces.append(FallingTrimPiece(
                        centerX: vm.lastDropCenterX,
                        centerZ: vm.lastDropCenterZ,
                        width: vm.frame.currentWidth,
                        depth: vm.frame.currentDepth,
                        rowIndex: vm.placed.count,
                        axis: axis,
                        fallsPositive: fallsPositive,
                        spawn: Date()
                    ))
                }
                showBanner = false
                if fxEnabled {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        withAnimation(.easeOut(duration: 0.3)) { showBanner = true }
                    }
                } else {
                    showBanner = true  // instant cut (RM or animations off)
                }
            } else if newState == .idle {
                showBanner = false     // reset after restart
            }
        }
        // Counter-trigger haptics — hapticsEnabled is the FIRST guard (D-10)
        .sensoryFeedback(.impact(weight: .medium),
                         trigger: settingsStore.hapticsEnabled ? vm.perfectCount : 0)
        .sensoryFeedback(.impact(weight: .light),
                         trigger: settingsStore.hapticsEnabled ? vm.dropCount : 0)
        // GameStats injection — lazy, one-shot (mirrors MergeGameView.swift:128-133)
        .task {
            guard !didInjectStats else { return }
            didInjectStats = true
            let stats = GameStats(modelContext: modelContext)
            vm.attachGameStats(stats)
        }
    }

    // MARK: - Core stack (shared by off-path + both Video Mode branches)

    /// The game surface: backdrop + board under the game-over grayscale
    /// drain, plus the score overlay / idle card / game-over banner layers.
    ///
    /// - Parameter scoreAlignment: corner for the score+streak overlay;
    ///   `nil` hides it (Large zones — score lives in the compact row).
    /// - Parameter includeBackdrop: `false` on the Large-zone branch, which
    ///   draws the backdrop itself behind the compact row + board VStack.
    @ViewBuilder
    func coreStack(scoreAlignment: Alignment?, includeBackdrop: Bool = true) -> some View {
        ZStack {
            // Board + backdrop share the game-over grayscale drain (D-09).
            Group {
                if includeBackdrop {
                    backdrop
                }
                board
            }
            .grayscale(vm.state == .gameOver ? 1.0 : 0.0)
            .animation(fxEnabled ? .easeOut(duration: 0.5) : nil,
                       value: vm.state == .gameOver)

            // Score + streak overlay — always visible during running and game-over
            if let scoreAlignment, vm.state == .running || vm.state == .gameOver {
                scoreOverlay(alignment: scoreAlignment)
            }

            // Idle / tap-to-start screen (§8.3 explicit empty/idle state)
            if vm.state == .idle {
                idleContent
            }

            // Game-over banner — delayed by pre-roll when animations on.
            // Centered in ALL modes (user override 2026-05-14 — banner
            // placement router intentionally not consumed).
            if showBanner {
                VideoModeBanner(
                    theme: theme,
                    content: gameOverContent,
                    location: videoModeStore.isEnabled ? videoModeStore.location : .largeBottom,
                    hapticsEnabled: settingsStore.hapticsEnabled,
                    reduceMotion: reduceMotion,
                    animationsEnabled: settingsStore.animationsEnabled
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .videoModeBannerTransition(reduceMotion: reduceMotion,
                                           animationsEnabled: settingsStore.animationsEnabled)
            }
        }
    }

    // MARK: - Board + backdrop

    /// TimelineView is the time source for the camera ease and FX. Paused
    /// whenever nothing time-based can be animating — idle, banner shown,
    /// or FX gated off — so it never burns frames for a static board.
    ///
    /// The canvas always extends UNDER the bottom safe-area inset — the
    /// home indicator in normal mode, plus the reserved video band in Video
    /// Mode large-bottom — and receives that inset as `bottomObscured`.
    /// Gameplay framing anchors to the logical height above it while the
    /// tower pedestal paints down to the physical screen bottom, so no mode
    /// leaves a background strip under the board.
    var board: some View {
        GeometryReader { proxy in
            let obscured = proxy.safeAreaInsets.bottom
            TimelineView(.animation(paused: !fxEnabled || vm.state == .idle || showBanner)) { tl in
                StackBoardCanvas(
                    placed: vm.placed,
                    frame: vm.frame,
                    prevCenterX: vm.prevCenterX,
                    prevCenterZ: vm.prevCenterZ,
                    accAlpha: vm.accumulatorAlpha,
                    theme: theme,
                    now: tl.date,
                    fxEnabled: fxEnabled,
                    reduceMotion: reduceMotion,
                    lastPlacementAt: lastPlacementAt,
                    fallingPieces: fallingPieces,
                    perfectPulses: perfectPulses,
                    landingFlash: landingFlash,
                    settleGlide: settleGlide,
                    bottomObscured: obscured
                )
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    /// Sky gradient derived from the tower's current palette layer over the
    /// background token — shifts hue gently as the tower climbs (all token
    /// colors; opacity-only derivation).
    var backdrop: some View {
        let sky = StackPalette.layer(forIndex: max(vm.placed.count - 1, 0),
                                     theme: theme).base
        return LinearGradient(
            stops: [
                .init(color: sky.opacity(0.22), location: 0.0),
                .init(color: sky.opacity(0.06), location: 0.45),
                .init(color: theme.colors.textPrimary.opacity(0.0), location: 0.7),
                .init(color: theme.colors.textPrimary.opacity(0.07), location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .background(theme.colors.background)
        .ignoresSafeArea()
        .animation(fxEnabled ? .easeInOut(duration: 0.8) : nil,
                   value: vm.placed.count / StackPalette.blocksPerStop)
    }

    // MARK: - FX helpers

    /// Builds the severed-overhang piece from the latest trim drop. Reads the
    /// VM's latched `lastTrimOverhang` / `lastTrimAxis` — NOT `frame.event`,
    /// which a second engine step in the same tick can overwrite with .none
    /// before this onChange runs. The trimmed block's center sits toward the
    /// drop side of the reference block along the trim axis, which tells us
    /// which edge broke off.
    private func makeTrimPiece() -> FallingTrimPiece? {
        let overhang = vm.lastTrimOverhang
        guard overhang > 0, vm.placed.count >= 2 else { return nil }
        let trimmed = vm.placed[vm.placed.count - 1]
        let ref     = vm.placed[vm.placed.count - 2]
        let axis    = vm.lastTrimAxis

        if axis == .x {
            let fallsPositive = trimmed.centerX >= ref.centerX
            let pieceCenter = fallsPositive
                ? trimmed.centerX + trimmed.width / 2 + overhang / 2
                : trimmed.centerX - trimmed.width / 2 - overhang / 2
            return FallingTrimPiece(centerX: pieceCenter, centerZ: trimmed.centerZ,
                                    width: overhang, depth: trimmed.depth,
                                    rowIndex: vm.placed.count - 1,
                                    axis: .x, fallsPositive: fallsPositive,
                                    spawn: Date())
        } else {
            let fallsPositive = trimmed.centerZ >= ref.centerZ
            let pieceCenter = fallsPositive
                ? trimmed.centerZ + trimmed.depth / 2 + overhang / 2
                : trimmed.centerZ - trimmed.depth / 2 - overhang / 2
            return FallingTrimPiece(centerX: trimmed.centerX, centerZ: pieceCenter,
                                    width: trimmed.width, depth: overhang,
                                    rowIndex: vm.placed.count - 1,
                                    axis: .z, fallsPositive: fallsPositive,
                                    spawn: Date())
        }
    }

    private func clearFX() {
        lastPlacementAt = nil
        fallingPieces = []
        perfectPulses = []
        landingFlash = nil
        settleGlide = nil
    }

}
