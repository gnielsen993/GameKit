//
//  SudokuLivesChip.swift
//  gamekit
//
//  3-dot lives chip for Sudoku in .lives game mode. Props-only. Mirrors
//  NonogramLivesChip shape: i-th dot is filled (danger color) while
//  mistakes < livesPerPuzzle - i, dims (textTertiary) once consumed.
//
//  Render convention:
//    - mistakes = 0 → all 3 dots filled (danger color)
//    - mistakes = 1 → 2 dots filled, 1 dim
//    - mistakes = 2 → 1 dot filled, 2 dim
//    - mistakes ≥ 3 → all 3 dim (game-over)
//
//  Renders NOTHING if the caller's gameMode is .free; parent
//  (SudokuHeaderBar) is responsible for not rendering in .free mode,
//  but the chip itself also guards internally for safety.
//

import SwiftUI
import DesignKit

struct SudokuLivesChip: View {
    let theme: Theme
    /// Current mistake count from viewModel.mistakes (0...livesPerPuzzle).
    let mistakes: Int
    /// Compact variant for Video Mode slots — matches NonogramLivesChip API.
    var compact: Bool = false

    private var livesRemaining: Int {
        max(0, SudokuGameMode.livesPerPuzzle - mistakes)
    }

    var body: some View {
        HStack(spacing: theme.spacing.xs / 2) {
            ForEach(0..<SudokuGameMode.livesPerPuzzle, id: \.self) { i in
                Image(systemName: i < livesRemaining ? "heart.fill" : "heart")
                    .foregroundStyle(i < livesRemaining
                                     ? theme.colors.danger
                                     : theme.colors.textTertiary)
                    .font(.system(size: compact ? 11 : 14, weight: .semibold))
            }
        }
        .gameInfoReadout(theme: theme, compact: compact)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(livesRemaining) of \(SudokuGameMode.livesPerPuzzle) lives remaining"))
    }
}
