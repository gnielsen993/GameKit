//
//  StackGameView.swift
//  gamekit
//
//  Chrome + lifecycle shell for the Stack game. Hosts StackBoardCanvas,
//  drives the arcade loop, wires tap-to-drop input, shows the idle screen
//  and the VideoModeBanner game-over surface, and routes per-drop haptics
//  plus the game-over slow-mo with full settings/Reduce Motion gating.
//
//  Plan 16-05 — replaces StackHarnessView (throwaway, deleted this plan).
//
//  Architecture invariants:
//    - No .videoModeAware() — real-time games are Video Mode exempt (ARCADE-08).
//    - scenePhase .inactive AND .background both call vm.pause() (Pitfall P1).
//    - hapticsEnabled is the FIRST guard on both .sensoryFeedback triggers (D-10).
//    - VideoModeBanner fires its own .error haptic — no duplicate here (D-08).
//    - Game-over pre-roll (500ms grayscale drain) runs only when
//      animationsEnabled && !reduceMotion; instant cut otherwise (D-09).
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
    @Environment(\.dismiss) private var dismiss

    // MARK: - View state

    @State private var vm = StackViewModel()
    @State private var didInjectStats = false
    @State private var prevCenterX: Double = StackConfig.default.playfieldCenter
    @State private var showBanner: Bool = false

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    // MARK: - Body

    var body: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            StackBoardCanvas(
                placed: vm.placed,
                frame: vm.frame,
                prevCenterX: prevCenterX,
                accAlpha: vm.accumulatorAlpha,
                theme: theme,
                reduceMotion: reduceMotion
            )
            // Color-drain pre-roll: desaturate on game-over (D-09).
            // Animated when animationsEnabled && !reduceMotion; instant cut otherwise.
            .grayscale(vm.state == .gameOver ? 1.0 : 0.0)
            .animation(
                (settingsStore.animationsEnabled && !reduceMotion)
                    ? .easeOut(duration: 0.5) : nil,
                value: vm.state == .gameOver
            )

            // Score + streak overlay — always visible during running and game-over
            if vm.state == .running || vm.state == .gameOver {
                scoreOverlay
            }

            // Idle / tap-to-start screen (§8.3 explicit empty/idle state)
            if vm.state == .idle {
                idleContent
            }

            // Game-over banner — delayed by pre-roll when animations on
            if showBanner {
                VideoModeBanner(
                    theme: theme,
                    content: gameOverContent,
                    location: .largeBottom,
                    hapticsEnabled: settingsStore.hapticsEnabled,
                    reduceMotion: reduceMotion,
                    animationsEnabled: settingsStore.animationsEnabled
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .videoModeBannerTransition(reduceMotion: reduceMotion,
                                           animationsEnabled: settingsStore.animationsEnabled)
            }
        }
        // Tap drops the block during running state; idle state button handles its own tap.
        .onTapGesture {
            if vm.state == .running { vm.pendingDrop = true }
        }
        .navigationTitle(String(localized: "Stack"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { backChevron }
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
        // Track prevCenterX for Gaffer interpolation in StackBoardCanvas
        .onChange(of: vm.frame.currentCenterX) { old, _ in
            prevCenterX = old
        }
        // Game-over pre-roll gate (D-09): 500ms before banner when animations on
        .onChange(of: vm.state) { _, newState in
            if newState == .gameOver {
                showBanner = false
                if settingsStore.animationsEnabled && !reduceMotion {
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

    // MARK: - Game-over banner content

    private var gameOverContent: VideoModeBannerContent {
        VideoModeBannerContent(
            outcome: .loss,
            title: String(localized: "Game over"),
            subtitle: nil,
            primaryButtonLabel: String(localized: "Restart"),
            accessibilityLabel: String(
                format: String(localized: "Game over. Score %d. Restart"),
                vm.frame.score
            ),
            onPrimary: {
                vm.restart()
                showBanner = false
            }
        )
    }

    // MARK: - Chrome overlays

    /// Score chip (top-trailing) + visible streak counter (D-04).
    @ViewBuilder private var scoreOverlay: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: theme.spacing.xs) {
                    Text("\(vm.frame.score)")
                        .font(theme.typography.title.monospacedDigit())
                        .foregroundStyle(theme.colors.textPrimary)
                    if vm.frame.streak > 0 {
                        Text(String(localized: "Streak: \(vm.frame.streak)"))
                            .font(theme.typography.caption.monospacedDigit())
                            .foregroundStyle(theme.colors.accentPrimary)
                    }
                }
                .padding(theme.spacing.m)
            }
            Spacer()
        }
    }

    /// Idle / tap-to-start screen — shown before the first tap and after restart.
    @ViewBuilder private var idleContent: some View {
        VStack(spacing: theme.spacing.l) {
            Text(String(localized: "Stack"))
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)
            Text(String(localized: "Tap to start"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
            Button(String(localized: "Start")) {
                vm.start()
            }
            .font(theme.typography.headline)
            .foregroundStyle(theme.colors.accentPrimary)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var backChevron: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Back to The Drawer"))
        }
    }
}
