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

import SwiftUI
import SwiftData
import DesignKit

struct NonogramGameView: View {
    @State private var viewModel = NonogramViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var didInjectStats = false
    @State private var showDifficultyPicker = false
    /// Gates the end-state card so the player gets a beat to admire the
    /// completed picture before the overlay covers it. Flipped true by a
    /// Task that runs on `state == .won`.
    @State private var endCardVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    private var isInteractive: Bool {
        viewModel.state != .won && viewModel.state != .gameOver
    }

    private var isTerminal: Bool {
        viewModel.state == .won || viewModel.state == .gameOver
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                NonogramHeaderBar(
                    theme: theme,
                    sizeLabel: "\(viewModel.difficulty.size) × \(viewModel.difficulty.size)",
                    timerAnchor: viewModel.timerAnchor,
                    pausedElapsed: viewModel.pausedElapsed,
                    livesRemaining: viewModel.gameMode == .lives ? viewModel.livesRemaining : nil
                )

                if viewModel.currentPuzzle != nil {
                    NonogramBoardView(
                        board: viewModel.board,
                        rowHints: viewModel.rowHints,
                        columnHints: viewModel.columnHints,
                        rowsCrossOff: viewModel.rowsCrossOff,
                        columnsCrossOff: viewModel.columnsCrossOff,
                        theme: theme,
                        isInteractive: isInteractive,
                        interactionMode: viewModel.interactionMode,
                        wrongFlashIdx: viewModel.lastWrongAttemptIdx,
                        onTap: { row, col in viewModel.handleTap(at: row, col: col) },
                        onLongPress: { row, col in viewModel.handleLongPress(at: row, col: col) },
                        onSlide: { row, col, next in viewModel.setCell(at: row, col: col, to: next) }
                    )
                    .padding(.horizontal, theme.spacing.s)
                    .sensoryFeedback(
                        .error,
                        trigger: settingsStore.hapticsEnabled ? viewModel.wrongAttemptCount : 0
                    )
                } else {
                    Spacer()
                    Text(String(localized: "No puzzles bundled yet"))
                        .font(.callout)
                        .foregroundStyle(theme.colors.textSecondary)
                    Spacer()
                }

                NonogramModePill(
                    theme: theme,
                    mode: viewModel.interactionMode,
                    isInteractive: isInteractive,
                    onSelect: { viewModel.setInteractionMode($0) }
                )
                .padding(.top, theme.spacing.s)
                .opacity(isInteractive ? 1 : 0)
                .allowsHitTesting(isInteractive)
            }
            .padding(.bottom, theme.spacing.l)

            // Celebratory confetti for the 2s pause between win and end-
            // card. Reuses the Minesweeper ConfettiView (TimelineView-
            // driven Canvas particles, theme-aware colors). Animations
            // toggle / Reduce Motion still gate it.
            if viewModel.state == .won
               && settingsStore.animationsEnabled
               && !reduceMotion {
                ConfettiView(theme: theme)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if isTerminal && endCardVisible {
                endStateOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
                NonogramToolbarMenu(
                    theme: theme,
                    currentDifficulty: viewModel.difficulty,
                    currentGameMode: viewModel.gameMode,
                    onSelectDifficulty: { viewModel.setDifficulty($0) },
                    onSelectGameMode: { viewModel.setGameMode($0) }
                )
            }
        }
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
    private var endStateOverlay: some View {
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
