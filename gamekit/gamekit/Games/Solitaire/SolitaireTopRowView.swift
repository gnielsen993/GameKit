import SwiftUI
import DesignKit

struct SolitaireTopRowView: View {
    let foundations: [CardRank?]   // 4 slots — index by CardSuit.foundationIndex
    let stock:       [PlayingCard]
    let waste:       [PlayingCard]
    let theme:       Theme
    let isClassic:   Bool
    let cardWidth:   CGFloat
    var selectedIsWaste:      Bool      = false
    var selectedFoundationSuit: CardSuit? = nil
    var draggingFoundationSuit: CardSuit? = nil
    var onStockTap:           () -> Void
    var onWasteTap:         () -> Void
    var onWasteDoubleTap:   () -> Void
    var onFoundationTap:    (CardSuit) -> Void
    var onWasteDragChanged: ((CGSize) -> Void)? = nil
    var onWasteDragEnded:   ((CGSize) -> Void)? = nil
    var onFoundationDragChanged: ((CardSuit, CGSize) -> Void)? = nil
    var onFoundationDragEnded:   ((CardSuit, CGSize) -> Void)? = nil

    private var cardHeight: CGFloat { cardWidth * 1.4 }
    private var radius:     CGFloat { cardWidth * 0.10 }

    private let suitOrder: [CardSuit] = [.spades, .hearts, .diamonds, .clubs]

    var body: some View {
        HStack(spacing: 6) {
            // Foundations — left
            ForEach(suitOrder, id: \.sfSymbol) { suit in
                foundationSlot(suit: suit)
            }

            Spacer(minLength: 0)

            // Waste — right side, adjacent to stock
            wasteSlot
                .onTapGesture(count: 2) { onWasteDoubleTap() }
                .onTapGesture { onWasteTap() }

            // Stock — rightmost
            stockSlot
                .onTapGesture { onStockTap() }
        }
    }

    // MARK: - Foundation slot

    private func foundationSlot(suit: CardSuit) -> some View {
        let topRank   = foundations[suit.foundationIndex]
        let isSelected = selectedFoundationSuit == suit
        let isGhosted  = draggingFoundationSuit == suit
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(
                    isSelected ? theme.colors.accentPrimary : theme.colors.border,
                    lineWidth: isSelected ? 2 : 1
                )
                .frame(width: cardWidth, height: cardHeight)

            if let rank = topRank {
                PlayingCardView(rank: rank, suit: suit, theme: theme,
                                isClassic: isClassic, width: cardWidth)
                    .opacity(isGhosted ? 0.15 : 1)
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { onFoundationDragChanged?(suit, $0.translation) }
                            .onEnded   { onFoundationDragEnded?(suit, $0.translation) }
                    )
            } else {
                Image(systemName: suit.sfSymbol)
                    .font(.system(size: cardWidth * 0.30, weight: .light))
                    .foregroundStyle(theme.colors.border)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .contentShape(Rectangle())
        .onTapGesture { onFoundationTap(suit) }
    }

    // MARK: - Waste slot
    // Top card rightmost, fully visible. Up to 2 previous cards peek out to the left.

    private var peekWidth: CGFloat { cardWidth * 0.38 }

    private var wasteSlot: some View {
        let count   = waste.count
        let visible = min(3, count)
        // Total width grows with each additional peeking card
        let totalW  = cardWidth + CGFloat(max(0, visible - 1)) * peekWidth

        return ZStack(alignment: .trailing) {
            // Empty outline anchored to trailing edge
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
                .frame(width: cardWidth, height: cardHeight)

            if count >= 3 {
                PlayingCardView(waste[count - 3], theme: theme, isClassic: isClassic, width: cardWidth)
                    .offset(x: -(peekWidth * 2))
            }
            if count >= 2 {
                PlayingCardView(waste[count - 2], theme: theme, isClassic: isClassic, width: cardWidth)
                    .offset(x: -peekWidth)
            }
            if let top = waste.last {
                PlayingCardView(top, theme: theme, isClassic: isClassic, width: cardWidth)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(theme.colors.accentPrimary, lineWidth: 2)
                            .opacity(selectedIsWaste ? 1 : 0)
                    )
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in onWasteDragChanged?(value.translation) }
                            .onEnded   { value in onWasteDragEnded?(value.translation) }
                    )
            }
        }
        .frame(width: totalW, height: cardHeight)
    }

    // MARK: - Stock slot

    private var stockSlot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
                .frame(width: cardWidth, height: cardHeight)

            if stock.isEmpty {
                // Recycle icon — tap to flip waste back
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: cardWidth * 0.30, weight: .light))
                    .foregroundStyle(theme.colors.border)
            } else {
                CardBackView(theme: theme, isClassic: isClassic, width: cardWidth)
                if stock.count >= 2 {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(theme.colors.surface)
                        .frame(width: cardWidth, height: cardHeight)
                        .offset(x: 2, y: -2)
                        .zIndex(-1)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
    }
}
