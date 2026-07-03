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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.settingsStore) private var settingsStore

    /// Minimum drag distance to register as a swipe. Below this, the gesture
    /// is treated as an accidental finger jiggle.
    private let swipeThreshold: CGFloat = 24

    /// DESIGN.md §10.2 gate — slides/pops hard-cut to instant when off.
    private var animated: Bool { settingsStore.animationsEnabled && !reduceMotion }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let gutter = theme.spacing.s
            let cellSide = (side - gutter * CGFloat(MergeBoard.size + 1)) / CGFloat(MergeBoard.size)
            let step = cellSide + gutter

            ZStack {
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .fill(theme.colors.border.opacity(0.4))
                    .frame(width: side, height: side)

                // Static layer: the empty-cell wells.
                VStack(spacing: gutter) {
                    ForEach(0..<MergeBoard.size, id: \.self) { row in
                        HStack(spacing: gutter) {
                            ForEach(0..<MergeBoard.size, id: \.self) { _ in
                                MergeTileView(theme: theme, tile: nil, sideLength: cellSide)
                            }
                        }
                    }
                }
                .padding(gutter)

                // Animated layer: tiles keyed by MergeTile.id (stable across
                // slides — see MergeTile.swift invariants), so position changes
                // glide, merged tiles pop in place, and spawned tiles scale in
                // just after the slide settles.
                ZStack {
                    ForEach(placedTiles(in: board)) { placed in
                        MergeTileView(
                            theme: theme,
                            tile: placed.tile,
                            sideLength: cellSide,
                            animated: animated
                        )
                        .position(
                            x: gutter + CGFloat(placed.col) * step + cellSide / 2,
                            y: gutter + CGFloat(placed.row) * step + cellSide / 2
                        )
                        .zIndex(placed.tile.mergedThisTurn ? 2 : 1)
                        .transition(tileTransition)
                    }
                }
                .frame(width: side, height: side)
                .animation(animated ? .spring(response: 0.24, dampingFraction: 0.9) : nil, value: board)
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

    // MARK: - Tile layer

    private struct PlacedTile: Identifiable {
        let tile: MergeTile
        let row: Int
        let col: Int
        var id: UUID { tile.id }
    }

    private func placedTiles(in board: MergeBoard) -> [PlacedTile] {
        var result: [PlacedTile] = []
        result.reserveCapacity(board.tileCount)
        for row in 0..<MergeBoard.size {
            for col in 0..<MergeBoard.size {
                if let tile = board.cell(row: row, col: col) {
                    result.append(PlacedTile(tile: tile, row: row, col: col))
                }
            }
        }
        return result
    }

    /// Spawned tiles scale in slightly after the slide settles; absorbed
    /// tiles fade under the arriving survivor (which draws above via zIndex).
    private var tileTransition: AnyTransition {
        guard animated else { return .identity }
        return .asymmetric(
            insertion: .scale(scale: 0.4)
                .combined(with: .opacity)
                .animation(.spring(response: 0.24, dampingFraction: 0.7).delay(0.09)),
            removal: .opacity.animation(.easeOut(duration: 0.08).delay(0.06))
        )
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
