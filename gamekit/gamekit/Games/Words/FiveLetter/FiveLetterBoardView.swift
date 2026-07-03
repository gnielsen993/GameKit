import SwiftUI
import DesignKit

struct FiveLetterBoardView: View {
    let theme: Theme
    let guesses: [FiveLetterGuess]
    let currentGuess: String
    /// VM counter bumped on each rejected guess — drives the current-row
    /// shake (DESIGN.md §10.2 wrong-move vocabulary). Callers that predate
    /// the shake can omit it; 0 never triggers.
    var invalidCount: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.settingsStore) private var settingsStore

    /// DESIGN.md §10.2 gate — reveal stagger, typing pop, and shake all
    /// hard-cut to instant when off.
    private var animated: Bool { settingsStore.animationsEnabled && !reduceMotion }

    var body: some View {
        VStack(spacing: theme.spacing.xs) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: theme.spacing.xs) {
                    ForEach(0..<5, id: \.self) { column in
                        FiveLetterTileView(
                            theme: theme,
                            content: tileContent(row: row, column: column),
                            column: column,
                            revealedRows: guesses.count,
                            animated: animated
                        )
                    }
                }
                // The animator is attached to every row with a shared trigger
                // (stable view identity — a row-dependent trigger or branch
                // would fire spurious shakes / break the reveal animation);
                // the offset is applied only to the current row.
                .keyframeAnimator(
                    initialValue: 0.0,
                    trigger: invalidCount
                ) { content, value in
                    content.offset(x: (animated && row == guesses.count) ? value : 0)
                } keyframes: { _ in
                    LinearKeyframe(8.0, duration: 0.1)
                    LinearKeyframe(-8.0, duration: 0.1)
                    LinearKeyframe(4.0, duration: 0.1)
                    LinearKeyframe(0.0, duration: 0.1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, theme.spacing.m)
        .layoutPriority(1)
    }

    private func tileContent(row: Int, column: Int) -> FiveLetterTileContent {
        if row < guesses.count {
            let guess = guesses[row]
            let letters = Array(guess.word)
            let mark = guess.marks.indices.contains(column) ? guess.marks[column] : .absent
            return FiveLetterTileContent(
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
        return FiveLetterTileContent(
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
}

struct FiveLetterTileContent {
    let letter: String
    let fill: Color
    let stroke: Color
    let textColor: Color
    let accessibility: String
}

/// Single board tile. Owns two motion behaviors (DESIGN.md §10.2):
///  - typing pop: a letter landing in the current row jolts to 1.12× and
///    springs back (keyframe, trigger-driven so rapid typing never coalesces)
///  - reveal stagger: when a guess is submitted, mark colors sweep across
///    the row left-to-right (60ms per column)
struct FiveLetterTileView: View {
    let theme: Theme
    let content: FiveLetterTileContent
    let column: Int
    let revealedRows: Int
    let animated: Bool

    @State private var typePopCount = 0

    var body: some View {
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
            .chipShadow()
            .animation(
                animated
                    ? .easeInOut(duration: theme.motion.normal).delay(Double(column) * 0.06)
                    : nil,
                value: revealedRows
            )
            .keyframeAnimator(initialValue: 1.0, trigger: typePopCount) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1.12, duration: 0.07)
                    SpringKeyframe(1.0, duration: 0.22, spring: Spring(response: 0.2, dampingRatio: 0.65))
                }
            }
            .onChange(of: content.letter) { oldValue, newValue in
                guard animated, oldValue.isEmpty, !newValue.isEmpty else { return }
                typePopCount += 1
            }
            .accessibilityLabel(Text(content.accessibility))
    }
}
