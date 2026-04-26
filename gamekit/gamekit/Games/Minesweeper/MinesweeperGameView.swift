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
//  iOS 17.0/17.1 @State-with-reference-type leak acknowledged (RESEARCH Pitfall 1):
//  one VM instance (~few KB) leaks per game-screen dismiss; not worth a
//  @StateObject shim that fights @Observable. Fixed in iOS 17.2+.
//

import SwiftUI
import DesignKit

struct MinesweeperGameView: View {
    @State private var viewModel: MinesweeperViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

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
                    onTap: { viewModel.reveal(at: $0) },
                    onLongPress: { viewModel.toggleFlag(at: $0) }
                )
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
