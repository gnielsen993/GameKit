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
//  Phase 12 Plan 12-02 (D-MG-01 + D-MG-17), updated by Phase 12.1 Plan 12.1-03:
//    - body is a three-way Group branch on Video Mode state:
//        • off-path (!videoModeStore.isEnabled): existingLayout + existingToolbarContent
//          — v1.1 render byte-identical (SC4 / D-12-OFFRESTORE)
//        • Large-zone: largeZoneLayout, nav-bar toolbar hidden — compact row
//          hosts Back/Score/Mode/Best/Restart-w-menu per D-MG-01
//        • Small-zone: `smallZoneLayout` (Phase 12.1) + `smallZoneToolbarContent`
//          — HeaderBar / ModePill ordering inside the VStack flips per
//          `anchors.headerBar`, and toolbar items reposition via the existing
//          `smallZoneToolbarContent`.
//    - All extension members live in MergeGameView+VideoMode.swift (§8.5
//      file-size cap split). Env reads, viewModel, theme, dismiss, and
//      settingsStore are internal access so the extension can read them.
//

import SwiftUI
import SwiftData
import DesignKit

struct MergeGameView: View {
    @State var viewModel: MergeViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) var settingsStore
    @Environment(\.dismiss) var dismiss
    @State private var didInjectStats = false

    // P12 D-MG-01 (Plan 12-02) + P12.1 Plan 12.1-03: three-way layout branch on Video Mode state.
    // - .isEnabled false → off-path = v1.1 verbatim (SC4 / D-12-OFFRESTORE byte-identical).
    // - .isEnabled true + location.isLarge → compactRowComposed swap (D-MG-01).
    // - .isEnabled true + small zone → `smallZoneLayout` (Phase 12.1, Plan 12.1-03) —
    //   chips/picker reposition away from PiP overlay corners + repositioned toolbar
    //   (D-MG-02 + CONTEXT D-04).
    @Environment(\.videoModeStore) var videoModeStore
    @Environment(\.videoModeCompactness) var videoModeCompactness

    var theme: Theme { themeManager.theme(using: colorScheme) }

    init(initialMode: MergeMode? = nil) {
        _viewModel = State(initialValue: MergeViewModel(mode: initialMode))
    }

    var body: some View {
        Group {
            if !videoModeStore.isEnabled {
                existingLayout
                    .toolbar { existingToolbarContent }
            } else if videoModeStore.location.isLarge {
                largeZoneLayout
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                smallZoneLayout
                    .toolbar { smallZoneToolbarContent }
            }
        }
        .navigationTitle(String(localized: "Merge"))
        .navigationBarTitleDisplayMode(.inline)
        // 2026-05-01: Hide the system back chevron + edge-swipe-to-go-back
        // gesture. Merge's tile interaction is swipe-driven, so the iOS
        // edge-swipe-back gesture was hijacking play swipes near the left
        // edge. The custom back ToolbarItem (in MergeGameView+VideoMode.swift)
        // is the only path off this screen (besides win/loss → Home from
        // the end-state card). Same treatment applied to MinesweeperGameView
        // for consistency across game screens.
        .navigationBarBackButtonHidden(true)
        .alert(
            String(localized: "Abandon current game?"),
            isPresented: $viewModel.showingAbandonAlert
        ) {
            Button(String(localized: "Cancel"), role: .cancel) {
                viewModel.cancelModeChange()
            }
            Button(String(localized: "Abandon"), role: .destructive) {
                viewModel.confirmModeChange()
            }
        } message: {
            Text(String(localized: "Switching modes resets the board. Your current score will be lost."))
        }
        .task {
            guard !didInjectStats else { return }
            didInjectStats = true
            let stats = GameStats(modelContext: modelContext)
            viewModel.attachGameStats(stats)
        }
    }

    // MARK: - End-state derivation

    var isTerminal: Bool {
        switch viewModel.state {
        case .gameOver: return true
        case .won where !viewModel.hasContinuedPastWin: return true
        default: return false
        }
    }

    var endStateForOverlay: MergeEndState? {
        switch viewModel.state {
        case .gameOver: return .gameOver
        case .won where !viewModel.hasContinuedPastWin: return .won
        default: return nil
        }
    }

    @ViewBuilder
    func endStateOverlay(state: MergeEndState) -> some View {
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
