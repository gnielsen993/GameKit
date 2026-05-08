//
//  NonogramBoardView.swift
//  gamekit
//
//  Composes the row hint column, column hint row, and the cell grid into
//  a single board. Sizing mirrors MinesweeperBoardView: GeometryReader
//  measures the available area, then divides between hint headers and
//  cell grid.
//
//  Hint header sizing (rule of thumb): max-hints-per-line × cellSize × 0.7
//  per hint slot, capped at 25% of the available axis. The 0.7 factor is
//  the column-header width allowance per hint number; tuned for tabular
//  numerals at 0.55 of cellSize.
//

import SwiftUI
import DesignKit

struct NonogramBoardView: View {
    let board: NonogramBoard
    let rowHints: [[Int]]
    let columnHints: [[Int]]
    let theme: Theme
    let isInteractive: Bool
    let onTap: (Int, Int) -> Void
    let onLongPress: (Int, Int) -> Void

    private static let minCellSize: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            let layout = computeLayout(in: proxy.size)
            VStack(spacing: 0) {
                // Top: blank corner + column hints row.
                HStack(spacing: 0) {
                    Color.clear.frame(width: layout.rowHintColumnWidth)
                    columnHeader(cellSize: layout.cellSize)
                }
                .frame(height: layout.colHintRowHeight)

                // Body: row hints column + cell grid.
                HStack(spacing: 0) {
                    rowHeader(cellSize: layout.cellSize, rowHintWidth: layout.rowHintColumnWidth)
                    cellGrid(cellSize: layout.cellSize)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
    }

    // MARK: - Header strips

    private func columnHeader(cellSize: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<board.size, id: \.self) { col in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ForEach(Array(columnHints[safe: col]?.enumerated() ?? [].enumerated()), id: \.offset) { _, value in
                        Text(value > 0 ? "\(value)" : "")
                            .font(.system(size: cellSize * 0.4, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.colors.textSecondary)
                            .monospacedDigit()
                    }
                }
                .frame(width: cellSize)
            }
        }
    }

    private func rowHeader(cellSize: CGFloat, rowHintWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<board.size, id: \.self) { row in
                HStack(spacing: theme.spacing.xs) {
                    Spacer(minLength: 0)
                    ForEach(Array(rowHints[safe: row]?.enumerated() ?? [].enumerated()), id: \.offset) { _, value in
                        Text(value > 0 ? "\(value)" : "")
                            .font(.system(size: cellSize * 0.4, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.colors.textSecondary)
                            .monospacedDigit()
                    }
                }
                .frame(width: rowHintWidth, height: cellSize)
                .padding(.trailing, theme.spacing.xs)
            }
        }
    }

    // MARK: - Cell grid

    private func cellGrid(cellSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<board.size, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<board.size, id: \.self) { col in
                        NonogramCellView(
                            state: board.cell(row: row, col: col),
                            cellSize: cellSize,
                            theme: theme,
                            isInteractive: isInteractive,
                            onTap: { onTap(row, col) },
                            onLongPress: { onLongPress(row, col) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Layout

    private struct Layout {
        let cellSize: CGFloat
        let rowHintColumnWidth: CGFloat
        let colHintRowHeight: CGFloat
    }

    private func computeLayout(in size: CGSize) -> Layout {
        let maxRowHints = rowHints.map(\.count).max() ?? 1
        let maxColHints = columnHints.map(\.count).max() ?? 1

        // Reserve up to 25% of the axis for hint headers.
        let maxHintWidth = size.width * 0.25
        let maxHintHeight = size.height * 0.25

        // Estimate hint header dims from cell size guess; iterate twice
        // (rough fixed-point) so the estimate stabilizes.
        var cs = Self.minCellSize
        for _ in 0..<2 {
            let rowHintWidth = min(CGFloat(maxRowHints) * cs * 0.7, maxHintWidth)
            let colHintHeight = min(CGFloat(maxColHints) * cs * 0.55, maxHintHeight)
            let usableW = size.width - rowHintWidth
            let usableH = size.height - colHintHeight
            let widthBound = usableW / CGFloat(board.size)
            let heightBound = usableH / CGFloat(board.size)
            cs = max(Self.minCellSize, min(widthBound, heightBound))
        }

        let rowHintWidth = min(CGFloat(maxRowHints) * cs * 0.7, maxHintWidth)
        let colHintHeight = min(CGFloat(maxColHints) * cs * 0.55, maxHintHeight)
        return Layout(cellSize: cs, rowHintColumnWidth: rowHintWidth, colHintRowHeight: colHintHeight)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
