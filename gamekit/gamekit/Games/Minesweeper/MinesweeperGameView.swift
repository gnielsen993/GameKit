//
//  MinesweeperGameView.swift
//  gamekit
//
//  Top-level Minesweeper game scene. The ONLY view in Games/Minesweeper/
//  that consumes @EnvironmentObject themeManager + @Environment(\.scenePhase) +
//  @Environment(\.colorScheme); child views (HeaderBar, BoardView, CellView,
//  ToolbarMenu, EndStateCard) receive `theme: Theme` as a let parameter
//  (RESEARCH §Anti-Patterns "Re-fetching theme tokens inside cell views").
//
//  Phase 3 invariants (per D-06, D-10, D-12, RESEARCH Pitfall 1+2):
//    - VM owned via @State (iOS 17 idiom; @StateObject incompatible with @Observable)
//    - scenePhase: .background → vm.pause(); .active → vm.resume();
//      .inactive → no-op (Pitfall 2 — control-center pulls / lock-screen flashes
//      should NOT pause the timer)
//    - End-state overlay sits in a ZStack with a theme.colors.background.opacity(0.85)
//      backdrop — NOT a sheet/fullScreenCover; D-02 forbids tap-to-dismiss
//    - .alert(isPresented: $viewModel.showingAbandonAlert) drives the D-10 mid-game
//      abandon flow (Cancel = vm.cancelDifficultyChange; Abandon = vm.confirmDifficultyChange)
//    - NavigationStack is owned by HomeView (per ARCHITECTURE Anti-Pattern 3 — no nested);
//      this view is pushed via NavigationLink from HomeView (Plan 04 Task 3)
//
//  Phase 4 invariants (per D-14, D-15, RESEARCH Pitfall 8):
//    - GameStats injected lazily via .task (NOT inside body — Pitfall 8
//      forbids per-render allocation of GameStats + its os.Logger)
//    - Once-per-scene guard via @State didInjectStats
//    - VM is the SwiftData firewall — view imports SwiftData only for
//      @Environment(\.modelContext); GameStats(modelContext:) construction
//      and viewModel.attachGameStats(stats) call site live in this view's
//      .task — VM never sees the modelContext directly
//
//  iOS 17.0/17.1 @State-with-reference-type leak acknowledged (RESEARCH Pitfall 1):
//  one VM instance (~few KB) leaks per game-screen dismiss; not worth a
//  @StateObject shim that fights @Observable. Fixed in iOS 17.2+.
//

import SwiftUI
import SwiftData
import DesignKit

struct MinesweeperGameView: View {
    @State private var viewModel: MinesweeperViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var didInjectStats = false           // one-shot guard (RESEARCH Pitfall 8)
    @State private var showDifficultyPicker = false      // P7 polish (kink #4)
    @Environment(\.dismiss) private var dismiss

    // End-of-game choreography (gated on settingsStore.animationsEnabled).
    // - Loss: mines wave outward from trip cell → wrong flags pop → end card.
    // - Win:  confetti for a beat → end card.
    // When animations are off (or Reduce Motion is on), all flags flip true
    // immediately so the end card lands without a pre-roll.
    @State private var lossMinesRevealed = false
    @State private var lossWrongFlagsPopped = false
    @State private var endCardVisible = false
    @State private var showConfetti = false

    // P5 (D-04/D-07/D-08) — animation/haptics/SFX environment reads.
    // accessibilityReduceMotion gates ALL animation surfaces per D-04.
    // settingsStore + sfxPlayer flow into the locked Plan 05-03
    // call-site contract: Haptics.playAHAP(named:hapticsEnabled:) +
    // sfxPlayer.play(_:sfxEnabled:) on .onChange(of: viewModel.phase).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.sfxPlayer) private var sfxPlayer

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    init() {
        _viewModel = State(initialValue: MinesweeperViewModel())
    }

    var body: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                MinesweeperHeaderBar(
                    theme: theme,
                    minesRemaining: viewModel.minesRemaining,
                    timerAnchor: viewModel.timerAnchor,
                    pausedElapsed: viewModel.pausedElapsed
                )

                MinesweeperBoardView(
                    theme: theme,
                    board: viewModel.board,
                    gameState: viewModel.gameState,
                    phase: viewModel.phase,
                    hapticsEnabled: settingsStore.hapticsEnabled,
                    reduceMotion: reduceMotion,
                    revealCount: viewModel.revealCount,
                    flagToggleCount: viewModel.flagToggleCount,
                    lossMinesRevealed: lossMinesRevealed,
                    lossWrongFlagsPopped: lossWrongFlagsPopped,
                    lossTripIdx: tripCellIndex,
                    onTap: { viewModel.handleTap(at: $0) },
                    onLongPress: { viewModel.handleLongPress(at: $0) }
                )
                // P5 D-03: 4-keyframe horizontal loss shake. Magnitude 8pt
                // locked by CONTEXT D-03 (animation amplitude, not layout
                // — exempt from FOUND-07 spacing-token rule). Reduce Motion
                // → trigger `false` so keyframes never fire.
                .keyframeAnimator(
                    initialValue: 0.0,
                    trigger: reduceMotion ? false : viewModel.phase.isLossShake
                ) { content, value in
                    content.offset(x: value)
                } keyframes: { _ in
                    LinearKeyframe(8.0, duration: 0.1)
                    LinearKeyframe(-8.0, duration: 0.1)
                    LinearKeyframe(4.0, duration: 0.1)
                    LinearKeyframe(0.0, duration: 0.1)
                }

                // P6.1 (MINES-12) — Reveal/Flag pill flipper.
                // Two-segment pill, current mode highlighted. Replaces prior
                // single circular FAB.
                MinesweeperModePill(
                    theme: theme,
                    mode: viewModel.interactionMode,
                    onSelect: { viewModel.setInteractionMode($0) }
                )
                .padding(.top, theme.spacing.s)
                .opacity(viewModel.terminalOutcome == nil ? 1 : 0)
                .allowsHitTesting(viewModel.terminalOutcome == nil)
                .sensoryFeedback(
                    .impact(weight: .light),
                    trigger: settingsStore.hapticsEnabled ? viewModel.modeToggleCount : 0
                )
            }

            // P5 D-02: full-board win sweep — success-tint wash via
            // .phaseAnimator. Sits ABOVE the board cells but BELOW the
            // end-state DKCard so the user can interact with Restart
            // without the wash blocking taps (.allowsHitTesting(false)
            // also enforces this). Reduce Motion → single phase [0.0]
            // emits no fade.
            Rectangle()
                .fill(theme.colors.success)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .phaseAnimator(
                    reduceMotion ? [0.0] : [0.0, 0.25, 0.0],
                    trigger: viewModel.phase == .winSweep
                ) { content, alpha in
                    content.opacity(alpha)
                } animation: { _ in
                    .easeInOut(duration: theme.motion.slow)
                }

            // Confetti — fires on win for a beat before the end card lands.
            // Always rendered above the win-sweep wash and below the end card.
            // Driven by `showConfetti` which the win-orchestration Task flips.
            if showConfetti {
                ConfettiView(theme: theme)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // End-state overlay — gated on `endCardVisible` so the loss
            // cascade / win confetti finish their pre-roll first.
            if let outcome = viewModel.terminalOutcome, endCardVisible {
                endStateOverlay(outcome: outcome)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .navigationTitle(String(localized: "Minesweeper"))
        .navigationBarTitleDisplayMode(.inline)
        // 2026-05-01: Hide the system back chevron + edge-swipe-to-go-back
        // gesture so cell long-press / pinch-to-zoom interactions near the
        // left edge don't get hijacked. Custom back ToolbarItem below is
        // the only path off this screen (besides win/loss → Home from the
        // end-state card). Matches MergeGameView for cross-game consistency.
        .navigationBarBackButtonHidden(true)
        .toolbar {
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
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.restart()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Restart game"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                MinesweeperToolbarMenu(
                    theme: theme,
                    currentDifficulty: viewModel.difficulty,
                    onSelect: { viewModel.requestDifficultyChange($0) }
                )
            }
        }
        .alert(
            String(localized: "Abandon current game?"),
            isPresented: $viewModel.showingAbandonAlert
        ) {
            Button(String(localized: "Cancel"), role: .cancel) {
                viewModel.cancelDifficultyChange()
            }
            Button(String(localized: "Abandon"), role: .destructive) {
                viewModel.confirmDifficultyChange()
            }
        } message: {
            Text(String(localized: "Your in-progress game will be lost."))
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.pause()                       // D-06
            case .active:
                viewModel.resume()                      // D-06
            case .inactive:
                break                                   // RESEARCH Pitfall 2 — no-op
            @unknown default:
                break
            }
        }
        // P5 D-07/D-08 — Haptics + SFX orchestration on the locked Plan
        // 05-03 call-site contract. BOTH services gate at the source on
        // the SettingsStore flag passed explicitly — view ships no
        // conditional branching of its own.
        // - .winSweep / .lossShake → AHAP via Haptics.playAHAP + SFX
        // - .revealing → tap SFX only (cell haptic fires via
        //   .sensoryFeedback(.selection) on CellView per D-07; no
        //   duplicate haptic call here)
        // - .idle / .flagging → no AHAP / SFX cue (flag haptic fires
        //   via .sensoryFeedback(.impact(.light)) on CellView)
        // Side-effect contract: this handler MUST NOT mutate VM state —
        // a phase change inside the handler would loop (T-05-19 mitigation).
        .onChange(of: viewModel.phase) { _, newPhase in
            switch newPhase {
            case .winSweep:
                Haptics.playAHAP(named: "win", hapticsEnabled: settingsStore.hapticsEnabled)
                sfxPlayer.play(.win, sfxEnabled: settingsStore.sfxEnabled)
                runWinChoreography()
            case .lossShake:
                Haptics.playAHAP(named: "loss", hapticsEnabled: settingsStore.hapticsEnabled)
                sfxPlayer.play(.loss, sfxEnabled: settingsStore.sfxEnabled)
                runLossChoreography()
            case .revealing:
                sfxPlayer.play(.tap, sfxEnabled: settingsStore.sfxEnabled)
            case .idle:
                // Restart resets to .idle — clear all choreography flags so
                // the next session's end-state lands clean.
                lossMinesRevealed = false
                lossWrongFlagsPopped = false
                endCardVisible = false
                showConfetti = false
            case .flagging:
                break
            }
        }
        .task {
            // Plan 04-05 Task 2 — one-shot GameStats injection (RESEARCH Pitfall 8).
            // GameStats(modelContext:) MUST NOT live inside body — that would
            // construct a new instance + new os.Logger on every render.
            guard !didInjectStats else { return }
            didInjectStats = true
            let stats = GameStats(modelContext: modelContext)
            viewModel.attachGameStats(stats)
        }
    }

    // MARK: - End-state overlay (D-01 + D-02 — no tap-to-dismiss; D-18 — no animation P3)

    @ViewBuilder
    private func endStateOverlay(outcome: GameOutcome) -> some View {
        ZStack {
            // Backdrop — covers full board AREA but does NOT consume taps
            // (the card itself owns the only tap targets per D-02).
            Rectangle()
                .fill(theme.colors.background.opacity(0.85))
                .ignoresSafeArea()
                .accessibilityHidden(true)

            MinesweeperEndStateCard(
                theme: theme,
                outcome: outcome,
                elapsed: viewModel.frozenElapsed,
                lossContext: viewModel.lossContext,
                onRestart: { viewModel.restart() },
                onChangeDifficulty: {
                    // P7 polish (kink #4): the original D-03 W-02 path called
                    // restart() and required the user to find the toolbar menu
                    // to actually change difficulty — confusing because the
                    // button literally says "Change difficulty". Now we surface
                    // the same difficulty list the toolbar menu uses, via a
                    // native confirmationDialog (declared on the GameView body).
                    showDifficultyPicker = true
                }
            )
        }
        .confirmationDialog(
            String(localized: "Change difficulty"),
            isPresented: $showDifficultyPicker,
            titleVisibility: .visible
        ) {
            ForEach(MinesweeperDifficulty.allCases, id: \.self) { difficulty in
                Button(difficultyDisplayName(difficulty)) {
                    viewModel.requestDifficultyChange(difficulty)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) { }
        }
    }

    private func difficultyDisplayName(_ d: MinesweeperDifficulty) -> String {
        switch d {
        case .easy:   return String(localized: "Easy")
        case .medium: return String(localized: "Medium")
        case .hard:   return String(localized: "Hard")
        }
    }

    // MARK: - End-of-game choreography

    /// Trip-mine index drives the loss-wave origin (chebyshev distance per
    /// cell). nil outside loss states.
    private var tripCellIndex: MinesweeperIndex? {
        if case .lost(let idx) = viewModel.gameState { return idx }
        return nil
    }

    /// Loss sequence: cascade reveal mines from trip cell → pop wrong flags
    /// → show end card. Skipped when animations are off; everything flips
    /// true atomically so the card lands without a pre-roll.
    private func runLossChoreography() {
        let animate = settingsStore.animationsEnabled && !reduceMotion
        guard animate else {
            lossMinesRevealed = true
            lossWrongFlagsPopped = true
            endCardVisible = true
            return
        }
        Task { @MainActor in
            // Mines wave outward — per-cell delay computed in CellView from
            // chebyshev distance to the trip cell. Wave duration ≈ 1.0s for
            // a 24-row Hard board (max chebyshev × 0.045 capped at 1.2s).
            lossMinesRevealed = true
            try? await Task.sleep(for: .milliseconds(900))
            // Wrong flags pop with a spring scale.
            lossWrongFlagsPopped = true
            try? await Task.sleep(for: .milliseconds(450))
            // End card slides in (the .transition on the conditional view
            // owns the easing — we just flip the gate).
            withAnimation(.easeOut(duration: 0.3)) {
                endCardVisible = true
            }
        }
    }

    /// Win sequence: confetti for a beat → end card. Skipped when animations
    /// are off; end card lands immediately.
    private func runWinChoreography() {
        let animate = settingsStore.animationsEnabled && !reduceMotion
        guard animate else {
            endCardVisible = true
            return
        }
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.2)) {
                showConfetti = true
            }
            // Hold the confetti for ~1.2s so the user reads the celebration
            // before the card overlays it.
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeOut(duration: 0.3)) {
                endCardVisible = true
            }
            // Let confetti continue falling under the card for another beat,
            // then fade it out so the end-card composition is clean.
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.easeIn(duration: 0.5)) {
                showConfetti = false
            }
        }
    }
}
