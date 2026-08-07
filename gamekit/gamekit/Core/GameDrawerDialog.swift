import SwiftUI
import DesignKit

/// A themed, in-context replacement for system alerts and action sheets on
/// game screens. Game state stays visible behind the scrim while choices use
/// the same tokens and button language as the rest of GameDrawer.
struct GameDrawerDialogAction {
    enum Style {
        case primary
        case secondary
        case destructive
        case quiet
    }

    let title: String
    var style: Style = .secondary
    let perform: () -> Void
}

struct GameDrawerDialog: View {
    let theme: Theme
    let title: String
    let message: String?
    let systemImage: String
    let actions: [GameDrawerDialogAction]

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            VStack(spacing: theme.spacing.s) {
                Image(systemName: systemImage)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.colors.accentPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(theme.colors.surfaceElevated)
                    )
                    .accessibilityHidden(true)

                Text(title)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                if let message, !message.isEmpty {
                    Text(message)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: theme.spacing.s) {
                ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                    actionButton(action)
                }
            }
        }
        .padding(theme.spacing.l)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(theme.colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .padding(.horizontal, theme.spacing.l)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func actionButton(_ action: GameDrawerDialogAction) -> some View {
        switch action.style {
        case .primary:
            DKButton(action.title, style: .primary, theme: theme, action: action.perform)
        case .secondary:
            DKButton(action.title, style: .secondary, theme: theme, action: action.perform)
        case .destructive:
            Button(action: action.perform) {
                Text(action.title)
                    .font(theme.typography.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, theme.spacing.s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colors.surfaceElevated)
            .background(theme.colors.danger)
            .clipShape(
                RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
            )
        case .quiet:
            Button(action: action.perform) {
                Text(action.title)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GameDrawerDialogModifier: ViewModifier {
    let isPresented: Bool
    let theme: Theme
    let title: String
    let message: String?
    let systemImage: String
    let actions: [GameDrawerDialogAction]

    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
                .allowsHitTesting(!isPresented)
                .accessibilityHidden(isPresented)

            if isPresented {
                theme.colors.background
                    .opacity(0.82)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }

                ViewThatFits(in: .vertical) {
                    dialog

                    ScrollView {
                        dialog
                            .padding(.vertical, theme.spacing.l)
                    }
                    .scrollIndicators(.hidden)
                }
                .transition(
                    reduceMotion || !settingsStore.animationsEnabled
                        ? .identity
                        : .opacity.combined(with: .scale(scale: 0.96))
                )
            }
        }
        .animation(
            reduceMotion || !settingsStore.animationsEnabled ? nil : theme.motion.ease,
            value: isPresented
        )
    }

    private var dialog: some View {
        GameDrawerDialog(
            theme: theme,
            title: title,
            message: message,
            systemImage: systemImage,
            actions: actions
        )
    }
}

extension View {
    func gameDrawerDialog(
        isPresented: Bool,
        theme: Theme,
        title: String,
        message: String? = nil,
        systemImage: String = "sparkles",
        actions: [GameDrawerDialogAction]
    ) -> some View {
        modifier(
            GameDrawerDialogModifier(
                isPresented: isPresented,
                theme: theme,
                title: title,
                message: message,
                systemImage: systemImage,
                actions: actions
            )
        )
    }
}
