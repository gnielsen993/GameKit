import SwiftUI
import DesignKit

// MARK: - InteractiveTableauView
//
// Drag-and-drop card tableau for the design prototype.
// Rules: Klondike tableau stacking (alternating color, descending rank).
//        Kings go on empty columns. Any sub-stack can be picked up.
// All cards are face-up (FreeCell style — the face-down mechanic is
// intentionally left out of the prototype).

struct InteractiveTableauView: View {
    let theme: Theme
    let isClassic: Bool

    // Board geometry constants
    private let cardWidth: CGFloat  = 58
    private let fanOffset: CGFloat  = 26   // vertical distance between fanned cards
    private let colSpacing: CGFloat = 10
    private let boardPad: CGFloat   = 12
    private let colCount           = 5
    private var cardHeight: CGFloat { cardWidth * 1.4 }
    private var maxColHeight: CGFloat { cardHeight + 7 * fanOffset }  // room for 8 cards
    private var boardHeight: CGFloat  { boardPad * 2 + maxColHeight + 20 }

    private var boardColor: Color {
        SolitaireFelt.boardColor(theme: theme, isClassic: isClassic)
    }

    // MARK: State

    @State private var columns: [[PlayingCard]] = Self.initialDeal()

    // Active drag
    @State private var isDragging      = false
    @State private var dragFromCol     = 0
    @State private var dragFromIdx     = 0
    @State private var dragOffset      = CGSize.zero
    @State private var highlightCol: Int? = nil
    @State private var activeDragCards: [PlayingCard] = []

    // Sensory feedback triggers (counter-trigger pattern per DESIGN.md §8)
    @State private var pickUpTick   = 0
    @State private var dropTick     = 0
    @State private var rejectTick   = 0

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HStack {
                label("Interactive — drag to stack")
                Spacer()
                Button {
                    isDragging = false; dragOffset = .zero; highlightCol = nil; activeDragCards = []
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        columns = Self.initialDeal()
                    }
                } label: {
                    Text("Reset")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.accentPrimary)
                }
            }

            ZStack(alignment: .topLeading) {
                // Felt / board background
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .fill(boardColor)
                    .frame(height: boardHeight)

                // Columns inside a named coordinate space
                HStack(alignment: .top, spacing: colSpacing) {
                    ForEach(0..<colCount, id: \.self) { colIdx in
                        columnStack(colIdx)
                    }
                }
                .coordinateSpace(.named("board"))
                .padding(boardPad)
                .gesture(boardGesture)

                // Dragged stack overlay (rendered above everything)
                if isDragging {
                    draggedOverlay
                }
            }
            .frame(height: boardHeight)

            ruleHint
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pickUpTick)
        .sensoryFeedback(.success, trigger: dropTick)
        .sensoryFeedback(.error, trigger: rejectTick)
    }

    // MARK: - Column view

    private func columnStack(_ colIdx: Int) -> some View {
        let cards = columns[colIdx]
        let isTarget = highlightedAndValid(colIdx)
        let isHovered = highlightCol == colIdx && isDragging

        return ZStack(alignment: .top) {
            // Empty slot outline — always present as drop indicator
            RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                .stroke(
                    isTarget  ? theme.colors.success :
                    isHovered ? theme.colors.warning.opacity(0.6) :
                                .white.opacity(0.18),
                    lineWidth: isTarget || isHovered ? 2 : 1
                )
                .background(
                    RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                        .fill(isTarget ? theme.colors.success.opacity(0.10) : Color.clear)
                )
                .frame(width: cardWidth, height: cardHeight)

            // Cards fanned downward
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                let isGhosted = isDragging && dragFromCol == colIdx && idx >= dragFromIdx
                PlayingCardView(card, theme: theme, isClassic: isClassic, width: cardWidth)
                    .offset(y: CGFloat(idx) * fanOffset)
                    .zIndex(Double(idx))
                    .opacity(isGhosted ? 0.15 : 1.0)
            }
        }
        .frame(width: cardWidth, height: maxColHeight, alignment: .top)
    }

    // MARK: - Dragged overlay

    private var draggedOverlay: some View {
        let x = boardPad + CGFloat(dragFromCol) * (cardWidth + colSpacing) + dragOffset.width
        let y = boardPad + CGFloat(dragFromIdx) * fanOffset + dragOffset.height

        return ZStack(alignment: .top) {
            ForEach(Array(activeDragCards.enumerated()), id: \.element.id) { idx, card in
                PlayingCardView(card, theme: theme, isClassic: isClassic, width: cardWidth)
                    .offset(y: CGFloat(idx) * fanOffset)
                    .zIndex(Double(idx))
            }
        }
        .frame(width: cardWidth)
        .scaleEffect(1.04, anchor: .top)
        .shadow(color: .black.opacity(0.30), radius: 14, x: 0, y: 8)
        .offset(x: x, y: y)
        .zIndex(999)
        .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.9), value: dragOffset)
    }

    // MARK: - Gesture

    private var boardGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("board"))
            .onChanged { value in
                if !isDragging {
                    // Determine tapped column and card index from startLocation
                    guard
                        let col = colAt(x: value.startLocation.x),
                        let idx = cardAt(y: value.startLocation.y, col: col),
                        columns[col][idx].isFaceUp
                    else { return }
                    dragFromCol    = col
                    dragFromIdx    = idx
                    activeDragCards = Array(columns[col][idx...])
                    isDragging     = true
                    pickUpTick    += 1
                }
                dragOffset   = value.translation
                highlightCol = colAt(x: value.location.x)
            }
            .onEnded { _ in finalizeDrop() }
    }

    // MARK: - Drop logic

    private func finalizeDrop() {
        let target = highlightCol

        if let t = target, t != dragFromCol, canDrop(onto: t) {
            // Valid drop — move the stack
            let moved = Array(columns[dragFromCol][dragFromIdx...])
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                columns[dragFromCol].removeSubrange(dragFromIdx...)
                columns[t].append(contentsOf: moved)
            }
            dropTick += 1
        } else {
            // Invalid drop — snap back (ghost un-ghosts, overlay disappears)
            rejectTick += 1
        }

        isDragging      = false
        dragOffset      = .zero
        highlightCol    = nil
        activeDragCards = []
    }

    private func canDrop(onto targetCol: Int) -> Bool {
        guard let card = activeDragCards.first else { return false }
        if columns[targetCol].isEmpty { return card.canGoOnEmpty }
        guard let top = columns[targetCol].last else { return false }
        return card.canStack(onto: top)
    }

    private func highlightedAndValid(_ colIdx: Int) -> Bool {
        guard isDragging, highlightCol == colIdx else { return false }
        return canDrop(onto: colIdx)
    }

    // MARK: - Coordinate helpers
    // Coordinate space "board" has its origin at the top-left corner of the
    // HStack that carries .coordinateSpace(.named("board")). The HStack sits
    // inside the ZStack after .padding(boardPad) on the outside, so within
    // the "board" space column i starts at x = i*(cardWidth+colSpacing) and
    // cards start at y = 0. No boardPad offset is needed here.

    private func colAt(x: CGFloat) -> Int? {
        guard x >= 0 else { return nil }
        let col = Int(x / (cardWidth + colSpacing))
        guard col >= 0 && col < colCount else { return nil }
        return col
    }

    private func cardAt(y: CGFloat, col: Int) -> Int? {
        guard y >= 0 else { return nil }
        let cards = columns[col]
        // Walk from the bottom-most (highest-index) card upward to find
        // the topmost card whose fan offset is ≤ the touch y.
        for idx in stride(from: cards.count - 1, through: 0, by: -1) {
            if y >= CGFloat(idx) * fanOffset { return idx }
        }
        return cards.isEmpty ? nil : 0
    }

    // MARK: - Initial deal
    //
    // Setup gives the user clear valid and invalid moves to discover:
    //   Col 0: K♠ alone          → can move to empty col 4
    //   Col 1: Q♥, J♠            → J♠ (black) on Q♥ (red) — valid stack
    //   Col 2: Q♠, J♥, 10♣       → valid descending alternating sequence
    //   Col 3: 9♦, 8♣            → valid; 9♦ (red) can receive 8♣ (black)
    //   Col 4: empty             → only a King may land here

    static func initialDeal() -> [[PlayingCard]] {
        [
            [PlayingCard(rank: .king,  suit: .spades)],
            [PlayingCard(rank: .queen, suit: .hearts),
             PlayingCard(rank: .jack,  suit: .spades)],
            [PlayingCard(rank: .queen, suit: .spades),
             PlayingCard(rank: .jack,  suit: .hearts),
             PlayingCard(rank: .ten,   suit: .clubs)],
            [PlayingCard(rank: .nine,  suit: .diamonds),
             PlayingCard(rank: .eight, suit: .clubs)],
            []
        ]
    }

    // MARK: - Hint label

    private var ruleHint: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Stack: lower rank · opposite colour · King to empty")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
            Text("Green border = valid drop · Pick up a stack by tapping any card in it")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textTertiary)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textSecondary)
            .textCase(.uppercase)
    }
}
