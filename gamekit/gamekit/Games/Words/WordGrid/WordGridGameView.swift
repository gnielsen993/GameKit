import SwiftUI
import SwiftData
import DesignKit

struct WordGridGameView: View {
    @State var viewModel: WordGridViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) var settingsStore
    @Environment(\.videoModeStore) var videoModeStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var didInjectStats = false
    @State private var bannerDismissed = false

    init(initialMode: WordGridMode? = nil) {
        _viewModel = State(initialValue: WordGridViewModel(mode: initialMode))
    }

    var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        Group {
            if videoModeStore.isEnabled {
                videoModeLayout
            } else {
                normalLayout()
                    .toolbar { gameToolbar() }
            }
        }
        .navigationTitle(String(localized: "Word Grid"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("Resume game?", isPresented: Binding(
            get: { viewModel.pendingSaveState != nil },
            set: { _ in }
        )) {
            Button("Continue") {
                if let saved = viewModel.pendingSaveState { viewModel.restoreState(saved) }
            }
            Button("New Grid", role: .destructive) { viewModel.discardSaveAndLoadNew() }
        } message: {
            Text("You have an unfinished Word Grid game.")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { viewModel.saveCurrentState() }
        }
        .task {
            guard !didInjectStats else { return }
            didInjectStats = true
            viewModel.attachGameStats(GameStats(modelContext: modelContext))
        }
    }

    /// Chip packing for Video Mode small-top zones — chips slide away from
    /// the covered corner; `.spread` is the off-path arrangement.
    enum InfoPack { case spread, leading, trailing }

    /// ~192pt system small-PiP height + margin (mirrors
    /// SudokuGameView+VideoMode.smallPipFootprint) — lifts the Clear/Submit/
    /// Finish control row above a bottom-corner PiP so it stays tappable.
    private static let smallPipFootprint: CGFloat = 200

    /// Necessity principle (2026-07-09, DESIGN §7.7): chrome changes from its
    /// off-path form only where the selected PiP zone actually covers it.
    @ViewBuilder
    private var videoModeLayout: some View {
        switch videoModeStore.location {
        case .largeTop:
            // Band covers the nav bar — compact row at the bottom edge.
            largeZoneLayout
                .toolbar(.hidden, for: .navigationBar)
        case .largeBottom:
            // Band covers only the bottom; the videoModeAware inset lifts the
            // control row above it — nav bar + full info row stay off-path.
            normalLayout()
                .toolbar { gameToolbar() }
        case .smallTopLeft:
            // PiP covers the leading nav corner + score chip: back/restart
            // join the (uncovered) menu at trailing; info chips pack trailing.
            normalLayout(infoPack: .trailing)
                .toolbar { gameToolbar(itemsAtLeading: false) }
        case .smallTopRight:
            // PiP covers the trailing nav corner + timer/mode chip: the menu
            // joins back/restart at leading; info chips pack leading.
            normalLayout(infoPack: .leading)
                .toolbar { gameToolbar(menuAtTrailing: false) }
        case .smallBottomLeft, .smallBottomRight:
            // PiP sits on the control row's bottom corner — the only
            // genuinely covered element. Lift the stack above the PiP
            // footprint; top chrome stays byte-identical to off-path.
            normalLayout(bottomClearance: Self.smallPipFootprint)
                .toolbar { gameToolbar() }
        }
    }

    /// Off-path layout. Video Mode zones whose PiP leaves the chrome
    /// unobstructed reuse it verbatim; parameters adjust only the covered
    /// element (defaults reproduce off-path exactly).
    @ViewBuilder
    private func normalLayout(infoPack: InfoPack = .spread,
                              bottomClearance: CGFloat = 0) -> some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(spacing: theme.spacing.s) {
                infoRow(compact: false, pack: infoPack)
                    .padding(.vertical, theme.spacing.xs)
                playArea
                currentWordRow
                controlRow
            }
            .padding(.bottom, bottomClearance > 0 ? bottomClearance : theme.spacing.l)

            if viewModel.state == .finished && !bannerDismissed {
                endBanner
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: settingsStore.hapticsEnabled ? viewModel.submitCount : 0)
        .sensoryFeedback(.error, trigger: settingsStore.hapticsEnabled ? viewModel.invalidCount : 0)
        .sensoryFeedback(.success, trigger: settingsStore.hapticsEnabled ? viewModel.finishCount : 0)
    }

    /// Large-top only — the band genuinely displaces the nav bar, so the
    /// compact row (at the bottom edge, opposite the band) hosts its roles.
    /// `.largeBottom` renders `normalLayout()` instead (necessity principle).
    @ViewBuilder
    private var largeZoneLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(spacing: theme.spacing.s) {
                infoRow(compact: true)
                playArea
                currentWordRow
                controlRow
                compactControlRow
            }
            .padding(.bottom, theme.spacing.l)

            if viewModel.state == .finished && !bannerDismissed {
                endBanner
            }
        }
    }

    private func infoRow(compact: Bool, pack: InfoPack = .spread) -> some View {
        HStack(spacing: theme.spacing.s) {
            if pack == .trailing { Spacer() }
            chip(systemName: "number", text: "\(viewModel.score)", compact: compact, numericValue: Double(viewModel.score))
            if pack == .spread { Spacer() }
            if viewModel.mode == .timed {
                chip(systemName: "clock", text: formatTime(viewModel.remainingSeconds), compact: compact)
            } else {
                chip(systemName: "infinity", text: viewModel.mode.displayName, compact: compact)
            }
            if pack == .leading { Spacer() }
        }
            .padding(.horizontal, theme.spacing.m)
    }

    @ViewBuilder
    private var playArea: some View {
        if horizontalSizeClass == .regular {
            HStack(alignment: .center, spacing: theme.spacing.s) {
                boardView
                WordGridFoundWordsPanel(
                    theme: theme,
                    words: viewModel.sortedFoundWords,
                    layout: .rail
                )
                .frame(width: theme.spacing.xxl * 5)
                .frame(maxHeight: .infinity)
            }
            .padding(.trailing, theme.spacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
        } else {
            VStack(spacing: theme.spacing.s) {
                boardView
                WordGridFoundWordsPanel(
                    theme: theme,
                    words: viewModel.sortedFoundWords,
                    layout: .compact
                )
                .frame(height: theme.spacing.xxl * 3)
                .padding(.horizontal, theme.spacing.m)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
        }
    }

    private var boardView: some View {
        WordGridBoardView(
            theme: theme,
            board: viewModel.board,
            selectedPath: viewModel.selectedPath,
            onSelect: { viewModel.select($0) }
        )
    }

    private var currentWordRow: some View {
        Text(viewModel.currentWord.isEmpty ? (viewModel.message ?? viewModel.mode.displayName) : viewModel.currentWord)
            .font(theme.typography.headline)
            .foregroundStyle(viewModel.currentWord.isEmpty ? theme.colors.textSecondary : theme.colors.accentPrimary)
            .frame(height: theme.spacing.xl)
            .frame(maxWidth: .infinity)
    }

    private var controlRow: some View {
        HStack(spacing: theme.spacing.s) {
            DKButton(String(localized: "Clear"), style: .secondary, theme: theme) {
                viewModel.clearSelection()
            }
            DKButton(String(localized: "Submit"), style: .primary, theme: theme) {
                viewModel.submitSelection()
            }
            DKButton(String(localized: "Finish"), style: .secondary, theme: theme) {
                viewModel.finish()
            }
        }
        .padding(.horizontal, theme.spacing.m)
        .opacity(viewModel.state == .finished ? 0.45 : 1)
        .allowsHitTesting(viewModel.state == .playing)
    }

    private var compactControlRow: some View {
        VideoCompactControlRow(theme: theme, onBack: { dismiss() }, onSettings: nil) {
            Text("\(viewModel.score)")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textPrimary)
        } picker: {
            EmptyView()
        } secondaryInfo: {
            Button { viewModel.restart() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(theme.colors.textPrimary)
            }
            .accessibilityLabel(Text("New grid"))
        }
    }

    private func chip(systemName: String, text: String, compact: Bool, numericValue: Double? = nil) -> some View {
        HStack(spacing: theme.spacing.xs) {
            Image(systemName: systemName)
            Text(text)
                .contentTransition(numericValue != nil ? .numericText(value: numericValue ?? 0) : .identity)
                .feedbackAnimation(theme.motion.ease, value: numericValue)
        }
        .font(compact ? theme.typography.caption : theme.typography.body)
        .foregroundStyle(theme.colors.textPrimary)
        .padding(.horizontal, compact ? theme.spacing.xs : theme.spacing.s)
        .padding(.vertical, theme.spacing.xs)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .chipShadow()
    }

    /// Off-path toolbar shape with per-side parameters — Video Mode small-top
    /// zones move only the items whose corner the PiP covers (defaults
    /// reproduce off-path exactly).
    @ToolbarContentBuilder
    private func gameToolbar(itemsAtLeading: Bool = true,
                             menuAtTrailing: Bool = true) -> some ToolbarContent {
        ToolbarItemGroup(placement: itemsAtLeading ? .topBarLeading : .topBarTrailing) {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel(Text("Back to The Drawer"))
            Button { viewModel.restart() } label: { Image(systemName: "arrow.counterclockwise") }
                .accessibilityLabel(Text("New grid"))
        }
        ToolbarItem(placement: menuAtTrailing ? .topBarTrailing : .topBarLeading) {
            Menu {
                ForEach(WordGridMode.allCases, id: \.self) { mode in
                    Button(mode.displayName) { viewModel.setMode(mode) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(Text("Mode"))
        }
    }

    private var endBanner: some View {
        VideoModeBanner(
            theme: theme,
            content: VideoModeBannerContent(
                outcome: .win,
                title: String(localized: "Grid complete"),
                subtitle: String(localized: "Score \(viewModel.score) · \(viewModel.foundWords.count) words"),
                primaryButtonLabel: String(localized: "New grid"),
                accessibilityLabel: "Grid complete. Score \(viewModel.score)",
                onPrimary: {
                    bannerDismissed = false
                    viewModel.restart()
                },
                secondaryButtonLabel: String(localized: "View board"),
                secondaryAction: { bannerDismissed = true },
                tertiaryButtonLabel: String(localized: "Change mode"),
                tertiaryAction: {
                    viewModel.setMode(viewModel.mode == .timed ? .relaxed : .timed)
                    bannerDismissed = false
                }
            ),
            location: videoModeStore.location,
            hapticsEnabled: settingsStore.hapticsEnabled,
            reduceMotion: reduceMotion,
            animationsEnabled: settingsStore.animationsEnabled
        )
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
