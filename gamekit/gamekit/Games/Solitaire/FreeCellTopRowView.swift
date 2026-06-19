import SwiftUI
import DesignKit

// MARK: - Top row (shelf): free cells + foundations

struct FreeCellTopRowView: View {
    let vm:        FreeCellViewModel
    let theme:     Theme
    let isClassic: Bool
    let cardWidth: CGFloat
    let colGap:    CGFloat
    var dragSource: FreeCellSelection? = nil

    private var cardHeight: CGFloat { cardWidth * 1.4 }

    private var suits: [CardSuit] { CardSuit.allCases }

    var body: some View {
        HStack(spacing: 0) {
            // Free cells
            HStack(spacing: colGap) {
                ForEach(0..<4, id: \.self) { idx in
                    freeCellSlot(idx)
                }
            }

            Spacer(minLength: colGap * 3)

            // Foundations
            HStack(spacing: colGap) {
                ForEach(Array(suits.enumerated()), id: \.offset) { i, suit in
                    foundationSlot(suit: suit, suitIdx: i)
                }
            }
        }
    }

    // MARK: - Free cell slot

    @ViewBuilder
    private func freeCellSlot(_ idx: Int) -> some View {
        let card       = vm.board.freeCells[idx]
        let isSelected = { if case .freeCell(let ci) = vm.selection { return ci == idx } else { return false } }()
        let isTarget   = vm.validFreeCellTargets.contains(idx)
        let isGhosted: Bool = { if case .freeCell(let ci) = dragSource { return ci == idx } else { return false } }()

        ZStack {
            RoundedRectangle(cornerRadius: cardWidth * 0.10, style: .continuous)
                .stroke(
                    isTarget   ? theme.colors.success :
                    isSelected ? theme.colors.accentPrimary :
                                 theme.colors.border,
                    lineWidth: (isTarget || isSelected) ? 2 : 1.5
                )
                .background(
                    RoundedRectangle(cornerRadius: cardWidth * 0.10, style: .continuous)
                        .fill(
                            isTarget   ? theme.colors.success.opacity(0.12) :
                            isSelected ? theme.colors.accentPrimary.opacity(0.10) :
                                         theme.colors.surface.opacity(0.25)
                        )
                )
                .frame(width: cardWidth, height: cardHeight)

            if let card {
                PlayingCardView(card, theme: theme, isClassic: isClassic, width: cardWidth)
                    .overlay(
                        isSelected && !isGhosted
                            ? RoundedRectangle(cornerRadius: cardWidth * 0.10, style: .continuous)
                                .stroke(theme.colors.accentPrimary, lineWidth: 2)
                            : nil
                    )
                    .opacity(isGhosted ? 0.22 : 1.0)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .contentShape(Rectangle())
        .onTapGesture { vm.tapFreeCell(cellIdx: idx) }
        .onLongPressGesture(minimumDuration: 0.4) { vm.doubleTapFreeCell(cellIdx: idx) }
    }

    // MARK: - Foundation slot

    @ViewBuilder
    private func foundationSlot(suit: CardSuit, suitIdx: Int) -> some View {
        let fidx        = vm.board.foundationIndex(for: suit)
        let topRank     = vm.board.foundations[fidx]
        let isTarget    = vm.selection != nil && vm.canMoveSelectionToFoundation
                          && vm.selectedCards.first?.suit == suit
        let isSelected: Bool = { if case .foundation(let s) = vm.selection { return s == suit } else { return false } }()
        let isGhosted:  Bool = { if case .foundation(let s) = dragSource { return s == suit } else { return false } }()

        ZStack {
            RoundedRectangle(cornerRadius: cardWidth * 0.10, style: .continuous)
                .stroke(
                    isSelected ? theme.colors.accentPrimary :
                    isTarget   ? theme.colors.success : theme.colors.border,
                    lineWidth: (isSelected || isTarget) ? 2 : 1.5
                )
                .background(
                    RoundedRectangle(cornerRadius: cardWidth * 0.10, style: .continuous)
                        .fill(
                            isSelected ? theme.colors.accentPrimary.opacity(0.10) :
                            isTarget   ? theme.colors.success.opacity(0.12) :
                                         theme.colors.surface.opacity(0.25)
                        )
                )
                .frame(width: cardWidth, height: cardHeight)

            if let rank = topRank {
                let card = PlayingCard(rank: rank, suit: suit)
                PlayingCardView(card, theme: theme, isClassic: isClassic, width: cardWidth)
                    .opacity(isGhosted ? 0.22 : 1.0)
            } else {
                Image(systemName: suit.sfSymbol)
                    .font(.system(size: cardWidth * 0.32))
                    .foregroundStyle(
                        (suit.isRed ? theme.colors.danger : theme.colors.textPrimary).opacity(0.25)
                    )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .contentShape(Rectangle())
        .onTapGesture { vm.tapFoundation(suit: suit) }
    }
}
