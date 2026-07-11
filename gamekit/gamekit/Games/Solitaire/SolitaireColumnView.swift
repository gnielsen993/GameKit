import SwiftUI
import DesignKit

struct SolitaireColumnView: View {
    let cards:       [PlayingCard]
    let theme:       Theme
    let isClassic:   Bool
    let cardWidth:   CGFloat
    var selectedFrom: Int?    // index where selection begins (cards from here down are highlighted)
    var ghostFromIdx: Int?    // drag: cards from here onward are semi-transparent placeholders
    var isDragTarget: Bool = false
    var onTap:       ((Int) -> Void)? = nil
    var onDoubleTap: ((Int) -> Void)? = nil

    private var cardHeight:    CGFloat { cardWidth * 1.4 }
    private var faceDownOff:   CGFloat { cardWidth * 0.20 }
    private var faceUpOff:     CGFloat { cardWidth * 0.46 }
    private var slotRadius:    CGFloat { cardWidth * 0.10 }

    private func yOffset(for idx: Int) -> CGFloat {
        guard idx > 0 else { return 0 }
        return (0..<idx).reduce(0) { acc, i in
            acc + (cards[i].isFaceUp ? faceUpOff : faceDownOff)
        }
    }

    private var totalHeight: CGFloat {
        guard !cards.isEmpty else { return cardHeight }
        return yOffset(for: cards.count - 1) + cardHeight
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Empty slot outline
            RoundedRectangle(cornerRadius: slotRadius, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
                .frame(width: cardWidth, height: cardHeight)

            ForEach(0..<cards.count, id: \.self) { idx in
                cardView(at: idx)
                    .offset(y: yOffset(for: idx))
                    .zIndex(Double(idx))
            }
        }
        .frame(width: cardWidth, height: max(cardHeight, totalHeight), alignment: .top)
        // Highlight column as valid drop target
        .overlay(
            RoundedRectangle(cornerRadius: slotRadius, style: .continuous)
                .stroke(theme.colors.accentPrimary.opacity(isDragTarget ? 0.7 : 0), lineWidth: 2)
                .frame(width: cardWidth, height: cardHeight)
                .feedbackAnimation(.easeInOut(duration: 0.15), value: isDragTarget),
            alignment: .top
        )
    }

    @ViewBuilder
    private func cardView(at idx: Int) -> some View {
        let card       = cards[idx]
        let isSelected = selectedFrom.map { idx >= $0 } ?? false
        let isGhost    = ghostFromIdx.map { idx >= $0 } ?? false

        Group {
            if card.isFaceUp {
                PlayingCardView(card, theme: theme, isClassic: isClassic, width: cardWidth)
                    .overlay(
                        RoundedRectangle(cornerRadius: cardWidth * 0.10, style: .continuous)
                            .stroke(theme.colors.accentPrimary, lineWidth: 2)
                            .opacity(isSelected && !isGhost ? 1 : 0)
                    )
            } else {
                CardBackView(theme: theme, isClassic: isClassic, width: cardWidth)
            }
        }
        .opacity(isGhost ? 0.15 : 1.0)
        .feedbackAnimation(.easeInOut(duration: 0.15), value: isSelected)
        .onTapGesture(count: 2) {
            if card.isFaceUp && !isGhost { onDoubleTap?(idx) }
        }
        .onTapGesture {
            if !isGhost { onTap?(idx) }
        }
    }
}
