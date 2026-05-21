//
//  SudokuGameView.swift
//  gamekit
//
//  Top-level Sudoku scene. Owns the VM, wires selection + placement
//  through to mutations, surfaces the win/loss overlay. Mirrors
//  NonogramGameView's shape: ZStack background + VStack(header / board /
//  numpad) + conditional end-state overlay, toolbar with back + restart +
//  SudokuToolbarMenu.
//
//  Video Mode layout extension: SudokuGameView+VideoMode.swift.
//  All extension members are internal access so the extension can read them.
//

import SwiftUI
import SwiftData
import DesignKit

struct SudokuGameView: View {
    @State var viewModel: SudokuViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) var settingsStore
    @Environment(\.dismiss) var dismiss
    @State private var didInjectStats = false
    @State var bannerDismissed = false
    @State var endCardVisible = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Video Mode env (mirrors NonogramGameView)
    @Environment(\.videoModeStore) var videoModeStore
    @Environment(\.videoModeCompactness) var videoModeCompactness

    init(initialDifficulty: SudokuDifficulty? = nil, initialMode: SudokuGameMode? = nil) {
        _viewModel = State(initialValue: SudokuViewModel(difficulty: initialDifficulty, mode: initialMode))
    }

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
            } else {
                // Video Mode path — delegate to +VideoMode extension.
                videoModeLayout
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            switch newState {
            case .won:
                let animate = settingsStore.animationsEnabled && !reduceMotion
                if animate {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(1500))
                        guard viewModel.state == .won else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            endCardVisible = true
                        }
                    }
                } else {
                    endCardVisible = true
                }
            case .gameOver:
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
                bannerDismissed = false
            }
        }
        .navigationTitle(String(localized: "Sudoku"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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

    // MARK: - End state overlay

    @ViewBuilder
    var endStateOverlay: some View {
        if !bannerDismissed {
            sudokuEndBanner
        }
    }

    @ViewBuilder
    private var sudokuEndBanner: some View {
        ZStack {
            Rectangle()
                .fill(theme.colors.background.opacity(0.85))
                .ignoresSafeArea()
                .accessibilityHidden(true)

            SudokuEndStateCard(
                theme: theme,
                outcome: viewModel.state == .won ? .won : .gameOver,
                difficulty: viewModel.difficulty,
                elapsed: viewModel.frozenElapsed,
                onPrimary: {
                    bannerDismissed = false
                    endCardVisible = false
                    if viewModel.state == .won {
                        viewModel.newPuzzle()
                    } else {
                        viewModel.restart()
                    }
                },
                onDismiss: {
                    bannerDismissed = true
                }
            )
        }
    }
}

// MARK: - Main layout

extension SudokuGameView {

    /// Timer + lives row rendered above the board. Internal so VideoMode
    /// extension can reuse it in the top-small-zone layout.
    @ViewBuilder
    var gameInfoRow: some View {
        HStack(spacing: theme.spacing.s) {
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: viewModel.timerAnchor,
                pausedElapsed: viewModel.pausedElapsed
            )
            Spacer()
            if viewModel.gameMode == .lives {
                SudokuLivesChip(theme: theme, mistakes: viewModel.mistakes)
            }
        }
        .padding(.horizontal, theme.spacing.m)
    }

    @ViewBuilder
    var existingLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.s) {
                // Timer (left) + lives (right) sit just above the board so
                // they never crowd the mode pill or number pad.
                gameInfoRow
                    .padding(.vertical, theme.spacing.xs)

                if viewModel.board != nil {
                    sudokuBoard
                } else {
                    Spacer()
                    Text(String(localized: "Loading puzzle…"))
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                    Spacer()
                }

                // Mode pill centered, erase trailing. ZStack keeps the pill
                // truly centered regardless of erase button width.
                ZStack(alignment: .center) {
                    SudokuModePill(
                        theme: theme,
                        mode: viewModel.interactionMode,
                        isInteractive: isInteractive,
                        onSelect: { viewModel.setInteractionMode($0) }
                    )
                    HStack {
                        Spacer()
                        eraseButton
                    }
                    .padding(.horizontal, theme.spacing.m)
                }
                .frame(maxWidth: .infinity)

                SudokuNumberPad(viewModel: viewModel, theme: theme)
                    .opacity(isInteractive ? 1 : 0.4)
                    .allowsHitTesting(isInteractive)
            }
            .padding(.bottom, theme.spacing.l)

            if isTerminal && endCardVisible {
                endStateOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    @ViewBuilder
    var sudokuBoard: some View {
        SudokuBoardView(viewModel: viewModel, theme: theme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, theme.spacing.m)
            .layoutPriority(1)
            .sensoryFeedback(
                .impact(weight: .light, intensity: 0.7),
                trigger: settingsStore.hapticsEnabled ? viewModel.placeCount : 0
            )
            .sensoryFeedback(
                .error,
                trigger: settingsStore.hapticsEnabled ? viewModel.wrongAttemptCount : 0
            )
            .sensoryFeedback(
                .success,
                trigger: settingsStore.hapticsEnabled ? viewModel.winCount : 0
            )
    }

    // MARK: - Toolbar (off-path)

    @ToolbarContentBuilder
    var existingToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { backButton }
        ToolbarItem(placement: .topBarLeading) { restartButton }
        ToolbarItem(placement: .topBarTrailing) {
            SudokuToolbarMenu(
                theme: theme,
                currentDifficulty: viewModel.difficulty,
                currentGameMode: viewModel.gameMode,
                onSelectDifficulty: { viewModel.setDifficulty($0) },
                onSelectGameMode: { viewModel.setGameMode($0) }
            )
        }
    }

    @ViewBuilder
    var backButton: some View {
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

    @ViewBuilder
    var restartButton: some View {
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
        .accessibilityLabel(Text("Restart puzzle"))
    }

    /// Erase button for the mode-pill row. Floats trailing so the 9 numpad
    /// digits can span the full pad width without a 10th off-center slot.
    @ViewBuilder
    var eraseButton: some View {
        Button {
            viewModel.erase()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 36, height: 36)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                        .stroke(theme.colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .opacity(isInteractive ? 1 : 0.4)
        .accessibilityLabel(Text("Erase"))
    }
}
