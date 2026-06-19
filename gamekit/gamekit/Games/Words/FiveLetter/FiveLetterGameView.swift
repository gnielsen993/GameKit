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
            if videoModeStore.isEnabled, videoModeStore.location.isLarge {
                largeZoneLayout
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                normalLayout
                    .toolbar { toolbarContent }
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

    @ViewBuilder
    private var normalLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(spacing: theme.spacing.s) {
                infoRow(compact: false)
                    .padding(.vertical, theme.spacing.xs)
                FiveLetterBoardView(theme: theme, guesses: viewModel.guesses, currentGuess: viewModel.currentGuess)
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
            .padding(.bottom, theme.spacing.l)

            if viewModel.isTerminal && !bannerDismissed {
                endBanner
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: settingsStore.hapticsEnabled ? viewModel.submitCount : 0)
        .sensoryFeedback(.error, trigger: settingsStore.hapticsEnabled ? viewModel.invalidCount : 0)
        .sensoryFeedback(.success, trigger: settingsStore.hapticsEnabled ? viewModel.winCount : 0)
    }

    @ViewBuilder
    private var largeZoneLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(spacing: theme.spacing.s) {
                if videoModeStore.location == .largeBottom {
                    compactControlRow
                }
                infoRow(compact: true)
                FiveLetterBoardView(theme: theme, guesses: viewModel.guesses, currentGuess: viewModel.currentGuess)
                FiveLetterKeyboardView(
                    theme: theme,
                    guesses: viewModel.guesses,
                    onLetter: { viewModel.input($0) },
                    onDelete: { viewModel.deleteLast() },
                    onSubmit: { viewModel.submit() }
                )
                .opacity(viewModel.isTerminal ? 0.45 : 1)
                .allowsHitTesting(!viewModel.isTerminal)
                if videoModeStore.location == .largeTop {
                    compactControlRow
                }
            }
            .padding(.bottom, theme.spacing.l)

            if viewModel.isTerminal && !bannerDismissed {
                endBanner
            }
        }
    }

    @ViewBuilder
    private func infoRow(compact: Bool) -> some View {
        HStack(spacing: theme.spacing.s) {
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: viewModel.timerAnchor,
                pausedElapsed: viewModel.pausedElapsed,
                compact: compact
            )
            Spacer()
            Text("\(viewModel.guesses.count)/6")
                .font(compact ? theme.typography.caption : theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .padding(.horizontal, compact ? theme.spacing.xs : theme.spacing.s)
                .padding(.vertical, theme.spacing.xs)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel(Text("Back to The Drawer"))
            Button { viewModel.restart() } label: { Image(systemName: "arrow.counterclockwise") }
                .disabled(!viewModel.canRestart)
                .accessibilityLabel(Text("Restart puzzle"))
        }
        ToolbarItem(placement: .topBarTrailing) {
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
