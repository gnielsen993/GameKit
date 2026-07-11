import SwiftUI
import DesignKit

struct WordGridFoundWordsPanel: View {
    enum Layout {
        case rail
        case compact
    }

    let theme: Theme
    let words: [String]
    let layout: Layout

    @ViewBuilder
    var body: some View {
        if layout == .rail {
            panelContent
                .padding(theme.spacing.s)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                        .stroke(theme.colors.border, lineWidth: 1)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
        } else {
            panelContent
                .padding(.vertical, theme.spacing.xs)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HStack(spacing: theme.spacing.s) {
                Text(String(localized: "Found"))
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                Spacer()
                Text("\(words.count)")
                    .font(theme.typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.textSecondary)
                    .contentTransition(.numericText(value: Double(words.count)))
                    .feedbackAnimation(theme.motion.ease, value: words.count)
            }

            if words.isEmpty {
                Text(String(localized: "No words yet."))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView(layout == .rail ? .vertical : .horizontal, showsIndicators: false) {
                    if layout == .rail {
                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                            ForEach(words, id: \.self) { word in
                                wordRow(word)
                                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                            }
                        }
                        .feedbackAnimation(.spring(response: 0.3, dampingFraction: 0.75), value: words)
                    } else {
                        HStack(spacing: theme.spacing.xs) {
                            ForEach(words, id: \.self) { word in
                                wordPill(word)
                                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                            }
                        }
                        .feedbackAnimation(.spring(response: 0.3, dampingFraction: 0.75), value: words)
                    }
                }
            }
        }
    }

    private func wordRow(_ word: String) -> some View {
        HStack(spacing: theme.spacing.s) {
            Text(word)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: theme.spacing.s)
            Text("+\(WordGridEngine.score(word))")
                .monospacedDigit()
                .foregroundStyle(theme.colors.textSecondary)
        }
        .font(theme.typography.caption)
        .foregroundStyle(theme.colors.textPrimary)
    }

    private func wordPill(_ word: String) -> some View {
        HStack(spacing: theme.spacing.xs) {
            Text(word)
                .lineLimit(1)
            Text("+\(WordGridEngine.score(word))")
                .monospacedDigit()
                .foregroundStyle(theme.colors.textSecondary)
        }
        .font(theme.typography.caption)
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, theme.spacing.xs)
        .foregroundStyle(theme.colors.accentPrimary)
    }

    private var accessibilityLabel: Text {
        if words.isEmpty {
            return Text("No words found yet")
        }
        return Text("\(words.count) words found: \(words.joined(separator: ", "))")
    }
}
