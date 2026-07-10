//
//  SnakeGameView.swift
//  gamekit
//
//  Chrome + lifecycle shell for the Snake game. Hosts SnakeBoardCanvas inside
//  a TimelineView (SwiftUI time source for 60 fps canvas redraws), drives the
//  arcade loop, wires swipe + D-pad steering, shows the idle screen and the
//  VideoModeBanner game-over surface, routes per-event haptics and the 500ms
//  pre-roll with full settings/Reduce Motion gating.
//
//  Architecture invariants:
//    - Video Mode adopted (exemption lifted 2026-07-09; see 15-VIDEO-MODE-ADR.md
//      amendment). The old "pixel-derived grid" rationale was stale — SnakeConfig
//      defines a FIXED logical 20×32 grid and SnakeBoardCanvas derives cellSize
//      from its own size per frame, so a PiP band reflow only rescales the render
//      and cannot desync engine state (same property that lifted Stack's
//      exemption). Wrapped with .videoModeAware() in HomeView; branch layouts in
//      SnakeGameView+VideoMode.swift. Off-path stays byte-identical (DESIGN §7.6).
//    - scenePhase .inactive AND .background both call vm.pause() (Common Pitfall 2).
//    - hapticsEnabled is the FIRST guard on all three .sensoryFeedback triggers.
//    - VideoModeBanner fires its own .error haptic — no duplicate here.
//    - Game-over pre-roll (500ms grayscale drain) runs only when
//      animationsEnabled && !reduceMotion; instant cut otherwise (DESIGN §10.3).
//    - .defersSystemGestures(on: .all) on the board prevents the system from
//      claiming a left-edge swipe as a navigation-pop gesture (SC1).
//    - NEVER screen shake (any setting, any preset — DESIGN.md D-10 brand rule).
//

import SwiftUI
import SwiftData
import DesignKit

struct SnakeGameView: View {

    // MARK: - Environment

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) var settingsStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dismiss) var dismiss
    @Environment(\.videoModeStore) var videoModeStore

    // MARK: - View state

    @State var vm = SnakeViewModel()
    @State private var didInjectStats = false
    @State var showBanner: Bool = false
    /// D-08 head pulse: 0 = rest, 1 = peak. Animated 1→0 over ~150ms on eatCount.
    @State private var headPulse: Double = 0

    var theme: Theme { themeManager.theme(using: colorScheme) }
    /// Master gate for time-based FX (animations setting + Reduce Motion — DESIGN §10.2).
    var fxEnabled: Bool { settingsStore.animationsEnabled && !reduceMotion }

    // MARK: - Body

    var body: some View {
        Group {
            if videoModeStore.isEnabled {
                // Zone branch layouts — SnakeGameView+VideoMode.swift.
                videoModeLayout
            } else {
                // Off-path — byte-identical to pre-adoption Snake (DESIGN §7.6).
                standardLayout()
            }
        }
        .navigationBarBackButtonHidden(true)
        // Arcade loop (ArcadeLoopDriver contract — ARCADE-02; no second dt clamp)
        .arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt: dt) }
        // Scene phase: BOTH .inactive AND .background call vm.pause() (Common Pitfall 2:
        // notification banners trigger .inactive, not .background)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:                  vm.resume()
            case .inactive, .background:   vm.pause()
            @unknown default:              vm.pause()
            }
        }
        // Game-over pre-roll gate (DESIGN §10.3): 500ms before banner when animations on
        .onChange(of: vm.state) { _, newState in
            if newState == .gameOver {
                showBanner = false
                if fxEnabled {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        withAnimation(.easeOut(duration: 0.3)) { showBanner = true }
                    }
                } else {
                    showBanner = true   // instant cut under RM or animations off
                }
            } else if newState == .idle {
                showBanner = false      // reset after restart
            }
        }
        // D-08 head pulse: 1→0 over ~150ms when food is eaten, gated by fxEnabled
        .onChange(of: vm.eatCount) { _, _ in
            guard fxEnabled && !reduceMotion else { return }
            headPulse = 1
            withAnimation(.easeOut(duration: 0.15)) { headPulse = 0 }
        }
        // Counter-trigger haptics — hapticsEnabled is the FIRST guard (DESIGN §8.2)
        // D-08: food eat → .impact(weight: .light, intensity: 0.7)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7),
                         trigger: settingsStore.hapticsEnabled ? vm.eatCount : 0)
        // D-07: direction enqueue (accepted only) → .selection
        .sensoryFeedback(.selection,
                         trigger: settingsStore.hapticsEnabled ? vm.enqueueCount : 0)
        // D-09: new high score mid-run (once per run) → .impact(weight: .medium, intensity: 1.0)
        .sensoryFeedback(.impact(weight: .medium, intensity: 1.0),
                         trigger: settingsStore.hapticsEnabled ? vm.highScoreCount : 0)
        // GameStats injection — lazy, one-shot (mirrors StackGameView / MergeGameView)
        .task {
            guard !didInjectStats else { return }
            didInjectStats = true
            let stats = GameStats(modelContext: modelContext)
            vm.attachGameStats(stats)
        }
        // Abandon alert — wall-mode toggle with an in-progress run (D-11)
        .alert(String(localized: "Abandon current game?"),
               isPresented: Bindable(vm).showingAbandonAlert) {
            Button(String(localized: "Cancel"), role: .cancel) {
                vm.cancelWallModeChange()
            }
            Button(String(localized: "Abandon"), role: .destructive) {
                vm.confirmWallModeChange()
            }
        } message: {
            Text(String(localized: "Switching modes resets the run. Your current score will be lost."))
        }
    }

    // MARK: - Standard layout (off-path + unobstructed Video Mode zones)

    /// The off-path chrome: nav bar (back chevron leading, wall-mode menu
    /// trailing), trailing score chip, board, D-pad. Video Mode zones whose
    /// PiP leaves this chrome unobstructed reuse it verbatim (necessity
    /// principle — DESIGN §7.7); small-top zones pass a moved placement for
    /// only the element their PiP corner actually covers.
    func standardLayout(scoreOnLeading: Bool = false,
                        backPlacement: ToolbarItemPlacement = .topBarLeading,
                        menuPlacement: ToolbarItemPlacement = .topBarTrailing) -> some View {
        coreContent(scoreOnLeading: scoreOnLeading)
            .navigationTitle(String(localized: "Snake"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: backPlacement) { backButton }
                ToolbarItem(placement: menuPlacement) { wallModeMenu }
            }
    }

    // MARK: - Core content (shared by off-path + all Video Mode branches)

    /// The game surface: background, info row, board, D-pad, idle card, and
    /// game-over banner.
    ///
    /// - Parameter scoreOnLeading: info-row side for the score chip —
    ///   `.smallTopRight` moves it leading because its PiP covers the
    ///   trailing corner; every other path keeps the off-path trailing side.
    /// - Parameter showScoreRow: `false` on the Large-top branch, where the
    ///   score lives in the compact row instead.
    /// - Parameter includeCompactRow: `true` on the Large-top branch only —
    ///   appends `compactRowComposed` under the D-pad at the bottom edge
    ///   (opposite the reserved band, DESIGN §7.1).
    @ViewBuilder
    func coreContent(scoreOnLeading: Bool = false,
                     showScoreRow: Bool = true,
                     includeCompactRow: Bool = false) -> some View {
        ZStack {
            // 1. Background
            theme.colors.background.ignoresSafeArea()

            // 2. Main layout: info row → board → D-pad (DESIGN §5.1 skeleton)
            VStack(spacing: theme.spacing.s) {
                // Info row: score chip (DESIGN §5.2 — separate header row for score;
                // Snake has no timer or lives, so score is the sole info element).
                // Hidden during idle so the start card is uncluttered.
                if showScoreRow, vm.state == .running || vm.state == .gameOver {
                    HStack {
                        if !scoreOnLeading { Spacer() }
                        SnakeScoreChip(theme: theme, score: vm.frame.score)
                        if scoreOnLeading { Spacer() }
                    }
                    .padding(.horizontal, theme.spacing.m)
                }

                boardArea
                    .padding(.horizontal, theme.spacing.m)

                // D-pad occupies the mode-pill slot (DESIGN §5.4).
                // Always visible; each button is a silent no-op for reverse
                // direction (queue rule rejects 180° in the VM — D-07).
                SnakeDPad(theme: theme) { dir in
                    vm.handleDirectionInput(dir)
                }

                if includeCompactRow {
                    compactRowComposed
                }
            }
            .padding(.bottom, theme.spacing.l)

            // 3. Idle / tap-to-start screen (DESIGN §8.3 explicit idle state)
            // The card overlays the board and would swallow drags, so it
            // carries the same swipe gesture — "Swipe … to start" must work
            // when the swipe lands on the card itself.
            if vm.state == .idle {
                idleContent
                    .gesture(swipeGesture)
            }

            // 4. Game-over banner — 500ms pre-roll when animations on (DESIGN §10.3)
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

    // MARK: - Board area

    /// Board canvas with swipe gesture and grayscale drain.
    /// Score chip lives in the info row above the board — never overlaid here
    /// (DESIGN §5.2: score goes in a separate header row, board unobstructed).
    ///
    /// The TimelineView drives 60 fps canvas redraws when the loop is running.
    /// Pausing it when idle / showing the banner prevents wasted GPU frames for
    /// a static board.
    ///
    /// The board is constrained to the 20:32 grid aspect ratio so SnakeBoardCanvas
    /// always receives a canvas whose dimensions match the cell layout — cells
    /// render at `cellSize = size.width / cols`, grid height = `cellSize × rows`.
    var boardArea: some View {
        ZStack {
            Group {
                TimelineView(.animation(paused: !fxEnabled || vm.state == .idle || showBanner)) { _ in
                    SnakeBoardCanvas(
                        snakeBody: vm.frame.body,
                        prevBody: vm.prevBody,
                        cellMoveAlpha: vm.frame.cellMoveAlpha,
                        food: vm.frame.food,
                        currentDirection: vm.frame.currentDirection,
                        theme: theme,
                        reduceMotion: reduceMotion,
                        fxEnabled: fxEnabled,
                        cols: SnakeConfig.default.cols,
                        rows: SnakeConfig.default.rows,
                        headPulse: headPulse
                    )
                }
            }
            .grayscale(vm.state == .gameOver ? 1.0 : 0.0)
            .animation(fxEnabled ? .easeOut(duration: 0.5) : nil, value: vm.state == .gameOver)
            // Swipe gesture: dominant axis maps to direction (DESIGN Pattern 5)
            .gesture(swipeGesture)
            // SC1: board claims all swipes so the system cannot interpret a
            // left-edge swipe as a navigation-pop back-gesture.
            .defersSystemGestures(on: .all)

        }
        // Constrain to 20:32 grid proportions so cellSize = size.width / cols
        // gives a board height exactly equal to cellSize × rows (no blank strip).
        .aspectRatio(
            CGFloat(SnakeConfig.default.cols) / CGFloat(SnakeConfig.default.rows),
            contentMode: .fit
        )
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }

    /// Shared swipe recognizer — attached to both the board and the idle card
    /// (the card overlays the board, so it must handle swipe-to-start itself).
    /// One enqueue per completed drag: .onEnded only, never .onChanged.
    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    vm.handleDirectionInput(dx > 0 ? .right : .left)
                } else {
                    vm.handleDirectionInput(dy > 0 ? .down : .up)
                }
            }
    }
}
