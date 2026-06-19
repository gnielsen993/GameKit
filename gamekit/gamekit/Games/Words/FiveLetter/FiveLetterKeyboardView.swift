import SwiftUI
import DesignKit

struct FiveLetterKeyboardView: View {
    let theme: Theme
    let guesses: [FiveLetterGuess]
    let onLetter: (Character) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void

    private let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

    var body: some View {
        VStack(spacing: theme.spacing.xs) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: theme.spacing.xs) {
                    if row == "ZXCVBNM" {
                        actionButton(title: "Enter", action: onSubmit)
                    }
                    ForEach(Array(row), id: \.self) { letter in
                        letterButton(letter)
                    }
                    if row == "ZXCVBNM" {
                        iconButton(systemName: "delete.left", action: onDelete)
                    }
                }
            }
        }
        .padding(.horizontal, theme.spacing.m)
    }

    @ViewBuilder
    private func letterButton(_ letter: Character) -> some View {
        Button { onLetter(letter) } label: {
            Text(String(letter))
                .font(theme.typography.body.weight(.semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(keyFill(letter))
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Letter \(String(letter))"))
    }

    @ViewBuilder
    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(String(localized: "\(title)"))
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Delete"))
    }

    private func keyFill(_ letter: Character) -> Color {
        var best: FiveLetterMark?
        for guess in guesses {
            let letters = Array(guess.word)
            for index in letters.indices where letters[index] == letter {
                let mark = guess.marks[index]
                if mark == .correct { return theme.colors.success.opacity(0.7) }
                if mark == .present { best = .present }
                if best == nil { best = mark }
            }
        }
        switch best {
        case .present: return theme.colors.warning.opacity(0.7)
        case .absent: return theme.colors.textTertiary.opacity(0.35)
        case .correct: return theme.colors.success.opacity(0.7)
        case nil: return theme.colors.surface
        }
    }
}
