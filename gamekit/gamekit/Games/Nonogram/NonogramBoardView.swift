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
    /// Slide-fill callback. Returns `true` if the mutation went through
    /// cleanly. A `false` return aborts the drag — used in Lives mode
    /// when a swipe hits a wrong cell, so a careless smear can't burn
    /// every life in one motion.
    let onSlide: (Int, Int, NonogramCellState) -> Bool

    // Drag @State below is plain `@State` (not private) — read/written by
    // the slide gesture in NonogramBoardView+SlideGesture.swift.
    //
    /// Drag intent: the target cell state every drag-crossed cell should
    /// be set to. Picked at drag-start from the first cell's value.
    @State var dragTarget: NonogramCellState? = nil
    /// Flat indices (row * size + col) already mutated during the current
    /// drag, so re-entering a cell mid-swipe doesn't double-trigger.
    @State var dragVisited: Set<Int> = []
    /// Flipped true when a Lives-mode wrong attempt fires mid-drag. Locks
    /// out further onChanged events until the user lifts their finger.
    @State var dragAborted: Bool = false
    /// Drag start cell — used to lock subsequent cells to a single row
    /// (horizontal swipe) or column (vertical swipe).
    @State var dragStartRow: Int? = nil
    @State var dragStartCol: Int? = nil
    /// Cell state at the drag's start cell. Subsequent cells along the
    /// swipe path are only mutated when their current state matches this
    /// — so starting on a blank and swiping through filled cells leaves
    /// the filled cells alone (player intent is "extend the run of
    /// blanks I started on").
    @State var dragStartState: NonogramCellState? = nil
    /// Most-recent sampled cell during the active drag — used to
    /// interpolate a continuous path through every intermediate cell
    /// when SwiftUI's onChanged samples don't catch every cell at high
    /// finger velocity.
    @State var lastDragRow: Int? = nil
    @State var lastDragCol: Int? = nil
    /// Locked-in axis for the current drag. nil until the player has moved
    /// far enough for SwiftUI to disambiguate horizontal vs vertical.
    @State var dragAxis: SlideAxis? = nil

    // P12 D-NG-15 (Plan 12-05): gates floor in computeLayout only.
    // D-NG-17 untouched; seam constants in NonogramBoardView+VideoMode.swift.
    @Environment(\.videoModeStore) private var videoModeStore

    // SlideAxis + the slide gesture live in NonogramBoardView+SlideGesture.swift.

    // P12 D-NG-15: internal access for NonogramBoardView+VideoMode.swift; value 14 unchanged.
    static let minCellSize: CGFloat = 14
    private static let minHintFont: CGFloat = 7
    /// Target board edge as a fraction of container width. Pinned so
    /// the grid stays the same size across difficulties — only the
    /// cells themselves shrink/grow as N changes.
    private static let gridEdgeFraction: CGFloat = 0.78
    /// Floor on the column-hint header height so vertical-hint stacks
    /// have headroom even at small N.
    private static let minColHintHeight: CGFloat = 80
    /// Per-hint horizontal slot factor inside the row-hint column.
    /// 0.35 is the aggressive setting chosen after stress-mode testing
    /// showed cs=15 felt too small. Single-digit hints fit comfortably;
    /// 2-digit hints (e.g. "10", "18") shrink via minimumScaleFactor to
    /// stay inside the tighter slot. Math: 20·cs + 10·0.35·cs ≤ width →
    /// cs ≤ width/23.5, so on a 402pt screen we land at cs ≈ 17.1
    /// (vs 15.75 at 0.5).
    private static let perHintWidthFactor: CGFloat = 0.35
    /// Padding inside the hint strip on the OUTER edge (screen edge for
    /// row hints, screen top for column hints). Keeps the leftmost /
    /// topmost numbers from kissing the safe-area boundary.
    private static let hintPaddingOuter: CGFloat = 4
    /// Padding inside the hint strip on the INNER edge (against the
    /// grid border). Bumped to 12pt so the numbers float off the grid
    /// edge with clear breathing room rather than kissing the border.
    private static let hintPaddingInner: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let layout = computeLayout(in: proxy.size)
            // Single-side margin: all unused horizontal space sits to the
            // LEFT of the grid so row hints can claim it. Old symmetric
            // layout split the margin in two and clipped the long-end
            // hints under the grid on dense boards.
            let totalWidth = layout.gridWidth + layout.rowHintColumnWidth
            let totalHeight = layout.colHintRowHeight + layout.gridWidth // square grid

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: layout.rowHintColumnWidth, height: layout.colHintRowHeight)
                    columnHeader(layout: layout)
                        .frame(width: layout.gridWidth, height: layout.colHintRowHeight)
                }

                HStack(spacing: 0) {
                    rowHeader(layout: layout)
                        .frame(width: layout.rowHintColumnWidth, height: layout.gridWidth)
                    cellGrid(cellSize: layout.cellSize)
                        .frame(width: layout.gridWidth, height: layout.gridWidth)
                        // Sharp dark border around the grid so the play
                        // area reads as a defined object against the
                        // surrounding hint margin and page background.
                        .overlay(
                            Rectangle()
                                .stroke(theme.colors.textPrimary.opacity(0.85), lineWidth: 1.5)
                        )
                }
            }
            // Lock the composition to its exact computed size so SwiftUI's
            // proposal-based layout can't quietly inflate any sub-frame and
            // open a gap between the column hints and the grid. Pin the
            // composition to the TRAILING edge — row hints absorb all
            // unused horizontal margin on the left, grid sits flush at
            // the right edge of the screen so dense boards never clip.
            .frame(width: totalWidth, height: totalHeight)
            // Center the composition in the available space (both axes).
            // Any horizontal or vertical slack splits symmetrically so
            // the board reads as a deliberately placed object rather
            // than top-pinned with weight imbalance.
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
        // Breathing room inside the hint strip so numbers don't kiss
        // the screen top or the grid's top edge.
        .padding(.top, Self.hintPaddingOuter)
        .padding(.bottom, Self.hintPaddingInner)
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
        // Same breathing-room budget as the column hints, applied to
        // the leading edge (screen edge) and the trailing edge (grid
        // edge) — keeps the L-strip's inset feel symmetric on both axes.
        .padding(.leading, Self.hintPaddingOuter)
        .padding(.trailing, Self.hintPaddingInner)
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
                            onTap: { onTap(row, col) }
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
        let n = CGFloat(board.size)

        // Fixed grid edge — the OUTER composition footprint stays
        // constant across difficulties so the player's eye lands on the
        // same physical area each time. Smaller puzzles get chunky
        // cells, denser puzzles get small cells, but the board's
        // overall size doesn't shift around.
        //
        // gridEdgeFraction (0.78) of the container width is reserved
        // for the grid; the remaining horizontal margin holds the row
        // hints regardless of how many hints the puzzle actually has.
        // Hints rely on minimumScaleFactor to shrink digits into the
        // fixed slot when worst-case hint counts exceed the budget.
        let pad = Self.hintPaddingOuter + Self.hintPaddingInner
        let maxByHeight = size.height - Self.minColHintHeight
        let preferredEdge = size.width * Self.gridEdgeFraction
        let floor = Self.minCellSize(videoModeOn: videoModeStore.isEnabled)
        let gridEdge = max(floor * n,
                           min(preferredEdge, maxByHeight))
        let cs = gridEdge / n

        // Hint slots take all leftover margin on each axis. This stays
        // CONSTANT as N changes — hint area for 5×5 looks the same
        // physical size as hint area for 20×20.
        let availableHintW = max(0, size.width - gridEdge)
        let availableHintH = max(0, size.height - gridEdge)
        let rowHintW = availableHintW
        let colHintH = min(availableHintH,
                           max(Self.minColHintHeight,
                               CGFloat(maxColHints) * cs * 0.55 + pad))

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
