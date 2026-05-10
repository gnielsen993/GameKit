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
    /// Most-recent row index that just transitioned to fully-satisfied.
    /// Drives a brief accent glow on every cell in that row so the
    /// player gets a visual "completed" beat. Nil → no flash.
    let flashRow: Int?
    let flashCol: Int?
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
    /// Cell state at the drag's start cell. Subsequent cells along the
    /// swipe path are only mutated when their current state matches this
    /// — so starting on a blank and swiping through filled cells leaves
    /// the filled cells alone (player intent is "extend the run of
    /// blanks I started on").
    @State private var dragStartState: NonogramCellState? = nil
    /// Most-recent sampled cell during the active drag — used to
    /// interpolate a continuous path through every intermediate cell
    /// when SwiftUI's onChanged samples don't catch every cell at high
    /// finger velocity.
    @State private var lastDragRow: Int? = nil
    @State private var lastDragCol: Int? = nil
    /// Locked-in axis for the current drag. nil until the player has moved
    /// far enough for SwiftUI to disambiguate horizontal vs vertical.
    @State private var dragAxis: SlideAxis? = nil

    private enum SlideAxis { case horizontal, vertical }

    private static let minCellSize: CGFloat = 14
    private static let minHintFont: CGFloat = 7
    /// Target board edge as a fraction of container width. Pinned so
    /// the grid stays the same size across difficulties — only the
    /// cells themselves shrink/grow as N changes.
    private static let gridEdgeFraction: CGFloat = 0.78
    /// Floor on the column-hint header height so vertical-hint stacks
    /// have headroom even at small N.
    private static let minColHintHeight: CGFloat = 80
    /// Per-hint horizontal slot factor inside the row-hint column.
    private static let perHintWidthFactor: CGFloat = 0.55

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
                        // Empty columns emit `[0]` per nonogram convention —
                        // render the 0 explicitly so the player sees a hint
                        // rather than a blank slot.
                        Text("\(value)")
                            .font(.system(size: layout.hintFont, weight: .semibold, design: .rounded))
                            .foregroundStyle(crossed
                                             ? theme.colors.textTertiary
                                             : theme.colors.textSecondary)
                            .strikethrough(crossed, color: theme.colors.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
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
                // 2pt between adjacent hint numbers — tighter than
                // theme.spacing.xs so "1 5" reads as two distinct hints
                // without sprawling, while "15" (a single 2-digit hint)
                // stays visually intact.
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    ForEach(Array((rowHints[safe: row] ?? []).enumerated()), id: \.offset) { idx, value in
                        let crossed = crossMask[safe: idx] ?? false
                        Text("\(value)")
                            .font(.system(size: layout.hintFont, weight: .semibold, design: .rounded))
                            .foregroundStyle(crossed
                                             ? theme.colors.textTertiary
                                             : theme.colors.textSecondary)
                            .strikethrough(crossed, color: theme.colors.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .fixedSize()
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
                            completionFlash: flashRow == row || flashCol == col,
                            onTap: { onTap(row, col) },
                            onLongPress: { onLongPress(row, col) }
                        )
                    }
                }
            }
        }
        // Bold 5×5 super-cell rules — standard nonogram convention so the
        // player can count cell positions without losing place. Drawn as
        // an overlay on top of the cell grid; doesn't intercept gestures.
        .overlay(superCellRules(cellSize: cellSize).allowsHitTesting(false))
        // Slide-to-fill: a drag with at-least-8pt movement starts a smear.
        // Below threshold, the per-cell tap/long-press gestures fire as
        // before. simultaneousGesture lets the drag coexist with the cell
        // gestures without one starving the other.
        .simultaneousGesture(slideGesture(cellSize: cellSize))
    }

    /// Bold internal grid lines every 5 cells. Drawn at full board span;
    /// edge lines (0 and `board.size`) are deliberately skipped — the
    /// outer board border lives on the cell view itself.
    @ViewBuilder
    private func superCellRules(cellSize: CGFloat) -> some View {
        let n = board.size
        let span = cellSize * CGFloat(n)
        let lineColor = theme.colors.textPrimary.opacity(0.55)
        let thickness: CGFloat = 1.5
        ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: 5, to: n, by: 5)), id: \.self) { i in
                let offset = cellSize * CGFloat(i)
                Rectangle()
                    .fill(lineColor)
                    .frame(width: thickness, height: span)
                    .offset(x: offset - thickness / 2, y: 0)
                Rectangle()
                    .fill(lineColor)
                    .frame(width: span, height: thickness)
                    .offset(x: 0, y: offset - thickness / 2)
            }
        }
        .frame(width: span, height: span, alignment: .topLeading)
    }

    private func slideGesture(cellSize: CGFloat) -> some Gesture {
        // 10pt minimum distance — back from 14pt now that path
        // interpolation handles fast swipes; high enough to avoid
        // accidental drags from finger reposition but low enough that a
        // quick swipe registers as a swipe instead of a tap.
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
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
                    dragStartState = startCell
                }
                guard let target = dragTarget,
                      let startRow = dragStartRow,
                      let startCol = dragStartCol,
                      let startState = dragStartState
                else { return }

                // Decide axis once the player has moved past the start cell.
                // Threshold lowered to 0.35 cells so the lock kicks in
                // quickly and downstream cells don't get spuriously
                // mutated before the axis is known.
                if dragAxis == nil {
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    if max(dx, dy) > cellSize * 0.35 {
                        dragAxis = (dx >= dy) ? .horizontal : .vertical
                    }
                }

                // Lock cell coords to the chosen axis. Until axis is set,
                // only the start cell is in play.
                let lockedRow = (dragAxis == .horizontal) ? startRow : row
                let lockedCol = (dragAxis == .vertical) ? startCol : col

                // Path interpolation — fast swipes can move several cells
                // between two onChanged samples; without filling the
                // intermediate cells the player sees gaps. Walk every
                // cell from the previous sample to the current one along
                // the locked axis so 60Hz sampling can't drop cells.
                let cellsToVisit: [(Int, Int)]
                if let prevRow = lastDragRow, let prevCol = lastDragCol,
                   dragAxis != nil {
                    cellsToVisit = cellsBetween(
                        fromRow: prevRow, fromCol: prevCol,
                        toRow: lockedRow, toCol: lockedCol,
                        axis: dragAxis!,
                        startRow: startRow, startCol: startCol
                    )
                } else {
                    cellsToVisit = [(lockedRow, lockedCol)]
                }
                lastDragRow = lockedRow
                lastDragCol = lockedCol

                for (r, c) in cellsToVisit {
                    let idx = r * board.size + c
                    if dragVisited.contains(idx) { continue }
                    dragVisited.insert(idx)
                    // Same-type filter: only flip cells that match the
                    // drag's start state. Start cell always commits.
                    let cellState = board.cell(row: r, col: c)
                    let isStart = (r == startRow && c == startCol)
                    guard isStart || cellState == startState else { continue }
                    let ok = onSlide(r, c, target)
                    if !ok {
                        dragAborted = true
                        break
                    }
                }
            }
            .onEnded { _ in
                dragTarget = nil
                dragVisited = []
                dragAborted = false
                dragAxis = nil
                dragStartRow = nil
                dragStartCol = nil
                dragStartState = nil
                lastDragRow = nil
                lastDragCol = nil
            }
    }

    /// Inclusive cell path between two samples along the locked axis.
    /// Returns ALL cells the swipe crossed in left-to-right or top-to-bottom
    /// order so the caller can fill them in sequence — a fast swipe that
    /// jumps from cell 3 to cell 7 in one frame still gets cells 4, 5, 6.
    /// The "from" cell itself is omitted (already visited last frame).
    private func cellsBetween(
        fromRow: Int, fromCol: Int,
        toRow: Int, toCol: Int,
        axis: SlideAxis,
        startRow: Int, startCol: Int
    ) -> [(Int, Int)] {
        switch axis {
        case .horizontal:
            let row = startRow
            if toCol == fromCol { return [(row, toCol)] }
            let step = toCol > fromCol ? 1 : -1
            return stride(from: fromCol + step, through: toCol, by: step)
                .map { (row, $0) }
        case .vertical:
            let col = startCol
            if toRow == fromRow { return [(toRow, col)] }
            let step = toRow > fromRow ? 1 : -1
            return stride(from: fromRow + step, through: toRow, by: step)
                .map { ($0, col) }
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

    /// Pin the GRID to a fixed proportion of the container, then size
    /// the hint columns/rows from whatever's left. Result: the board's
    /// outer dimensions stay roughly constant across difficulties — a
    /// 5×5 puzzle has big chunky cells, a 20×20 has small dense cells,
    /// but the player's eye lands on the same physical area each time.
    /// Matches the layout pattern from competitor nonogram apps.
    private func computeLayout(in size: CGSize) -> Layout {
        let maxRowHints = rowHints.map(\.count).max() ?? 1
        let maxColHints = columnHints.map(\.count).max() ?? 1

        // Target grid edge: keep board square and lean toward the
        // smaller container axis. 70% of width keeps a comfortable
        // hint margin; never exceed available height minus reserve for
        // column hints.
        let preferredEdge = size.width * Self.gridEdgeFraction
        let maxByHeight = size.height - Self.minColHintHeight
        let gridEdge = max(Self.minCellSize * CGFloat(board.size),
                           min(preferredEdge, maxByHeight))
        let cs = gridEdge / CGFloat(board.size)

        // Hint slots get whatever margin remains beside/above the grid.
        // Symmetric horizontal reserve so the grid is centered.
        let availableHintW = max(0, (size.width - gridEdge) / 2)
        let availableHintH = max(0, size.height - gridEdge)
        let rowHintW = min(availableHintW,
                           CGFloat(maxRowHints) * cs * Self.perHintWidthFactor)
        let colHintH = min(availableHintH,
                           CGFloat(maxColHints) * cs * 0.55)

        // Hint font scales with cell size but never drops below
        // minHintFont so a crowded 20×20 row stays legible. Cap on the
        // upper end so 5×5 hints don't look comically large.
        let hintFont = max(Self.minHintFont, min(cs * 0.42, 22))

        return Layout(
            cellSize: cs,
            rowHintColumnWidth: rowHintW,
            colHintRowHeight: colHintH,
            gridWidth: gridEdge,
            hintFont: hintFont
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
