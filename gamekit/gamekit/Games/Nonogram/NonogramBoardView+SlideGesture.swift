//
//  NonogramBoardView+SlideGesture.swift
//  gamekit
//
//  Slide-to-fill drag subsystem extracted from NonogramBoardView to keep
//  the host file under the §8.5 line cap. Owns the smear gesture, fast-
//  swipe path interpolation, axis locking, the cell-edge deadzone, and the
//  pure start-cell intent helper.
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
        // 12pt minimum distance — between the original 14 and the 10
        // we landed on after path interpolation. Higher than 10 so a
        // brushing finger doesn't kick off a drag, lower than 14 so a
        // committed quick swipe still registers without a perceived tap
        // delay.
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard isInteractive, !dragAborted else { return }
                // Cell-detection with fractional position. xFrac/yFrac
                // are the 0..1 offset within the current cell on each
                // axis; used downstream for the cell-edge deadzone that
                // stops "my finger drifted past the border but I didn't
                // mean to enter the next cell" misfires.
                let xCell = value.location.x / cellSize
                let yCell = value.location.y / cellSize
                let xFrac = xCell - xCell.rounded(.down)
                let yFrac = yCell - yCell.rounded(.down)
                let row = Int(yCell.rounded(.down))
                let col = Int(xCell.rounded(.down))
                guard row >= 0, row < board.size, col >= 0, col < board.size else { return }

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

                // Cell-edge deadzone — restored from commit 538cbe1.
                // When the finger crosses into a NEW cell on the active
                // axis, the touch must be past the outer 22% before we
                // commit. Stops drifted-past-the-border misfires that
                // mark adjacent rows mid-swipe. Path interpolation
                // (below) still backfills if the finger truly crossed
                // through, but a glancing finger that barely nicks the
                // border is rejected.
                if let prevRow = lastDragRow, let prevCol = lastDragCol,
                   dragAxis != nil,
                   prevRow != lockedRow || prevCol != lockedCol {
                    let activeFrac: CGFloat = (dragAxis == .horizontal) ? xFrac : yFrac
                    if activeFrac < 0.22 || activeFrac > 0.78 {
                        return
                    }
                }

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
