import SwiftUI
import SwiftData
import DesignKit

struct AppEntryRootView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.settingsStore) private var settingsStore

    let startupController: AppStartupController

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    private var transitionAnimation: Animation? {
        guard settingsStore.animationsEnabled else { return nil }
        return .easeOut(duration: theme.motion.normal)
    }

    var body: some View {
        ZStack {
            Color("BrandLaunchBackground")
                .ignoresSafeArea()

            switch startupController.presentation {
            case .preparing:
                BrandedEntryView(
                    theme: theme,
                    showsProgress: startupController.feedback.showsProgress
                )
                .transition(entryTransition)

            case .ready:
                if let container = startupController.container {
                    RootTabView()
                        .modelContainer(container)
                        .transition(.opacity)
                }

            case .failed:
                StartupRecoveryView(theme: theme) {
                    Task { await startupController.retry() }
                }
                .transition(.opacity)
            }
        }
        .animation(transitionAnimation, value: startupController.presentation)
        .task {
            await startupController.start()
        }
    }

    private var entryTransition: AnyTransition {
        if reduceMotion || !settingsStore.animationsEnabled {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: 1.02))
    }
}

private struct BrandedEntryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.settingsStore) private var settingsStore

    let theme: Theme
    let showsProgress: Bool

    @State private var isSettled = false

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(
                    width: theme.spacing.xxl * 5,
                    height: theme.spacing.xxl * 5
                )
                .scaleEffect(isSettled ? 1 : 0.97)
                .opacity(isSettled ? 1 : 0.9)
                .accessibilityLabel(Text(AppInfo.displayName))
                .accessibilityIdentifier("brand-entry-logo")

            if showsProgress {
                ProgressView()
                    .tint(Color("BrandLaunchForeground"))
                    .accessibilityLabel(String(localized: "Opening GameDrawer"))
                    .accessibilityIdentifier("startup-progress")
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard settingsStore.animationsEnabled else {
                isSettled = true
                return
            }
            if reduceMotion {
                withAnimation(.easeOut(duration: theme.motion.fast)) {
                    isSettled = true
                }
            } else {
                withAnimation(.easeOut(duration: theme.motion.slow)) {
                    isSettled = true
                }
            }
        }
    }
}

private struct StartupRecoveryView: View {
    let theme: Theme
    let retry: () -> Void

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(
                    width: theme.spacing.xxl * 3,
                    height: theme.spacing.xxl * 3
                )
                .accessibilityHidden(true)

            VStack(spacing: theme.spacing.s) {
                Text(String(localized: "GameDrawer couldn't open"))
                    .font(theme.typography.title)
                Text(String(localized: "Your game data hasn't been changed. Try opening it again."))
                    .font(theme.typography.body)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color("BrandLaunchForeground"))

            DKButton(
                String(localized: "Try Again"),
                style: .primary,
                theme: theme,
                action: retry
            )
            .accessibilityLabel(String(localized: "Try opening GameDrawer again"))
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.accessibility5)
        .accessibilityIdentifier("startup-recovery")
    }
}
