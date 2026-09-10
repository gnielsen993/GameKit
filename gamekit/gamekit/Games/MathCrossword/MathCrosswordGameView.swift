import SwiftUI
import MathCrosswordCore
import SwiftData
import DesignKit

struct MathCrosswordGameView: View {
    @State private var viewModel: MathCrosswordViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.videoModeStore) private var videoModeStore
    @State private var didInjectStats = false
    @State private var showRestartDialog = false
    @State private var showDifficultyDialog = false
    @State private var showReplaceSaveDialog = false
    @State private var viewedCompletedBoard = false
    @State private var boardFrame: CGRect = .zero
    @State private var bankFrame: CGRect = .zero
    @State private var draggedCell: GridPos?
    @State private var draggedValue: Int?
    @State private var dragLocation: CGPoint = .zero

    init(initialDifficulty: String? = nil) {
        _viewModel = State(initialValue: MathCrosswordViewModel(initialDifficulty: initialDifficulty))
    }

    private var theme: Theme { themeManager.theme(using: colorScheme) }
    private var isPlaying: Bool { viewModel.state == .playing }

    var body: some View {
        Group {
            if videoModeStore.isEnabled {
                gameLayout(showCompactControls: true)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                gameLayout(showCompactControls: false)
                    .toolbar { toolbarContent }
            }
        }
        .gameAssistInset(theme: theme) {
            hintCard
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .animation(
            settingsStore.animationsEnabled && !reduceMotion ? theme.motion.ease : nil,
            value: viewModel.isHintCardVisible
        )
        .gameDrawerDialog(
            isPresented: viewModel.pendingSaveState != nil,
            theme: theme,
            title: "Resume puzzle?",
            message: "You have an unfinished \(viewModel.difficulty.displayName) Math Crossword.",
            systemImage: "arrow.counterclockwise",
            actions: [
                GameDrawerDialogAction(title: "Continue", style: .primary) {
                    if let save = viewModel.pendingSaveState { viewModel.restoreState(save) }
                },
                GameDrawerDialogAction(title: "New puzzle", style: .destructive) {
                    viewModel.discardSaveAndGenerate()
                }
            ]
        )
        .gameDrawerDialog(
            isPresented: showReplaceSaveDialog,
            theme: theme,
            title: "Replace saved puzzle?",
            message: "The unreadable save will be replaced with a new puzzle.",
            systemImage: "exclamationmark.triangle",
            actions: [
                GameDrawerDialogAction(title: "Keep saved puzzle", style: .primary) { showReplaceSaveDialog = false },
                GameDrawerDialogAction(title: "Replace", style: .destructive) {
                    showReplaceSaveDialog = false
                    viewModel.replaceUnreadableSave()
                }
            ]
        )
        .gameDrawerDialog(
            isPresented: showRestartDialog,
            theme: theme,
            title: "Restart this puzzle?",
            message: "Your placed tiles will be cleared.",
            systemImage: "arrow.counterclockwise",
            actions: [
                GameDrawerDialogAction(title: "Keep playing", style: .primary) { showRestartDialog = false },
                GameDrawerDialogAction(title: "Restart", style: .destructive) {
                    showRestartDialog = false
                    viewModel.restart()
                }
            ]
        )
        .gameDrawerDialog(
            isPresented: showDifficultyDialog,
            theme: theme,
            title: "Choose difficulty",
            message: "A new puzzle starts when you change difficulty.",
            systemImage: "slider.horizontal.3",
            actions: MathCrosswordDifficulty.allCases.map { difficulty in
                GameDrawerDialogAction(title: difficulty.displayName, style: difficulty == viewModel.difficulty ? .primary : .secondary) {
                    showDifficultyDialog = false
                    viewModel.setDifficulty(difficulty)
                }
            }
        )
        .onChange(of: viewModel.isHintCardVisible) { _, showing in
            if showing { viewModel.pause() }
            else { resumeIfPossible() }
        }
        .onChange(of: showRestartDialog) { _, showing in
            if showing { viewModel.pause() }
            else { resumeIfPossible() }
        }
        .onChange(of: showDifficultyDialog) { _, showing in
            if showing { viewModel.pause() }
            else { resumeIfPossible() }
        }
        .onChange(of: showReplaceSaveDialog) { _, showing in
            if showing { viewModel.pause() }
            else { resumeIfPossible() }
        }
        .onChange(of: viewModel.pendingSaveState != nil) { _, showing in
            if showing { viewModel.pause() }
            else { resumeIfPossible() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: viewModel.setSceneActive(true)
            case .inactive, .background: viewModel.setSceneActive(false)
            @unknown default: break
            }
        }
        .onDisappear {
            draggedValue = nil
            viewModel.pause()
            viewModel.cancelGeneration()
        }
        .onChange(of: viewModel.state) { _, state in
            if state != .won { viewedCompletedBoard = false }
        }
        .task {
            guard !didInjectStats else { return }
            didInjectStats = true
            viewModel.attachGameStats(GameStats(modelContext: modelContext))
        }
        .navigationTitle("Math Crossword")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private func gameLayout(showCompactControls: Bool) -> some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(spacing: theme.spacing.s) {
                if showCompactControls && controlsAtTop { compactControls }
                infoRow(compact: videoModeStore.isEnabled)
                playArea
                bankAndActions
                if showCompactControls && !controlsAtTop { compactControls }
            }
            .padding(.bottom, theme.spacing.l)

            if viewModel.state == .won && !viewedCompletedBoard {
                MathCrosswordEndCard(
                    theme: theme,
                    difficulty: viewModel.difficulty,
                    elapsed: viewModel.pausedElapsed,
                    assistsUsed: viewModel.assistsUsed,
                    location: videoModeStore.location,
                    hapticsEnabled: settingsStore.hapticsEnabled,
                    reduceMotion: reduceMotion,
                    animationsEnabled: settingsStore.animationsEnabled,
                    onNewPuzzle: viewModel.newPuzzle,
                    onDismiss: { viewedCompletedBoard = true }
                )
            }
        }
        .overlay(alignment: .topLeading) {
            if let draggedValue, let puzzle = viewModel.puzzle {
                Text(String(draggedValue))
                    .font(theme.typography.title.weight(.semibold))
                    .foregroundStyle(theme.colors.background)
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .frame(width: boardFrame.width / CGFloat(puzzle.colCount), height: boardFrame.height / CGFloat(puzzle.rowCount))
                    .background(theme.colors.accentPrimary, in: RoundedRectangle(cornerRadius: theme.radii.button))
                    .position(dragLocation)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .coordinateSpace(name: MathCrosswordCoordinateSpace.name)
        .sensoryFeedback(.selection, trigger: settingsStore.hapticsEnabled ? viewModel.selectionCount : 0)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: settingsStore.hapticsEnabled ? viewModel.placementCount : 0)
        .sensoryFeedback(.error, trigger: settingsStore.hapticsEnabled ? viewModel.wrongAttemptCount : 0)
        .sensoryFeedback(.success, trigger: settingsStore.hapticsEnabled ? viewModel.winCount : 0)
    }

    private func infoRow(compact: Bool) -> some View {
        let packTrailing = videoModeStore.isEnabled && videoModeStore.location == .smallTopLeft
        let packLeading = videoModeStore.isEnabled && videoModeStore.location == .smallTopRight
        return HStack(spacing: theme.spacing.s) {
            if packTrailing { Spacer() }
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: viewModel.timerAnchor,
                pausedElapsed: viewModel.pausedElapsed,
                compact: compact
            )
            if !packTrailing && !packLeading { Spacer() }
            Text("\(viewModel.filledCount) / \(viewModel.blankCount)")
                .font(compact ? theme.typography.caption : theme.typography.body)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textSecondary)
                .gameInfoReadout(theme: theme, compact: compact)
                .accessibilityLabel(Text("\(viewModel.filledCount) of \(viewModel.blankCount) blanks filled"))
            if packLeading { Spacer() }
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.xs)
    }

    @ViewBuilder
    private var playArea: some View {
        switch viewModel.state {
        case .loading:
            Spacer()
            ProgressView()
                .tint(theme.colors.accentPrimary)
            Text("Making your puzzle…")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
            Spacer()
        case .failed(let message):
            Spacer()
            VStack(spacing: theme.spacing.s) {
                Text(message)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                DKButton(viewModel.hasUnreadableSave ? "Replace saved puzzle" : "Try again", theme: theme) {
                    if viewModel.hasUnreadableSave {
                        showReplaceSaveDialog = true
                    } else {
                        viewModel.newPuzzle()
                    }
                }
            }
            .padding(.horizontal, theme.spacing.m)
            Spacer()
        case .playing, .won:
            if let puzzle = viewModel.puzzle {
                MathCrosswordBoardView(
                    theme: theme,
                    puzzle: puzzle,
                    placements: viewModel.placements,
                    selectedCell: viewModel.selectedCell,
                    hintPlacements: viewModel.activeHint?.placements ?? [:],
                    conflictingCells: viewModel.validation?.conflictingCells ?? [],
                    onSelect: viewModel.select,
                    dropTarget: draggedValue == nil || draggedCell != nil ? nil : dragPosition(at: dragLocation),
                    onFrameChange: { boardFrame = $0 },
                    onDragChanged: { position, value, location in
                        guard isPlaying else { return }
                        draggedCell = position
                        draggedValue = value
                        dragLocation = location
                    },
                    onDragEnded: { position, value, location in
                        defer { draggedValue = nil; draggedCell = nil }
                        guard bankFrame.contains(location) else { return }
                        viewModel.returnTile(at: position, expectedValue: value)
                    }
                )
            }
        }
    }

    private var controlsAtTop: Bool {
        [VideoModeLocation.largeBottom, .smallBottomLeft, .smallBottomRight].contains(videoModeStore.location)
    }

    private var placementInstruction: String {
        if let conflict = viewModel.conflictMessage { return conflict }
        if viewModel.selectedCell == nil {
            return dynamicTypeSize.isAccessibilitySize ? "Select a blank." : "Drag a number to a blank, or tap to place."
        }
        return dynamicTypeSize.isAccessibilitySize ? "Choose a number." : "Choose a number, or drag this tile back to the bank."
    }

    private var bankAndActions: some View {
        VStack(spacing: theme.spacing.s) {
            if !viewModel.isHintCardVisible {
                Text(dynamicTypeSize.isAccessibilitySize && viewModel.hasIncorrectPlacement ? "Check this board." : placementInstruction)
                    .font(theme.typography.caption)
                    .foregroundStyle(viewModel.hasIncorrectPlacement ? theme.colors.danger : theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(Text(placementInstruction))
            }
            MathCrosswordNumberBank(
                theme: theme,
                values: viewModel.remainingBank,
                compact: videoModeStore.isEnabled,
                selectedCell: viewModel.selectedCell != nil && isPlaying,
                onPlace: viewModel.place,
                onDragChanged: { value, location in
                    draggedCell = nil
                    draggedValue = value
                    dragLocation = location
                },
                onDragEnded: { value, location in
                    defer { draggedValue = nil }
                    guard isPlaying, let position = dragPosition(at: location) else { return }
                    viewModel.select(position)
                    viewModel.place(value)
                }
            )
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .named(MathCrosswordCoordinateSpace.name))
            } action: { bankFrame = $0 }
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.button)
                    .stroke(theme.colors.accentPrimary, lineWidth: 2)
                    .opacity(draggedCell != nil && bankFrame.contains(dragLocation) ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .accessibilityIdentifier("math-number-bank")

            if !videoModeStore.isEnabled {
                HStack(spacing: theme.spacing.s) {
                    Button(action: viewModel.eraseSelected) {
                        Label("Erase", systemImage: "delete.left")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.pressable)
                    .disabled(viewModel.selectedCell == nil || !isPlaying)
                    .accessibilityLabel(Text("Erase selected tile"))

                    Button(action: viewModel.undo) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.pressable)
                    .disabled(viewModel.placementHistory.isEmpty || !isPlaying)
                    .accessibilityLabel(Text("Undo last tile"))
                }
                .font(theme.typography.body.weight(.semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .padding(.horizontal, theme.spacing.m)
            }
        }
        .opacity(isPlaying ? 1 : 0.55)
        .allowsHitTesting(isPlaying)
    }

    private var compactControls: some View {
        HStack(spacing: theme.spacing.s) {
            compactButton(symbol: "chevron.left", label: "Back to The Drawer", action: { dismiss() })
            if settingsStore.assistsEnabled {
                compactButton(symbol: "lightbulb", label: "Show a Math Crossword hint", action: viewModel.requestHint)
            }
            compactButton(symbol: "delete.left", label: "Erase selected tile", action: viewModel.eraseSelected)
                .disabled(viewModel.selectedCell == nil || !isPlaying)
            compactButton(symbol: "arrow.uturn.backward", label: "Undo last tile", action: viewModel.undo)
                .disabled(viewModel.placementHistory.isEmpty || !isPlaying)
            compactButton(symbol: "arrow.counterclockwise", label: "Restart puzzle", action: { showRestartDialog = true })
            compactButton(symbol: "ellipsis.circle", label: "Choose difficulty", action: { showDifficultyDialog = true })
        }
        .padding(.horizontal, theme.spacing.m)
    }

    private func compactButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: theme.spacing.m, height: theme.spacing.m)
                .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: toolbarLeadingPlacement) {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel(Text("Back to The Drawer"))
            Button { showRestartDialog = true } label: { Image(systemName: "arrow.counterclockwise") }
                .accessibilityLabel(Text("Restart puzzle"))
        }
        if settingsStore.assistsEnabled && isPlaying {
            ToolbarItem(placement: toolbarTrailingPlacement) {
                GameAssistToolbarButton(theme: theme, label: "Show a Math Crossword hint", action: viewModel.requestHint)
            }
        }
        ToolbarItem(placement: toolbarTrailingPlacement) {
            Menu {
                if settingsStore.assistsEnabled && isPlaying {
                    Button("Show a hint", systemImage: "lightbulb") { viewModel.requestHint() }
                }
                Divider()
                Button("Change difficulty", systemImage: "slider.horizontal.3") { showDifficultyDialog = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(Text("Game options"))
        }
    }

    @ViewBuilder
    private var hintCard: some View {
        if viewModel.isHintCardVisible, let hint = viewModel.activeHint {
            GameAssistCard(
                theme: theme,
                title: "A forced step",
                message: hint.isRevealed
                    ? MathCrosswordHintCopy.reveal(for: hint.placements)
                    : MathCrosswordHintCopy.explanation(for: hint),
                primaryAction: .init(
                    title: hint.isRevealed ? "Fill it in" : "Show the numbers",
                    perform: hint.isRevealed ? viewModel.applyHint : viewModel.revealActiveHint
                ),
                onDismiss: viewModel.dismissHint
            )
        } else if viewModel.isHintCardVisible, let message = viewModel.hintUnavailableMessage {
            GameAssistCard(
                theme: theme,
                title: "Check this board first",
                message: message,
                tone: .warning,
                onDismiss: viewModel.dismissHint
            )
        }
    }

    private func dragPosition(at point: CGPoint) -> GridPos? {
        guard let puzzle = viewModel.puzzle, boardFrame.width > 0, boardFrame.height > 0,
              boardFrame.contains(point) else { return nil }
        let position = GridPos(
            row: Int((point.y - boardFrame.minY) / boardFrame.height * CGFloat(puzzle.rowCount)),
            col: Int((point.x - boardFrame.minX) / boardFrame.width * CGFloat(puzzle.colCount))
        )
        return puzzle.blanks.contains(position) ? position : nil
    }

    private func resumeIfPossible() {
        guard scenePhase == .active,
              !showRestartDialog,
              !showDifficultyDialog,
              !showReplaceSaveDialog,
              viewModel.pendingSaveState == nil else { return }
        viewModel.resume()
    }

    private var toolbarLeadingPlacement: ToolbarItemPlacement {
        videoModeStore.isEnabled && videoModeStore.location == .smallTopLeft
            ? .topBarTrailing
            : .topBarLeading
    }

    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        videoModeStore.isEnabled && videoModeStore.location == .smallTopRight
            ? .topBarLeading
            : .topBarTrailing
    }
}
