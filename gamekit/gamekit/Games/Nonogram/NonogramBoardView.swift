//
//  NonogramBoardView.swift
//  gamekit
//
//  Composes row hints, column hints, and the cell grid into one board.
//
//  Centering: the GRID itself is centered on screen — row hints jut into
//  the left margin, balanced by an equivalent invisible right spacer.
//  This is why the cell-size formula reserves `2 × rowHintWidth` of axis
//  width even though hints only render on one side.
//
//  Long-hint safety: worst-case alternating-fill rows produce ceil(N/2)
//  hint numbers (10 for a 20-cell row). The hint header gets up to 32%
//  of the axis width, the per-hint slot scales down to a `minHintFont`
//  floor for legibility, and the rendering uses spacing of 0 between
//  numbers when they get tight.
//

import SwiftUI
import DesignKit

struct NonogramBoardView: View {
    let board: NonogramBoard
    let rowHints: [[Int]]
    let columnHints: [[Int]]
    /// Per-row, per-hint-index cross-off mask. `rowsCrossOff[r][i] = true`
    /// when hint `i` of row `r` has been satisfied by a uniquely-positioned
    /// player run. The renderer strikes through that single number.
    let rowsCrossOff: [[Bool]]
    let columnsCrossOff: [[Bool]]
    let theme: Theme
    let isInteractive: Bool
    /// Current interaction mode (Place / Mark). Drag intent is computed
    /// from (mode, first-cell-state) so a slide in Mark mode lays down
    /// X marks instead of fills.
    let interactionMode: NonogramInteractionMode
    /// Flat-index of the most-recent wrong-tap cell (Lives mode). nil =
    /// no flash. Forwarded to CellView so the matching cell renders the
    /// red overlay + shake.
    let wrongFlashIdx: Int?
    let onTap: (Int, Int) -> Void
    let onLongPress: (Int, Int) -> Void
    /// Slide-fill callback. Returns `true` if the mutation went through
    /// cleanly. A `false` return aborts the drag — used in Lives mode
    /// when a swipe hits a wrong cell, so a careless smear can't burn
    /// every life in one motion.
    let onSlide: (Int, Int, NonogramCellState) -> Bool

    /// Drag intent: the target cell state every drag-crossed cell should
    /// be set to. Picked at drag-start from the first cell's value.
    @State private var dragTarget: NonogramCellState? = nil
    /// Flat indices (row * size + col) already mutated during the current
    /// drag, so re-entering a cell mid-swipe doesn't double-trigger.
    @State private var dragVisited: Set<Int> = []
    /// Flipped true when a Lives-mode wrong attempt fires mid-drag. Locks
    /// out further onChanged events until the user lifts their finger.
    @State private var dragAborted: Bool = false
    /// Drag start cell — used to lock subsequent cells to a single row
    /// (horizontal swipe) or column (vertical swipe).
    @State private var dragStartRow: Int? = nil
    @State private var dragStartCol: Int? = nil
    /// Locked-in axis for the current drag. nil until the player has moved
    /// far enough for SwiftUI to disambiguate horizontal vs vertical.
    @State private var dragAxis: SlideAxis? = nil

    private enum SlideAxis { case horizontal, vertical }

    private static let minCellSize: CGFloat = 14
    private static let minHintFont: CGFloat = 8
    private static let maxHintFractionH: CGFloat = 0.32
    private static let maxHintFractionV: CGFloat = 0.32

    var body: some View {
        GeometryReader { proxy in
            let layout = computeLayout(in: proxy.size)
            let totalWidth = layout.gridWidth + 2 * layout.rowHintColumnWidth
            let totalHeight = layout.colHintRowHeight + layout.gridWidth // square grid

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: layout.rowHintColumnWidth, height: layout.colHintRowHeight)
                    columnHeader(layout: layout)
                        .frame(width: layout.gridWidth, height: layout.colHintRowHeight)
                    Color.clear
                        .frame(width: layout.rowHintColumnWidth, height: layout.colHintRowHeight)
                }

                HStack(spacing: 0) {
                    rowHeader(layout: layout)
                        .frame(width: layout.rowHintColumnWidth, height: layout.gridWidth)
                    cellGrid(cellSize: layout.cellSize)
                        .frame(width: layout.gridWidth, height: layout.gridWidth)
                    Color.clear
                        .frame(width: layout.rowHintColumnWidth, height: layout.gridWidth)
                }
            }
            // Lock the composition to its exact computed size so SwiftUI's
            // proposal-based layout can't quietly inflate any sub-frame and
            // open a gap between the column hints and the grid.
            .frame(width: totalWidth, height: totalHeight)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
    }

    // MARK: - Header strips

    private func columnHeader(layout: Layout) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<board.size, id: \.self) { col in
                let crossMask = columnsCrossOff[safe: col] ?? []
                VStack(spacing: 0) {
                    ForEach(Array((columnHints[safe: col] ?? []).enumerated()), id: \.offset) { idx, value in
                        let crossed = crossMask[safe: idx] ?? false
                        Text(value > 0 ? "\(value)" : "")
                            .font(.system(size: layout.hintFont, weight: .semibold, design: .rounded))
                            .foregroundStyle(crossed
                                             ? theme.colors.textTertiary
                                             : theme.colors.textSecondary)
                            .monospacedDigit()
                            .strikethrough(crossed, color: theme.colors.textTertiary)
                    }
                }
                .frame(width: layout.cellSize, height: layout.colHintRowHeight, alignment: .bottom)
            }
        }
    }

    private func rowHeader(layout: Layout) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<board.size, id: \.self) { row in
                let crossMask = rowsCrossOff[safe: row] ?? []
                HStack(spacing: theme.spacing.xs) {
                    Spacer(minLength: 0)
                    ForEach(Array((rowHints[safe: row] ?? []).enumerated()), id: \.offset) { idx, value in
                        let crossed = crossMask[safe: idx] ?? false
                        Text(value > 0 ? "\(value)" : "")
                            .font(.system(size: layout.hintFont, weight: .semibold, design: .rounded))
                            .foregroundStyle(crossed
                                             ? theme.colors.textTertiary
                                             : theme.colors.textSecondary)
                            .monospacedDigit()
                            .strikethrough(crossed, color: theme.colors.textTertiary)
                    }
                }
                .frame(width: layout.rowHintColumnWidth, height: layout.cellSize)
            }
        }
    }

    // MARK: - Cell grid

    private func cellGrid(cellSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<board.size, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<board.size, id: \.self) { col in
                        let idx = row * board.size + col
                        NonogramCellView(
                            state: board.cell(row: row, col: col),
                            cellSize: cellSize,
                            theme: theme,
                            isInteractive: isInteractive,
                            wrongFlash: wrongFlashIdx == idx,
                            onTap: { onTap(row, col) },
                            onLongPress: { onLongPress(row, col) }
                        )
                    }
                }
            }
        }
        // Slide-to-fill: a drag with at-least-8pt movement starts a smear.
        // Below threshold, the per-cell tap/long-press gestures fire as
        // before. simultaneousGesture lets the drag coexist with the cell
        // gestures without one starving the other.
        .simultaneousGesture(slideGesture(cellSize: cellSize))
    }

    private func slideGesture(cellSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard isInteractive, !dragAborted else { return }
                let row = Int((value.location.y / cellSize).rounded(.down))
                let col = Int((value.location.x / cellSize).rounded(.down))
                guard row >= 0, row < board.size, col >= 0, col < board.size else { return }

                // First sample: lock the start cell + capture intent.
                if dragTarget == nil {
                    let startCell = board.cell(row: row, col: col)
                    dragTarget = Self.dragTarget(
                        mode: interactionMode,
                        currentCell: startCell
                    )
                    dragStartRow = row
                    dragStartCol = col
                }
                guard let target = dragTarget,
                      let startRow = dragStartRow,
                      let startCol = dragStartCol
                else { return }

                // Decide axis once the player has moved past the start cell.
                if dragAxis == nil {
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    if max(dx, dy) > cellSize * 0.5 {
                        dragAxis = (dx >= dy) ? .horizontal : .vertical
                    }
                }

                // Lock cell coords to the chosen axis. Until axis is set,
                // only the start cell is in play.
                let lockedRow = (dragAxis == .horizontal) ? startRow : row
                let lockedCol = (dragAxis == .vertical) ? startCol : col
                let idx = lockedRow * board.size + lockedCol

                if dragVisited.contains(idx) { return }
                dragVisited.insert(idx)
                let ok = onSlide(lockedRow, lockedCol, target)
                if !ok {
                    dragAborted = true
                }
            }
            .onEnded { _ in
                dragTarget = nil
                dragVisited = []
                dragAborted = false
                dragAxis = nil
                dragStartRow = nil
                dragStartCol = nil
            }
    }

    /// Mirror of NonogramViewModel's tap-toggle logic for the drag's
    /// start cell. Pure function so the rule can be unit-tested without
    /// spinning up a view hierarchy.
    private static func dragTarget(
        mode: NonogramInteractionMode,
        currentCell: NonogramCellState
    ) -> NonogramCellState {
        switch (mode, currentCell) {
        case (.place, .filled):                  return .empty
        case (.place, .empty), (.place, .marked): return .filled
        case (.mark, .marked):                   return .empty
        case (.mark, .empty), (.mark, .filled):  return .marked
        }
    }

    // MARK: - Layout

    private struct Layout {
        let cellSize: CGFloat
        let rowHintColumnWidth: CGFloat
        let colHintRowHeight: CGFloat
        let gridWidth: CGFloat
        let hintFont: CGFloat
    }

    /// Two-pass fixed-point: cell size depends on hint widths, hint widths
    /// depend on cell size. Three iterations is plenty for the estimate
    /// to converge to a stable value.
    private func computeLayout(in size: CGSize) -> Layout {
        let maxRowHints = rowHints.map(\.count).max() ?? 1
        let maxColHints = columnHints.map(\.count).max() ?? 1

        let hintCapW = size.width * Self.maxHintFractionH
        let hintCapH = size.height * Self.maxHintFractionV

        // Per-hint horizontal slot factor: drops as hint count climbs so the
        // hint column doesn't blow past its 32% cap. 0.7 for sparse rows,
        // ~0.45 for crowded ones.
        let perHintW = max(0.45, min(0.7, 1.0 / CGFloat(maxRowHints) * 4.5))

        var cs = Self.minCellSize
        for _ in 0..<3 {
            let rowHintW = min(CGFloat(maxRowHints) * cs * perHintW, hintCapW)
            let colHintH = min(CGFloat(maxColHints) * cs * 0.55, hintCapH)
            // Reserve symmetric space on left + right so the grid centers.
            let usableW = size.width - 2 * rowHintW
            let usableH = size.height - colHintH
            let widthBound = usableW / CGFloat(board.size)
            let heightBound = usableH / CGFloat(board.size)
            cs = max(Self.minCellSize, min(widthBound, heightBound))
        }

        let rowHintW = min(CGFloat(maxRowHints) * cs * perHintW, hintCapW)
        let colHintH = min(CGFloat(maxColHints) * cs * 0.55, hintCapH)
        let gridW = cs * CGFloat(board.size)

        // Hint font scales with cell size but never drops below `minHintFont`
        // so a crowded 20×20 row still has legible numbers.
        let hintFont = max(Self.minHintFont, cs * 0.4)

        return Layout(
            cellSize: cs,
            rowHintColumnWidth: rowHintW,
            colHintRowHeight: colHintH,
            gridWidth: gridW,
            hintFont: hintFont
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
