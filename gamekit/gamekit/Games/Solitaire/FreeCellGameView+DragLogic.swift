import SwiftUI
import DesignKit

// MARK: - FreeCellGameView drag logic
//
// Drag gesture math (source pick-up, live target validation, drop
// resolution) extracted from FreeCellGameView to keep the host file under
// the §8.5 line cap. The drag `@State` (`dragState`, `dragTarget`,
// `headerHeight`) and `vm` live on the host struct and are already
// non-private (shared with FreeCellGameView+VideoMode.swift); the helper
// math methods below drop to internal access for the cross-file move.

extension FreeCellGameView {

    func onDragChanged(
        _ val: DragGesture.Value,
        cardW: CGFloat, cardH: CGFloat, shelfH: CGFloat,
        boardPad: CGFloat, colGap: CGFloat, geoW: CGFloat
    ) {
        if let ds = dragState {
            dragState?.location = val.location
            dragTarget = validatedDragTarget(
                at: val.location, dragging: ds.cards, from: ds.source,
                cardW: cardW, shelfH: shelfH, boardPad: boardPad, colGap: colGap, geoW: geoW
            )
            return
        }
        // First movement — compute source
        guard let (sel, offset) = computeSource(
            at: val.startLocation,
            cardW: cardW, cardH: cardH, shelfH: shelfH,
            boardPad: boardPad, colGap: colGap, geoW: geoW
        ) else { return }
        let cards: [PlayingCard] = {
            switch sel {
            case .column(let col, let idx): return Array(vm.board.columns[col][idx...])
            case .freeCell(let cell):       return vm.board.freeCells[cell].map { [$0] } ?? []
            case .foundation(let suit):
                let fidx = vm.board.foundationIndex(for: suit)
                return vm.board.foundations[fidx].map { [PlayingCard(rank: $0, suit: suit)] } ?? []
            }
        }()
        guard !cards.isEmpty else { return }
        vm.clearSelection()
        dragState = FreeCellDragState(
            source: sel, cards: cards,
            location: val.location, touchOffset: offset,
            cardWidth: cardW
        )
    }

    func onDragEnded(
        _ val: DragGesture.Value,
        cardW: CGFloat, shelfH: CGFloat,
        boardPad: CGFloat, colGap: CGFloat, geoW: CGFloat
    ) {
        defer { dragState = nil; dragTarget = nil }
        guard let ds = dragState else { return }
        guard let dest = computeDropTarget(
            at: val.location,
            cardW: cardW, shelfH: shelfH,
            boardPad: boardPad, colGap: colGap, geoW: geoW
        ) else { return }
        vm.applyDragDrop(from: ds.source, to: dest)
    }

    // Returns (selection, touchOffsetWithinCard) or nil if location is not draggable.
    func computeSource(
        at loc: CGPoint,
        cardW: CGFloat, cardH: CGFloat, shelfH: CGFloat,
        boardPad: CGFloat, colGap: CGFloat, geoW: CGFloat
    ) -> (FreeCellSelection, CGPoint)? {
        let shelfTopY  = headerHeight
        let shelfBotY  = headerHeight + shelfH
        let boardTopY  = shelfBotY + 8   // .padding(.top, 8) on board HStack

        if loc.y >= shelfTopY && loc.y < shelfBotY {
            // Shelf zone — free cells (left) and foundations (right) are draggable
            let freeCellsW = 4 * cardW + 3 * colGap
            let cardTopY   = shelfTopY + 10  // .padding(.vertical, 10)

            // Free cells (left group)
            let relX = loc.x - boardPad
            if relX >= 0 && relX < freeCellsW {
                let cellIdx = max(0, min(3, Int(relX / (cardW + colGap))))
                guard vm.board.freeCells[cellIdx] != nil else { return nil }
                let cardTopX = boardPad + CGFloat(cellIdx) * (cardW + colGap)
                let offset = CGPoint(
                    x: max(0, min(cardW, loc.x - cardTopX)),
                    y: max(0, min(cardH, loc.y - cardTopY))
                )
                return (.freeCell(cellIdx: cellIdx), offset)
            }

            // Foundations (right group) — drag the top card back into play
            let foundStartX = geoW - boardPad - freeCellsW
            if loc.x >= foundStartX {
                let fRelX = loc.x - foundStartX
                let i     = max(0, min(3, Int(fRelX / (cardW + colGap))))
                let suit  = CardSuit.allCases[i]
                guard vm.board.foundations[vm.board.foundationIndex(for: suit)] != nil else { return nil }
                let cardTopX = foundStartX + CGFloat(i) * (cardW + colGap)
                let offset = CGPoint(
                    x: max(0, min(cardW, loc.x - cardTopX)),
                    y: max(0, min(cardH, loc.y - cardTopY))
                )
                return (.foundation(suit: suit), offset)
            }
            return nil
        }

        if loc.y >= boardTopY {
            let relX = loc.x - boardPad
            guard relX >= 0 else { return nil }
            let col = max(0, min(7, Int(relX / (cardW + colGap))))
            let colCards = vm.board.columns[col]
            guard !colCards.isEmpty else { return nil }
            let localY = loc.y - boardTopY
            let fo = FreeCellColumnView.fanOffset(for: colCards.count, cardWidth: cardW)
            let cardIdx = max(0, min(colCards.count - 1, Int(localY / fo)))
            let dragCards = Array(colCards[cardIdx...])
            guard FreeCellRules.isValidSequence(dragCards) else { return nil }
            let limit = FreeCellRules.maxMoveable(board: vm.board, toEmptyColumn: false)
            guard dragCards.count <= limit else { return nil }
            let cardTopX = boardPad + CGFloat(col) * (cardW + colGap)
            let cardTopY = boardTopY + CGFloat(cardIdx) * fo
            let offset = CGPoint(
                x: max(0, min(cardW, loc.x - cardTopX)),
                y: max(0, min(cardH, loc.y - cardTopY))
            )
            return (.column(colIdx: col, startCardIdx: cardIdx), offset)
        }
        return nil
    }

    private func validatedDragTarget(
        at loc: CGPoint, dragging cards: [PlayingCard], from source: FreeCellSelection,
        cardW: CGFloat, shelfH: CGFloat, boardPad: CGFloat, colGap: CGFloat, geoW: CGFloat
    ) -> FreeCellDest? {
        guard let raw = computeDropTarget(at: loc, cardW: cardW, shelfH: shelfH,
                                          boardPad: boardPad, colGap: colGap, geoW: geoW)
        else { return nil }
        switch raw {
        case .column(let col):
            let isSrc: Bool = { if case .column(let c, _) = source { return c == col } else { return false } }()
            if isSrc { return nil }
            let dst = vm.board.columns[col]
            let canPlace = FreeCellRules.canPlace(cards[0], onto: dst)
            let limit = FreeCellRules.maxMoveable(board: vm.board, toEmptyColumn: dst.isEmpty)
            return (canPlace && cards.count <= limit) ? raw : nil
        case .freeCell(let idx):
            return (cards.count == 1 && vm.board.freeCells[idx] == nil) ? raw : nil
        case .foundation:
            return (cards.count == 1 &&
                    FreeCellRules.canMoveToFoundation(cards[0], foundations: vm.board.foundations)) ? raw : nil
        }
    }

    func computeDropTarget(
        at loc: CGPoint,
        cardW: CGFloat, shelfH: CGFloat,
        boardPad: CGFloat, colGap: CGFloat, geoW: CGFloat
    ) -> FreeCellDest? {
        let shelfTopY  = headerHeight
        let shelfBotY  = headerHeight + shelfH
        let boardTopY  = shelfBotY + 8

        if loc.y >= shelfTopY && loc.y < shelfBotY {
            let freeCellsW = 4 * cardW + 3 * colGap
            let relX = loc.x - boardPad
            if relX >= 0 && relX < freeCellsW {
                let cellIdx = max(0, min(3, Int(relX / (cardW + colGap))))
                return .freeCell(cellIdx)
            }
            let foundStartX = geoW - boardPad - freeCellsW
            if loc.x >= foundStartX { return .foundation }
            return nil
        }

        if loc.y >= boardTopY {
            let relX = loc.x - boardPad
            guard relX >= 0 else { return nil }
            let col = max(0, min(7, Int(relX / (cardW + colGap))))
            return .column(col)
        }
        return nil
    }
}
