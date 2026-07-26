//
//  NonogramBoardView+SlideGesture.swift
//  gamekit
//
//  Slide-to-fill drag subsystem extracted from NonogramBoardView to keep
//  the host file under the §8.5 line cap. Owns the smear gesture, fast-
//  swipe path interpolation, axis locking, touch-up precision targeting,
//  and the pure start-cell intent helper.
//
//  The drag's `@State` lives on the host struct (Swift extensions cannot
//  declare stored properties) and is plain `@State` (not `private`) so this
//  cross-file extension can read/write it — idiomatic for SwiftUI and the
//  tightest scope Swift allows once the gesture lives in another file.
//

import SwiftUI

extension NonogramBoardView {

    enum SlideAxis { case horizontal, vertical }

    func slideGesture(cellSize: CGFloat) -> some Gesture {
        // Start immediately so touch-down can preview the targeted cell.
        // Mutation waits until touch-up unless movement crosses the smear
        // threshold; this lets a player correct an adjacent-cell miss before
        // spending a life on a dense 20x20 board.
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard isInteractive, !dragAborted else { return }
                let xCell = value.location.x / cellSize
                let yCell = value.location.y / cellSize
                let row = Int(yCell.rounded(.down))
                let col = Int(xCell.rounded(.down))
                guard row >= 0, row < board.size, col >= 0, col < board.size else { return }

                if dragAxis == nil {
                    precisionRow = row
                    precisionCol = col
                }

                // First sample: lock the start cell + capture intent.
                // Use startLocation (where the finger actually landed), not
                // location (current position after minimumDistance crossed).
                // By the time onChanged fires, the finger may have drifted
                // into an adjacent cell, reading the wrong state and locking
                // the wrong fill/erase intent for the whole drag.
                if dragTarget == nil {
                    let sxCell = value.startLocation.x / cellSize
                    let syCell = value.startLocation.y / cellSize
                    let sRow = Int(syCell.rounded(.down))
                    let sCol = Int(sxCell.rounded(.down))
                    guard sRow >= 0, sRow < board.size, sCol >= 0, sCol < board.size else { return }
                    let startCell = board.cell(row: sRow, col: sCol)
                    dragTarget = Self.dragTarget(
                        mode: interactionMode,
                        currentCell: startCell
                    )
                    dragStartRow = sRow
                    dragStartCol = sCol
                    dragStartState = startCell
                }
                guard let target = dragTarget,
                      let startRow = dragStartRow,
                      let startCol = dragStartCol,
                      let startState = dragStartState
                else { return }

                // Decide axis only after enough travel to distinguish a
                // deliberate smear from repositioning within/near the tiny
                // target cell. Interpolation below backfills the full path.
                if dragAxis == nil {
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    if max(dx, dy) >= Self.dragActivationDistance(cellSize: cellSize) {
                        dragAxis = (dx >= dy) ? .horizontal : .vertical
                        precisionRow = nil
                        precisionCol = nil
                    }
                }

                // Until the gesture becomes a smear, targeting remains a
                // preview only. Touch-up commits the currently highlighted
                // cell exactly once.
                guard dragAxis != nil else { return }

                // Lock cell coords to the chosen axis. Until axis is set,
                // only the start cell is in play.
                let lockedRow = (dragAxis == .horizontal) ? startRow : row
                let lockedCol = (dragAxis == .vertical) ? startCol : col

                // Path interpolation — fast swipes can move several cells
                // between two onChanged samples; without filling the
                // intermediate cells the player sees gaps. Do not reject a
                // sample merely because it landed near the edge of its cell:
                // fast samples commonly do, and deferring them is what made
                // the rendered fill trail behind the finger. Axis locking
                // already prevents perpendicular spillover.
                let cellsToVisit: [(Int, Int)]
                if let prevRow = lastDragRow, let prevCol = lastDragCol {
                    cellsToVisit = Self.cellsBetween(
                        fromRow: prevRow, fromCol: prevCol,
                        toRow: lockedRow, toCol: lockedCol,
                        axis: dragAxis!,
                        startRow: startRow, startCol: startCol
                    )
                } else if let axis = dragAxis {
                    cellsToVisit = [(startRow, startCol)] + Self.cellsBetween(
                        fromRow: startRow, fromCol: startCol,
                        toRow: lockedRow, toCol: lockedCol,
                        axis: axis,
                        startRow: startRow, startCol: startCol
                    )
                } else {
                    cellsToVisit = []
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
                if dragAxis == nil,
                   let row = precisionRow,
                   let col = precisionCol,
                   isInteractive {
                    onTap(row, col)
                }
                dragTarget = nil
                dragVisited = []
                dragAborted = false
                dragAxis = nil
                dragStartRow = nil
                dragStartCol = nil
                dragStartState = nil
                lastDragRow = nil
                lastDragCol = nil
                precisionRow = nil
                precisionCol = nil
            }
    }

    /// Allow at least one neighboring-cell correction before interpreting a
    /// touch as a smear. Dense boards get a 24pt precision window; roomy
    /// boards cap at 32pt so swipe-to-fill remains responsive.
    static func dragActivationDistance(cellSize: CGFloat) -> CGFloat {
        min(max(cellSize * 1.5, 24), 32)
    }

    /// Inclusive cell path between two samples along the locked axis.
    /// Returns ALL cells the swipe crossed in left-to-right or top-to-bottom
    /// order so the caller can fill them in sequence — a fast swipe that
    /// jumps from cell 3 to cell 7 in one frame still gets cells 4, 5, 6.
    /// The "from" cell itself is omitted (already visited last frame).
    static func cellsBetween(
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
    static func dragTarget(
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
}
