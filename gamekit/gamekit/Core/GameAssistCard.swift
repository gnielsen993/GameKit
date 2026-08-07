import SwiftUI
import DesignKit

/// Shared presentation for game-specific coaching. The card owns no game
/// state and performs no deduction; each game supplies copy and actions.
struct GameAssistCard: View {
    let theme: Theme
    let title: String
    let message: String
    var progress: String? = nil
    var tone: Tone = .accent
    var primaryAction: Action? = nil
    let onDismiss: () -> Void

    enum Tone { case accent, warning, neutral }

    struct Action {
        let title: String
        let perform: () -> Void
    }

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.s) {
            Image(systemName: tone == .warning ? "exclamationmark.triangle.fill" : "lightbulb.fill")
                .font(theme.typography.body.weight(.semibold))
                .foregroundStyle(toneColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(theme.colors.surfaceElevated)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
                    Text(title)
                        .font(theme.typography.body.weight(.semibold))
                        .foregroundStyle(theme.colors.textPrimary)

                    Spacer(minLength: theme.spacing.s)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(theme.typography.caption.weight(.semibold))
                            .foregroundStyle(theme.colors.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Dismiss hint"))
                }

                Text(message)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let progress {
                    Text(progress)
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(toneColor)
                }

                if let primaryAction {
                    Button(primaryAction.title, action: primaryAction.perform)
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colors.accentPrimary)
                        .frame(minHeight: 44)
                        .accessibilityHint(Text("Applies this hint"))
                }
            }
        }
        .padding(theme.spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(theme.colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .stroke(toneColor, lineWidth: 1)
        )
        .padding(.horizontal, theme.spacing.m)
        .accessibilityElement(children: .contain)
    }

    private var toneColor: Color {
        switch tone {
        case .accent: return theme.colors.accentPrimary
        case .warning: return theme.colors.danger
        case .neutral: return theme.colors.textTertiary
        }
    }
}

struct GameAssistToolbarButton: View {
    let theme: Theme
    let label: String
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "lightbulb")
                .font(theme.typography.body.weight(.semibold))
                .foregroundStyle(theme.colors.accentPrimary)
                .frame(
                    width: compact ? theme.spacing.xl : 44,
                    height: compact ? theme.spacing.xl : 44
                )
                .background(compact ? theme.colors.surface : Color.clear)
                .clipShape(
                    RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// Keeps coaching clear of both the game board and the Video Mode window.
/// Off-path help reserves space at the top. In Video Mode it moves to the
/// vertical edge opposite the selected PiP zone.
enum GameAssistPlacement {
    static func edge(videoModeEnabled: Bool, location: VideoModeLocation) -> VerticalEdge {
        guard videoModeEnabled else { return .top }
        switch location {
        case .largeTop, .smallTopLeft, .smallTopRight:
            return .bottom
        case .largeBottom, .smallBottomLeft, .smallBottomRight:
            return .top
        }
    }
}

private struct GameAssistInsetModifier<Assist: View>: ViewModifier {
    let theme: Theme
    let assist: Assist
    @Environment(\.videoModeStore) private var videoModeStore

    func body(content: Content) -> some View {
        content.safeAreaInset(
            edge: GameAssistPlacement.edge(
                videoModeEnabled: videoModeStore.isEnabled,
                location: videoModeStore.location
            ),
            spacing: theme.spacing.s
        ) {
            assist
        }
    }
}

extension View {
    func gameAssistInset<Assist: View>(
        theme: Theme,
        @ViewBuilder assist: () -> Assist
    ) -> some View {
        modifier(GameAssistInsetModifier(theme: theme, assist: assist()))
    }
}
