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
                    onTap: { viewModel.reveal(at: $0) },
                    onLongPress: { viewModel.toggleFlag(at: $0) }
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
                    LinearKeyframe(0.0, duration: 0.0)
                    LinearKeyframe(8.0, duration: 0.1)
                    LinearKeyframe(-8.0, duration: 0.1)
                    LinearKeyframe(4.0, duration: 0.1)
                    LinearKeyframe(0.0, duration: 0.1)
                }
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

            // End-state overlay — terminal state only (D-02 + D-18: no animation in P3)
            if let outcome = viewModel.terminalOutcome {
                endStateOverlay(outcome: outcome)
            }
        }
        .navigationTitle(String(localized: "Minesweeper"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.restart()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(theme.colors.textPrimary)
                }
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
            case .lossShake:
                Haptics.playAHAP(named: "loss", hapticsEnabled: settingsStore.hapticsEnabled)
                sfxPlayer.play(.loss, sfxEnabled: settingsStore.sfxEnabled)
            case .revealing:
                sfxPlayer.play(.tap, sfxEnabled: settingsStore.sfxEnabled)
            case .idle, .flagging:
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
                    // CONTEXT D-03 (refined W-02): "Change difficulty" calls restart()
                    // for fresh idle at the same difficulty. The user changes the
                    // difficulty itself by tapping the trailing toolbar Menu.
                    // P3 ships the simplest path; sheet-presented difficulty picker
                    // deferred to P5 polish.
                    viewModel.restart()
                }
            )
        }
    }
}
