//
//  NonogramGameView.swift
//  gamekit
//
//  Top-level Nonogram scene. Owns the VM, wires taps + long-press through
//  to mutations, surfaces the win overlay. Mirrors MinesweeperGameView's
//  shape so the cross-game pattern is identical: ZStack background +
//  VStack(header / board / mode pill) + conditional end-state overlay,
//  toolbar with back chevron + restart + size picker.
//
//  Phase 12 Plan 12-04 (D-NG-01 + D-NG-17) + Phase 12.1 Plan 12.1-04 (D-04):
//    - body is a three-way Group branch on Video Mode state:
//        • off-path (!videoModeStore.isEnabled): existingLayout + existingToolbarContent
//          — v1.1 render byte-identical (SC4 / D-12-OFFRESTORE)
//        • Large-zone: largeZoneLayout, nav-bar toolbar hidden — compact row
//          hosts Back / Size↔Lives / Fill-Mark / Time / Restart-w-menu per D-NG-01
//        • Small-zone: `smallZoneLayout` (Phase 12.1) + `smallZoneToolbarContent`
//          — HeaderBar/ModePill ordering inside the VStack flips per
//          `anchors.headerBar`, and toolbar items reposition via the existing
//          `smallZoneToolbarContent`.
//    - All extension members live in NonogramGameView+VideoMode.swift (§8.5
//      file-size cap split). Env reads, viewModel, theme, dismiss, settingsStore,
//      reduceMotion, endCardVisible, isInteractive, isTerminal, endStateOverlay
//      are internal access so the extension can read them.
//    - D-NG-17: NonogramBoardView untouched in this plan; Plan 12-05 handles
//      the cell-size floor seam.
//

import SwiftUI
import SwiftData
import DesignKit

struct NonogramGameView: View {
    @State var viewModel: NonogramViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) var settingsStore
    @Environment(\.dismiss) var dismiss
    @State private var didInjectStats = false
    @State var showDifficultyPicker = false               // internal so banner extension can write
    @State var bannerDismissed = false                    // P13 "View board" toggle

    init(initialDifficulty: NonogramDifficulty? = nil) {
        _viewModel = State(initialValue: NonogramViewModel(difficulty: initialDifficulty))
    }
    /// Gates the end-state card so the player gets a beat to admire the
    /// completed picture before the overlay covers it. Flipped true by a
    /// Task that runs on `state == .won`.
    @State var endCardVisible = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // P12 D-NG-01 (Plan 12-04) + P12.1 D-04 (Plan 12.1-04): three-way layout
    // branch on Video Mode state.
    // - .isEnabled false → off-path = v1.1 verbatim (SC4 / D-12-OFFRESTORE byte-identical).
    // - .isEnabled true + location.isLarge → compactRowComposed swap (D-NG-01).
    // - .isEnabled true + small zone → `smallZoneLayout` (Phase 12.1, Plan
    //   12.1-04) — chips/picker reposition away from PiP overlay corners +
    //   repositioned toolbar (D-NG-02 + CONTEXT D-04).
    @Environment(\.videoModeStore) var videoModeStore
    @Environment(\.videoModeCompactness) var videoModeCompactness

    var theme: Theme { themeManager.theme(using: colorScheme) }

    var isInteractive: Bool {
        viewModel.state != .won && viewModel.state != .gameOver
    }

    var isTerminal: Bool {
        viewModel.state == .won || viewModel.state == .gameOver
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
                // v1.1 existingLayout shape (compact). Toolbar reposition
                // applies — back + difficulty menu live there.
                smallTopZoneLayout
                    .toolbar { smallZoneToolbarContent }
            } else {
                // Phase 12.1, Plan 12.1-06 round 2 — Bot L/R Small zones use
                // HeaderBar (compact) top → Board → HStack picker row at the
                // bottom, ModePill slid to the side opposite covered PiP.
                smallBottomZoneLayout
                    .toolbar { smallZoneToolbarContent }
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            switch newState {
            case .won:
                let animate = settingsStore.animationsEnabled && !reduceMotion
                if animate {
                    Task { @MainActor in
                        // Hold ~2s on the completed picture so the player
                        // can take it in before the overlay covers it.
                        try? await Task.sleep(for: .milliseconds(2000))
                        guard viewModel.state == .won else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            endCardVisible = true
                        }
                    }
                } else {
                    endCardVisible = true
                }
            case .gameOver:
                // Game-over lands more abruptly than win — no celebratory
                // pause. ~0.5s breath so the last life dropping in the
                // header chip registers, then card slides in.
                let animate = settingsStore.animationsEnabled && !reduceMotion
                if animate {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        guard viewModel.state == .gameOver else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            endCardVisible = true
                        }
                    }
                } else {
                    endCardVisible = true
                }
            case .idle, .playing:
                endCardVisible = false
            }
        }
        .navigationTitle(String(localized: "Nonogram"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog(
            String(localized: "Choose size"),
            isPresented: $showDifficultyPicker,
            titleVisibility: .visible
        ) {
            ForEach(NonogramDifficulty.allCases, id: \.self) { d in
                Button(difficultyDisplayName(d)) {
                    viewModel.setDifficulty(d)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) { }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background: viewModel.pause()
            case .active:     viewModel.resume()
            case .inactive:   break
            @unknown default: break
            }
        }
        .task {
            guard !didInjectStats else { return }
            didInjectStats = true
            let stats = GameStats(modelContext: modelContext)
            viewModel.attachGameStats(stats)
        }
    }

    @ViewBuilder
    var endStateOverlay: some View {
        // P13 user override 2026-05-14: banner = win/loss surface ALWAYS.
        videoModeEndBanner
    }

    /// Legacy v1.1 EndStateCard overlay — retained for reference/rollback only.
    @ViewBuilder
    private var offPathEndStateOverlay: some View {
        ZStack {
            Rectangle()
                .fill(theme.colors.background.opacity(0.85))
                .ignoresSafeArea()
                .accessibilityHidden(true)

            NonogramEndStateCard(
                theme: theme,
                outcome: viewModel.state == .won ? .won : .gameOver,
                title: viewModel.currentPuzzle?.title ?? "",
                elapsed: viewModel.frozenElapsed,
                onPrimary: {
                    // Win → "New puzzle" picks a fresh random.
                    // Game-over → "Try again" reuses the same puzzle.
                    if viewModel.state == .won {
                        viewModel.newPuzzle()
                    } else {
                        viewModel.restart()
                    }
                },
                onChangeDifficulty: {
                    showDifficultyPicker = true
                }
            )
        }
    }

    private func difficultyDisplayName(_ d: NonogramDifficulty) -> String {
        switch d {
        case .tiny:   return String(localized: "Tiny  -  5 × 5")
        case .small:  return String(localized: "Small  -  10 × 10")
        case .medium: return String(localized: "Medium  -  15 × 15")
        case .large:  return String(localized: "Large  -  20 × 20")
        }
    }
}
