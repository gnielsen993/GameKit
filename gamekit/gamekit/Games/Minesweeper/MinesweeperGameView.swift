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
    @State var viewModel: MinesweeperViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var didInjectStats = false           // one-shot guard (RESEARCH Pitfall 8)
    @State private var showDifficultyPicker = false      // P7 polish (kink #4)
    @Environment(\.dismiss) var dismiss

    // End-of-game choreography (gated on settingsStore.animationsEnabled).
    // - Loss: mines wave outward from trip cell → wrong flags pop → end card.
    // - Win:  confetti for a beat → end card.
    // When animations are off (or Reduce Motion is on), all flags flip true
    // immediately so the end card lands without a pre-roll.
    @State var lossMinesRevealed = false
    @State var lossWrongFlagsPopped = false
    @State var endCardVisible = false
    @State var showConfetti = false

    // P5 (D-04/D-07/D-08) — animation/haptics/SFX environment reads.
    // accessibilityReduceMotion gates ALL animation surfaces per D-04.
    // settingsStore + sfxPlayer flow into the locked Plan 05-03
    // call-site contract: Haptics.playAHAP(named:hapticsEnabled:) +
    // sfxPlayer.play(_:sfxEnabled:) on .onChange(of: viewModel.phase).
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.settingsStore) var settingsStore
    @Environment(\.sfxPlayer) private var sfxPlayer

    // P11 D-01/D-02 (Plan 11-03): three-way layout branch on Video Mode state.
    // - .isEnabled false → off-path = v1.0 verbatim (SC5 byte-identical).
    // - .isEnabled true + location.isLarge → Plan 11-04 will swap to
    //   VideoCompactControlRow (D-05); for now we render existingLayout
    //   with the toolbar hidden so the wrap site compiles end-to-end.
    // - .isEnabled true + small zone → existing layout + repositioned
    //   toolbar via VideoModeSlotRouter.anchors(for:) (D-02).
    @Environment(\.videoModeStore) var videoModeStore
    @Environment(\.videoModeCompactness) var videoModeCompactness

    var theme: Theme { themeManager.theme(using: colorScheme) }

    init(initialDifficulty: MinesweeperDifficulty? = nil) {
        _viewModel = State(initialValue: MinesweeperViewModel(difficulty: initialDifficulty))
    }

    var body: some View {
        // P11 D-01/D-02 (Plan 11-03 + 11-04): three-way layout branch.
        // - Off-path: render existingLayout + v1.0 toolbar (SC5 byte-identical).
        // - Large-zone (D-01/D-05/D-06/D-08/D-18): render `largeZoneLayout`
        //   with toolbar hidden (D-09). HeaderBar + ModePill from the off-path
        //   are NOT rendered — both roles migrate into VideoCompactControlRow
        //   (HeaderBar's chips → slot 2 stack; ModePill → slot 3). Compactness
        //   reactions per D-18 happen inside `compactRowComposed`.
        // - Small-zone: render existingLayout with toolbar items repositioned
        //   per VideoModeSlotRouter.anchors(for:) (D-02). No compact-row swap,
        //   no HeaderBar/ModePill hiding.
        Group {
            if !videoModeStore.isEnabled {
                existingLayout
                    .toolbar { existingToolbarContent }
            } else if videoModeStore.location.isLarge {
                largeZoneLayout
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                existingLayout
                    .toolbar { smallZoneToolbarContent }
            }
        }
        .navigationTitle(String(localized: "Minesweeper"))
        .navigationBarTitleDisplayMode(.inline)
        // 2026-05-01: Hide the system back chevron + edge-swipe-to-go-back
        // gesture so cell long-press / pinch-to-zoom interactions near the
        // left edge don't get hijacked. Custom back ToolbarItem (see
        // existingToolbarContent / smallZoneToolbarContent in
        // MinesweeperGameView+VideoMode.swift) is the only path off this
        // screen (besides win/loss → Home from the end-state card). Matches
        // MergeGameView for cross-game consistency.
        .navigationBarBackButtonHidden(true)
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
    func endStateOverlay(outcome: GameOutcome) -> some View {
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
    var tripCellIndex: MinesweeperIndex? {
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
