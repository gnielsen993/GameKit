//
//  MergeBoardView.swift
//  gamekit
//
//  4x4 grid renderer + swipe gesture host. Props-only — receives the board
//  state and a single `onSwipe` closure. The VM owns all state.
//
//  Sizing: takes the smaller of the available width/height bound, divides
//  into 4 equal cells with `theme.spacing.s` gutters. Mirrors
//  MinesweeperBoardView's GeometryReader-driven sizing so the board scales
//  cleanly on the iPhone SE (320pt-wide) and iPhone 17 Pro Max alike.
//

import SwiftUI
import DesignKit

struct MergeBoardView: View {
    let theme: Theme
    let board: MergeBoard
    let onSwipe: (SwipeDirection) -> Void

    /// Minimum drag distance to register as a swipe. Below this, the gesture
    /// is treated as an accidental finger jiggle.
    private let swipeThreshold: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let gutter = theme.spacing.s
            let cellSide = (side - gutter * CGFloat(MergeBoard.size + 1)) / CGFloat(MergeBoard.size)

            ZStack {
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .fill(theme.colors.border.opacity(0.4))
                    .frame(width: side, height: side)

                VStack(spacing: gutter) {
                    ForEach(0..<MergeBoard.size, id: \.self) { row in
                        HStack(spacing: gutter) {
                            ForEach(0..<MergeBoard.size, id: \.self) { col in
                                MergeTileView(
                                    theme: theme,
                                    tile: board.cell(row: row, col: col),
                                    sideLength: cellSide
                                )
                            }
                        }
                    }
                }
                .padding(gutter)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(swipeGesture)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Merge board"))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: swipeThreshold, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > swipeThreshold || abs(dy) > swipeThreshold else { return }
                if abs(dx) > abs(dy) {
                    onSwipe(dx > 0 ? .right : .left)
                } else {
                    onSwipe(dy > 0 ? .down : .up)
                }
            }
    }
}
