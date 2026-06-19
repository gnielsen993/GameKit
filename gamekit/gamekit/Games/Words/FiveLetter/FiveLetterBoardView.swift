import SwiftUI
import DesignKit

struct FiveLetterBoardView: View {
    let theme: Theme
    let guesses: [FiveLetterGuess]
    let currentGuess: String

    var body: some View {
        VStack(spacing: theme.spacing.xs) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: theme.spacing.xs) {
                    ForEach(0..<5, id: \.self) { column in
                        tile(row: row, column: column)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, theme.spacing.m)
        .layoutPriority(1)
    }

    @ViewBuilder
    private func tile(row: Int, column: Int) -> some View {
        let content = tileContent(row: row, column: column)
        Text(content.letter)
            .font(theme.typography.title.weight(.bold))
            .foregroundStyle(content.textColor)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: 54, maxHeight: 54)
            .aspectRatio(1, contentMode: .fit)
            .background(content.fill)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                    .stroke(content.stroke, lineWidth: 1)
            )
            .accessibilityLabel(Text(content.accessibility))
    }

    private func tileContent(row: Int, column: Int) -> TileContent {
        if row < guesses.count {
            let guess = guesses[row]
            let letters = Array(guess.word)
            let mark = guess.marks.indices.contains(column) ? guess.marks[column] : .absent
            return TileContent(
                letter: letters.indices.contains(column) ? String(letters[column]) : "",
                fill: fill(for: mark),
                stroke: fill(for: mark),
                textColor: theme.colors.background,
                accessibility: "\(letters.indices.contains(column) ? String(letters[column]) : "blank"), \(mark.rawValue)"
            )
        }

        let currentLetters = Array(currentGuess)
        let letter = row == guesses.count && currentLetters.indices.contains(column)
            ? String(currentLetters[column])
            : ""
        return TileContent(
            letter: letter,
            fill: theme.colors.surface,
            stroke: letter.isEmpty ? theme.colors.border : theme.colors.accentPrimary,
            textColor: theme.colors.textPrimary,
            accessibility: letter.isEmpty ? "Empty letter" : "Letter \(letter)"
        )
    }

    private func fill(for mark: FiveLetterMark) -> Color {
        switch mark {
        case .correct: return theme.colors.success
        case .present: return theme.colors.warning
        case .absent: return theme.colors.textTertiary
        }
    }

    private struct TileContent {
        let letter: String
        let fill: Color
        let stroke: Color
        let textColor: Color
        let accessibility: String
    }
}
