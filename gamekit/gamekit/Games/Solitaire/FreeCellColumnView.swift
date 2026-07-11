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
    var dragTarget: FreeCellDest?      = nil

    private var cardHeight: CGFloat { cardWidth * 1.4 }
    private var radius:     CGFloat { cardWidth * 0.10 }

    private var fanOffset: CGFloat {
        FreeCellColumnView.fanOffset(for: cards.count, cardWidth: cardWidth)
    }

    // Shared by FreeCellGameView.computeSource so visual layout and hit-detection
    // stay in sync — both call this, neither hard-codes its own formula.
    static func fanOffset(for count: Int, cardWidth: CGFloat) -> CGFloat {
        let base: CGFloat  = cardWidth * 0.46
        let floor: CGFloat = cardWidth * 0.33   // raised from 0.20 — keeps rank/suit readable
        guard count > 8 else { return base }
        return max(floor, base - CGFloat(count - 8) * 1.5)   // gentler than old 2.5
    }

    private var columnHeight: CGFloat {
        guard !cards.isEmpty else { return cardHeight }
        return cardHeight + CGFloat(cards.count - 1) * fanOffset
    }

    private var isTapTarget: Bool { vm.validColumnTargets.contains(colIdx) }

    private var isDragTarget: Bool {
        if case .column(let col) = dragTarget { return col == colIdx }
        return false
    }

    private var isHighlighted: Bool { isTapTarget || isDragTarget }

    private var selectedStartIdx: Int? {
        if case .column(let col, let idx) = vm.selection, col == colIdx { return idx }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Slot — visible border when empty; green tint when highlighted+empty
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(
                    isHighlighted && cards.isEmpty ? theme.colors.success : theme.colors.border,
                    lineWidth: isHighlighted && cards.isEmpty ? 2 : 1.5
                )
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(isHighlighted && cards.isEmpty
                              ? theme.colors.success.opacity(0.10)
                              : theme.colors.surface.opacity(0.15))
                )
                .frame(width: cardWidth, height: cardHeight)
                .onTapGesture {
                    if cards.isEmpty { vm.tapEmptyColumn(colIdx: colIdx) }
                }

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
        let isTopCard   = idx == cards.count - 1

        PlayingCardView(card, theme: theme, isClassic: isClassic, width: cardWidth)
            .overlay(alignment: .topLeading) {
                if isTopOfSel && !ghosted {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(theme.colors.accentPrimary, lineWidth: 2)
                }
                // Highlight the card the dragged/selected stack lands on
                if isTopCard && isHighlighted && !ghosted {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(theme.colors.success, lineWidth: 2)
                }
            }
            .opacity(ghosted ? 0.22 : (isSelected ? 0.85 : 1.0))
            .feedbackAnimation(.easeInOut(duration: 0.15), value: isSelected)
            .feedbackAnimation(.easeInOut(duration: 0.15), value: isHighlighted)
            .contentShape(Rectangle())
            .onTapGesture      { vm.tapColumnCard(colIdx: colIdx, cardIdx: idx) }
            .onLongPressGesture(minimumDuration: 0.4) {
                if idx == cards.count - 1 { vm.doubleTapColumnCard(colIdx: colIdx) }
                else { vm.tapColumnCard(colIdx: colIdx, cardIdx: idx) }
            }
    }
}
