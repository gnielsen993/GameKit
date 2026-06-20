import SwiftUI
import DesignKit

// MARK: - SolitaireGameView drag gesture + hit-testing
//
// Tableau drag gesture, the three drop-finalizers (tableau / foundation /
// waste), and the column/card coordinate helpers extracted from
// SolitaireGameView to keep the host file under the §8.5 line cap. All drag
// `@State` and `vm` live on the host struct and are already non-private
// (shared with SolitaireGameView+VideoMode.swift), so these methods move
// across at their existing internal access with no signature changes.

extension SolitaireGameView {

    // MARK: - Drag gesture (tableau columns)

    func tableauDragGesture(cardW: CGFloat, gap: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("solitaire-tableau"))
            .onChanged { value in
                if !isDragging {
                    guard
                        let col = colAt(x: value.startLocation.x, cardW: cardW, gap: gap),
                        let idx = cardAt(y: value.startLocation.y, col: col, cardW: cardW),
                        vm.board.tableau[col][idx].isFaceUp
                    else { return }

                    let seq = SolitaireRules.pickableSequence(
                        from: vm.board.tableau[col], startingAt: idx
                    )
                    guard !seq.isEmpty else { return }

                    dragSourceCol   = col
                    dragFromIdx     = idx
                    dragCards       = seq
                    dragIsFromWaste = false
                    isDragging      = true
                    vm.clearSelection()
                    pickUpTick     += 1
                }
                dragOffset    = value.translation
                dropTargetCol = colAt(x: value.location.x, cardW: cardW, gap: gap)
            }
            .onEnded { val in finalizeDrop(value: val, cardW: cardW) }
    }

    func finalizeDrop(value: DragGesture.Value, cardW: CGFloat) {
        defer {
            isDragging      = false
            dragOffset      = .zero
            dropTargetCol   = nil
            dragCards       = []
            dragIsFromWaste = false
        }
        // Drop above the tableau → try to send single card to foundation
        if value.location.y < 0 && dragCards.count == 1 {
            if vm.sendToFoundation(column: dragSourceCol) {
                dropTick += 1
            } else {
                rejectTick += 1
            }
            return
        }
        guard
            let target = dropTargetCol,
            target != dragSourceCol,
            SolitaireRules.canPlaceOnTableau(dragCards, onto: vm.board.tableau[target])
        else {
            rejectTick += 1
            return
        }
        vm.commitDrag(fromColumn: dragSourceCol, fromIdx: dragFromIdx, toColumn: target)
        dropTick += 1
    }

    func finalizeFoundationDrop(suit: CardSuit, translation: CGSize, cardW: CGFloat) {
        defer {
            isDragging           = false
            dragOffset           = .zero
            dropTargetCol        = nil
            dragCards            = []
            dragIsFromFoundation = false
            dragFoundationSuit   = nil
        }
        // Require a deliberate downward drag into the tableau — a small jiggle
        // in the top row shouldn't fling a foundation card onto a column.
        guard translation.height > cardW * 0.7,
              let target = dropTargetCol,
              let rank = vm.board.foundations[suit.foundationIndex]
        else { rejectTick += 1; return }
        let card = PlayingCard(rank: rank, suit: suit)
        guard SolitaireRules.canPlaceOnTableau([card], onto: vm.board.tableau[target]) else {
            rejectTick += 1
            return
        }
        vm.commitFoundationDrag(suit: suit, toColumn: target)
        dropTick += 1
    }

    func finalizeWasteDrop(translation: CGSize, cardW: CGFloat) {
        defer {
            isDragging      = false
            dragOffset      = .zero
            dropTargetCol   = nil
            dragCards       = []
            dragIsFromWaste = false
        }
        // Drag stayed in the shelf row (< one card height down) → try foundation
        if translation.height < cardW * 1.4 {
            if vm.sendWasteToFoundation() {
                dropTick += 1
                return
            }
        }
        guard
            let target = dropTargetCol,
            let topCard = vm.board.topWaste,
            SolitaireRules.canPlaceOnTableau([topCard], onto: vm.board.tableau[target])
        else {
            rejectTick += 1
            return
        }
        vm.commitWasteDrag(toColumn: target)
        dropTick += 1
    }

    // MARK: - Coordinate helpers

    // x is in "solitaire-tableau" space (HStack local, before horizontal pad).
    func colAt(x: CGFloat, cardW: CGFloat, gap: CGFloat) -> Int? {
        guard x >= 0 else { return nil }
        let col = Int(x / (cardW + gap))
        guard col < 7 else { return nil }
        let colStart = CGFloat(col) * (cardW + gap)
        guard x < colStart + cardW else { return nil }
        return col
    }

    // x is in board-ZStack space (includes left pad); subtracts pad before col lookup.
    func colAtBoardX(_ x: CGFloat, cardW: CGFloat, gap: CGFloat, pad: CGFloat) -> Int? {
        colAt(x: x - pad, cardW: cardW, gap: gap)
    }

    func cardAt(y: CGFloat, col: Int, cardW: CGFloat) -> Int? {
        let column = vm.board.tableau[col]
        guard !column.isEmpty, y >= 0 else { return nil }
        let faceDownOff = cardW * 0.20
        let faceUpOff   = cardW * 0.46
        var offsets: [CGFloat] = [0]
        for i in 1..<column.count {
            offsets.append(offsets[i-1] + (column[i-1].isFaceUp ? faceUpOff : faceDownOff))
        }
        for idx in stride(from: column.count - 1, through: 0, by: -1) {
            if y >= offsets[idx] { return idx }
        }
        return 0
    }

    func columnYOffset(col: Int, fromIdx: Int, cardW: CGFloat) -> CGFloat {
        let column = vm.board.tableau[col]
        guard fromIdx > 0 else { return 0 }
        let faceDownOff = cardW * 0.20
        let faceUpOff   = cardW * 0.46
        return (0..<fromIdx).reduce(CGFloat(0)) { acc, i in
            acc + (column[i].isFaceUp ? faceUpOff : faceDownOff)
        }
    }

    func selectedFrom(col: Int) -> Int? {
        guard case .column(let c, let from) = vm.selection, c == col else { return nil }
        return from
    }
}
