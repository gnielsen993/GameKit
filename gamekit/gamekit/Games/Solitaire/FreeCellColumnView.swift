import SwiftUI
import DesignKit

struct FreeCellColumnView: View {
    let colIdx:    Int
    let cards:     [PlayingCard]
    let vm:        FreeCellViewModel
    let theme:     Theme
    let isClassic: Bool
    let cardWidth: CGFloat
    var dragSource: FreeCellSelection? = nil

    private var cardHeight: CGFloat { cardWidth * 1.4 }
    private var radius:     CGFloat { cardWidth * 0.10 }

    // Dynamic fan — compress when cards stack deeply
    private var fanOffset: CGFloat {
        let base: CGFloat = cardWidth * 0.40
        let floor: CGFloat = cardWidth * 0.18
        guard cards.count > 8 else { return base }
        let shrink = CGFloat(cards.count - 8) * 2.5
        return max(floor, base - shrink)
    }

    private var columnHeight: CGFloat {
        guard !cards.isEmpty else { return cardHeight }
        return cardHeight + CGFloat(cards.count - 1) * fanOffset
    }

    private var isValidTarget: Bool { vm.validColumnTargets.contains(colIdx) }

    private var selectedStartIdx: Int? {
        if case .column(let col, let idx) = vm.selection, col == colIdx { return idx }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Slot outline (always present as drop zone indicator)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(
                    isValidTarget ? theme.colors.success : .white.opacity(0.18),
                    lineWidth: isValidTarget ? 2 : 1
                )
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(isValidTarget ? theme.colors.success.opacity(0.10) : Color.clear)
                )
                .frame(width: cardWidth, height: cardHeight)
                .onTapGesture {
                    if cards.isEmpty { vm.tapEmptyColumn(colIdx: colIdx) }
                }

            // Cards fanned downward
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                cardTile(card: card, idx: idx)
                    .offset(y: CGFloat(idx) * fanOffset)
                    .zIndex(Double(idx))
            }
        }
        .frame(width: cardWidth, height: max(cardHeight, columnHeight), alignment: .top)
    }

    private func isGhosted(_ idx: Int) -> Bool {
        guard let src = dragSource else { return false }
        if case .column(let col, let start) = src, col == colIdx { return idx >= start }
        return false
    }

    @ViewBuilder
    private func cardTile(card: PlayingCard, idx: Int) -> some View {
        let selIdx      = selectedStartIdx
        let isSelected  = selIdx.map { idx >= $0 } ?? false
        let isTopOfSel  = selIdx == idx
        let ghosted     = isGhosted(idx)

        PlayingCardView(card, theme: theme, isClassic: isClassic, width: cardWidth)
            .overlay(alignment: .topLeading) {
                if isTopOfSel && !ghosted {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(theme.colors.accentPrimary, lineWidth: 2)
                }
            }
            .opacity(ghosted ? 0.22 : (isSelected ? 0.85 : 1.0))
            .contentShape(Rectangle())
            .onTapGesture      { vm.tapColumnCard(colIdx: colIdx, cardIdx: idx) }
            .onLongPressGesture(minimumDuration: 0.4) {
                if idx == cards.count - 1 { vm.doubleTapColumnCard(colIdx: colIdx) }
                else { vm.tapColumnCard(colIdx: colIdx, cardIdx: idx) }
            }
    }
}
