//
//  SudokuBoardView.swift
//  gamekit
//
//  9×9 Sudoku board renderer. Uses a VStack/HStack grid of SudokuCellView
//  with a single-pass Path overlay to draw the thin inter-cell dividers and
//  separate Path overlays for the thicker 3×3 box borders. All borders
//  are non-interactive overlays (.allowsHitTesting(false)) so taps pass
//  through to the underlying cell tap gesture.
//
//  Token note: plan referenced `theme.colors.accent` which does not exist;
//  using `theme.colors.accentPrimary` (the correct token name per ThemeColors).
//
//  Theme audit (Phase 15-04, 2026-05-19): verified under Classic +
//  Voltage + Dracula presets on iPhone 17 Pro sim. Cell digits (givens
//  vs user vs notes), selected/peer/same-number highlights, wrong-flash
//  danger overlay, and box borders all distinguishable per CLAUDE §8.12.
//

import SwiftUI
import DesignKit

struct SudokuBoardView: View {
    @Bindable var viewModel: SudokuViewModel
    let theme: Theme

    static let size = SudokuBoard.size       // 9
    static let boxSize = SudokuBoard.boxSize // 3

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cellSide = side / CGFloat(Self.size)

            ZStack {
                gridBackground
                cellGrid(cellSide: cellSide)
                thinDividerOverlay(side: side)
                boxBorderOverlay(side: side)
                outerBorder(side: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var gridBackground: some View {
        Rectangle()
            .fill(theme.colors.surface)
    }

    @ViewBuilder
    private func cellGrid(cellSide: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<Self.size, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<Self.size, id: \.self) { c in
                        let board = viewModel.board ?? emptyBoard()
                        let cell = board.cell(row: r, col: c)
                        let highlight = highlightTier(row: r, col: c)
                        let isFlash = viewModel.lastWrongAttemptIdx == r * 9 + c
                        SudokuCellView(
                            cell: cell,
                            highlight: highlight,
                            isWrongFlashing: isFlash,
                            theme: theme
                        )
                        .frame(width: cellSide, height: cellSide)
                        .onTapGesture {
                            viewModel.select(row: r, col: c)
                        }
                    }
                }
            }
        }
    }

    /// Single-pass Path overlay drawing 0.5pt lines between every cell row and
    /// column, EXCLUDING the 3× box lines (those are drawn by boxBorderOverlay
    /// at 2pt). Non-interactive: .allowsHitTesting(false) so taps reach cells.
    @ViewBuilder
    private func thinDividerOverlay(side: CGFloat) -> some View {
        let step = side / CGFloat(Self.size)
        Path { p in
            for i in 1..<Self.size where i % Self.boxSize != 0 {
                let x = CGFloat(i) * step
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: side))
                p.move(to: CGPoint(x: 0, y: x))
                p.addLine(to: CGPoint(x: side, y: x))
            }
        }
        .stroke(theme.colors.border.opacity(0.40), lineWidth: 0.5)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func boxBorderOverlay(side: CGFloat) -> some View {
        let third = side / 3
        Path { p in
            p.move(to: CGPoint(x: third, y: 0))
            p.addLine(to: CGPoint(x: third, y: side))
            p.move(to: CGPoint(x: 2 * third, y: 0))
            p.addLine(to: CGPoint(x: 2 * third, y: side))
            p.move(to: CGPoint(x: 0, y: third))
            p.addLine(to: CGPoint(x: side, y: third))
            p.move(to: CGPoint(x: 0, y: 2 * third))
            p.addLine(to: CGPoint(x: side, y: 2 * third))
        }
        .stroke(theme.colors.border, lineWidth: 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func outerBorder(side: CGFloat) -> some View {
        Rectangle()
            .stroke(theme.colors.border, lineWidth: 2)
            .frame(width: side, height: side)
            .allowsHitTesting(false)
    }

    private func highlightTier(row: Int, col: Int) -> SudokuCellView.HighlightTier {
        guard let sel = viewModel.selected else { return .none }
        if sel.row == row && sel.col == col { return .selected }

        // Same-number tier: if selected cell has a value and this cell shares it.
        if let board = viewModel.board {
            let selValue = board.cell(row: sel.row, col: sel.col).value
            let thisValue = board.cell(row: row, col: col).value
            if let sv = selValue, let tv = thisValue, sv == tv {
                return .sameNumber
            }
        }

        // Peer tier: same row, column, or 3×3 box.
        let peers = SudokuBoard.peerIndices(row: sel.row, col: sel.col)
        if peers.contains(row * 9 + col) { return .peer }

        return .none
    }

    private func emptyBoard() -> SudokuBoard {
        // Defensive fallback — shouldn't actually render before VM loads.
        let zeros = String(repeating: "0", count: 81)
        let ones  = String(repeating: "1", count: 81)
        return SudokuBoard(givens: zeros, solution: ones)!
    }
}
