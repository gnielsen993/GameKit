//
//  MergeGameView.swift
//  gamekit
//
//  Top-level Merge game scene. The ONLY view in Games/Merge/ that consumes
//  @EnvironmentObject themeManager + @Environment(\.modelContext); child
//  views (HeaderBar, BoardView, TileView, EndStateCard, ModePill, ToolbarMenu)
//  receive `theme: Theme` as a let parameter (matches Minesweeper's
//  re-fetch-avoidance pattern at MinesweeperGameView.swift:41).
//
//  Wiring:
//    - VM owned via `@State` (iOS 17 idiom, @Observable)
//    - GameStats injected lazily via `.task` once-per-scene (Plan 04 D-14)
//    - Swipe gestures forwarded from MergeBoardView through the VM's
//      `handleSwipe(_:)`
//    - End-state overlay sits in a ZStack with a backdrop dim — NOT a sheet
//      (mirrors MinesweeperGameView D-02 / no tap-to-dismiss)
//

import SwiftUI
import SwiftData
import DesignKit

struct MergeGameView: View {
    @State private var viewModel: MergeViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) private var settingsStore
    @State private var didInjectStats = false

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    init() {
        _viewModel = State(initialValue: MergeViewModel())
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                MergeHeaderBar(
                    theme: theme,
                    score: viewModel.score,
                    bestScore: viewModel.bestScore,
                    mode: viewModel.mode
                )

                MergeBoardView(
                    theme: theme,
                    board: viewModel.board,
                    onSwipe: { viewModel.handleSwipe($0) }
                )
                .padding(.horizontal, theme.spacing.l)
                .sensoryFeedback(
                    .impact(weight: .light),
                    trigger: settingsStore.hapticsEnabled ? viewModel.mergeCount : 0
                )
                .sensoryFeedback(
                    .success,
                    trigger: settingsStore.hapticsEnabled ? viewModel.terminalCount : 0
                )

                MergeModePill(
                    theme: theme,
                    mode: viewModel.mode,
                    onSelect: { viewModel.setMode($0) }
                )
                .padding(.top, theme.spacing.s)
                .opacity(isTerminal ? 0 : 1)
                .allowsHitTesting(!isTerminal)
            }

            if let endState = endStateForOverlay {
                endStateOverlay(state: endState)
            }
        }
        .navigationTitle(String(localized: "Merge"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
                MergeToolbarMenu(
                    theme: theme,
                    currentMode: viewModel.mode,
                    onSelect: { viewModel.setMode($0) }
                )
            }
        }
        .task {
            guard !didInjectStats else { return }
            didInjectStats = true
            let stats = GameStats(modelContext: modelContext)
            viewModel.attachGameStats(stats)
        }
    }

    // MARK: - End-state derivation

    private var isTerminal: Bool {
        switch viewModel.state {
        case .gameOver: return true
        case .won where !viewModel.hasContinuedPastWin: return true
        default: return false
        }
    }

    private var endStateForOverlay: MergeEndState? {
        switch viewModel.state {
        case .gameOver: return .gameOver
        case .won where !viewModel.hasContinuedPastWin: return .won
        default: return nil
        }
    }

    @ViewBuilder
    private func endStateOverlay(state: MergeEndState) -> some View {
        ZStack {
            Rectangle()
                .fill(theme.colors.background.opacity(0.85))
                .ignoresSafeArea()
                .accessibilityHidden(true)

            MergeEndStateCard(
                theme: theme,
                state: state,
                score: viewModel.score,
                bestScore: viewModel.bestScore,
                onPrimary: {
                    switch state {
                    case .won:      viewModel.continuePastWin()
                    case .gameOver: viewModel.restart()
                    }
                },
                onSecondary: {
                    switch state {
                    case .won:      viewModel.restart()
                    case .gameOver: viewModel.restart()  // same path; mode picker is the toolbar
                    }
                }
            )
        }
    }
}
