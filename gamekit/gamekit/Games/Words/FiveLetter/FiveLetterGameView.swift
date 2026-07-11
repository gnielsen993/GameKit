import SwiftUI
import SwiftData
import DesignKit

struct FiveLetterGameView: View {
    @State var viewModel: FiveLetterViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) var settingsStore
    @Environment(\.videoModeStore) var videoModeStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didInjectStats = false
    @State private var bannerDismissed = false

    init(initialMode: FiveLetterMode? = nil) {
        _viewModel = State(initialValue: FiveLetterViewModel(mode: initialMode))
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
        .navigationTitle(String(localized: "Five Letter"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("Resume puzzle?", isPresented: Binding(
            get: { viewModel.pendingSaveState != nil },
            set: { _ in }
        )) {
            Button("Continue") {
                if let saved = viewModel.pendingSaveState { viewModel.restoreState(saved) }
            }
            Button("New Puzzle", role: .destructive) { viewModel.discardSaveAndLoadNew() }
        } message: {
            Text("You have an unfinished Five Letter puzzle.")
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                viewModel.saveCurrentState()
                viewModel.pause()
            case .active:
                viewModel.resume()
            case .inactive:
                break
            @unknown default:
                break
            }
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
    /// SudokuGameView+VideoMode.smallPipFootprint) — lifts the keyboard above
    /// a bottom-corner PiP so every key stays tappable.
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
            // keyboard above it — nav bar + full info row stay off-path.
            normalLayout()
                .toolbar { gameToolbar() }
        case .smallTopLeft:
            // PiP covers the leading nav corner + timer chip: back/restart
            // join the (uncovered) menu at trailing; info chips pack trailing.
            normalLayout(infoPack: .trailing)
                .toolbar { gameToolbar(itemsAtLeading: false) }
        case .smallTopRight:
            // PiP covers the trailing nav corner + guesses chip: the menu
            // joins back/restart at leading; info chips pack leading.
            normalLayout(infoPack: .leading)
                .toolbar { gameToolbar(menuAtTrailing: false) }
        case .smallBottomLeft, .smallBottomRight:
            // PiP sits on the keyboard's bottom corner — the only genuinely
            // covered element. Lift the stack above the PiP footprint; top
            // chrome stays byte-identical to off-path.
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
                FiveLetterBoardView(theme: theme, guesses: viewModel.guesses, currentGuess: viewModel.currentGuess, invalidCount: viewModel.invalidCount)
                messageLine
                FiveLetterKeyboardView(
                    theme: theme,
                    guesses: viewModel.guesses,
                    onLetter: { viewModel.input($0) },
                    onDelete: { viewModel.deleteLast() },
                    onSubmit: { viewModel.submit() }
                )
                .opacity(viewModel.isTerminal ? 0.45 : 1)
                .allowsHitTesting(!viewModel.isTerminal)
            }
            .padding(.bottom, bottomClearance > 0 ? bottomClearance : theme.spacing.l)

            if viewModel.isTerminal && !bannerDismissed {
                endBanner
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: settingsStore.hapticsEnabled ? viewModel.submitCount : 0)
        .sensoryFeedback(.error, trigger: settingsStore.hapticsEnabled ? viewModel.invalidCount : 0)
        .sensoryFeedback(.success, trigger: settingsStore.hapticsEnabled ? viewModel.winCount : 0)
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
                FiveLetterBoardView(theme: theme, guesses: viewModel.guesses, currentGuess: viewModel.currentGuess, invalidCount: viewModel.invalidCount)
                FiveLetterKeyboardView(
                    theme: theme,
                    guesses: viewModel.guesses,
                    onLetter: { viewModel.input($0) },
                    onDelete: { viewModel.deleteLast() },
                    onSubmit: { viewModel.submit() }
                )
                .opacity(viewModel.isTerminal ? 0.45 : 1)
                .allowsHitTesting(!viewModel.isTerminal)
                compactControlRow
            }
            .padding(.bottom, theme.spacing.l)

            if viewModel.isTerminal && !bannerDismissed {
                endBanner
            }
        }
    }

    @ViewBuilder
    private func infoRow(compact: Bool, pack: InfoPack = .spread) -> some View {
        HStack(spacing: theme.spacing.s) {
            if pack == .trailing { Spacer() }
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: viewModel.timerAnchor,
                pausedElapsed: viewModel.pausedElapsed,
                compact: compact
            )
            if pack == .spread { Spacer() }
            Text("\(viewModel.guesses.count)/6")
                .font(compact ? theme.typography.caption : theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .contentTransition(.numericText(value: Double(viewModel.guesses.count)))
                .feedbackAnimation(theme.motion.ease, value: viewModel.guesses.count)
                .gameInfoReadout(theme: theme, compact: compact)
            if pack == .leading { Spacer() }
        }
        .padding(.horizontal, theme.spacing.m)
    }

    private var messageLine: some View {
        Text(viewModel.message ?? viewModel.statusText)
            .font(theme.typography.caption)
            .foregroundStyle(viewModel.message == nil ? theme.colors.textSecondary : theme.colors.accentPrimary)
            .frame(height: theme.spacing.l)
    }

    private var compactControlRow: some View {
        VideoCompactControlRow(theme: theme, onBack: { dismiss() }, onSettings: nil) {
            Text(viewModel.mode.displayName)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textPrimary)
        } picker: {
            EmptyView()
        } secondaryInfo: {
            Button { viewModel.restart() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(theme.colors.textPrimary)
            }
            .disabled(!viewModel.canRestart)
            .accessibilityLabel(Text("Restart puzzle"))
        }
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
                .disabled(!viewModel.canRestart)
                .accessibilityLabel(Text("Restart puzzle"))
        }
        ToolbarItem(placement: menuAtTrailing ? .topBarTrailing : .topBarLeading) {
            Menu {
                ForEach(FiveLetterMode.allCases, id: \.self) { mode in
                    Button(mode.displayName) { viewModel.setMode(mode) }
                }
                Divider()
                Button(viewModel.strictModeEnabled ? "Strict mode: On" : "Strict mode: Off") {
                    viewModel.toggleStrictMode()
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
                outcome: viewModel.state == .won ? .win : .loss,
                title: viewModel.state == .won ? String(localized: "Solved") : String(localized: "Answer: \(viewModel.answer)"),
                subtitle: viewModel.state == .won ? String(localized: "\(viewModel.guesses.count) guesses") : nil,
                primaryButtonLabel: viewModel.mode == .daily ? String(localized: "Play unlimited") : String(localized: "Next puzzle"),
                accessibilityLabel: viewModel.state == .won ? "Solved" : "Answer \(viewModel.answer)",
                onPrimary: {
                    bannerDismissed = false
                    if viewModel.mode == .daily {
                        viewModel.setMode(.unlimited)
                    } else {
                        viewModel.restart()
                    }
                },
                secondaryButtonLabel: String(localized: "View board"),
                secondaryAction: { bannerDismissed = true },
                tertiaryButtonLabel: String(localized: "Change mode"),
                tertiaryAction: {
                    viewModel.setMode(viewModel.mode == .daily ? .unlimited : .daily)
                    bannerDismissed = false
                }
            ),
            location: videoModeStore.location,
            hapticsEnabled: settingsStore.hapticsEnabled,
            reduceMotion: reduceMotion,
            animationsEnabled: settingsStore.animationsEnabled
        )
    }
}
