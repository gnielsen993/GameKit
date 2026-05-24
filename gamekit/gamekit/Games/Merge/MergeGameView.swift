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
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State var bannerDismissed = false                    // P13 "View board" toggle

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
            } else if videoModeStore.location.isTopSmall {
                // Phase 12.1, Plan 12.1-06 round 2 — Top L/R Small zones use
                // v1.1 existingLayout shape (HeaderBar top → Board → ModePill
                // bottom) rendered compact. Toolbar reposition still applies.
                smallTopZoneLayout
                    .toolbar { smallZoneToolbarContent }
            } else {
                // Phase 12.1, Plan 12.1-06 round 2 — Bot L/R Small zones use
                // HeaderBar (compact) top → Board → HStack picker row at the
                // bottom, ModePill (compact) slid to the side opposite the
                // covered PiP corner. Picker is a SIBLING row, never an
                // overlay on board tiles.
                smallBottomZoneLayout
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
        .alert("Resume game?", isPresented: Binding(
            get: { viewModel.pendingSaveState != nil },
            set: { _ in }
        )) {
            Button("Continue") {
                if let saved = viewModel.pendingSaveState { viewModel.restoreState(saved) }
            }
            Button("New Game", role: .destructive) { viewModel.discardSaveAndLoadNew() }
        } message: {
            if let s = viewModel.pendingSaveState {
                Text("You have an in-progress Merge game with a score of \(s.score).")
            }
        }
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { viewModel.saveCurrentState() }
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
        // P13 user override 2026-05-14: banner = win/loss surface ALWAYS.
        videoModeEndBanner(state: state)
    }

    /// Legacy v1.1 EndStateCard overlay — retained for reference/rollback only.
    @ViewBuilder
    private func offPathEndStateOverlay(state: MergeEndState) -> some View {
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
