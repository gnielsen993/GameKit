//
//  MergeTileView.swift
//  gamekit
//
//  Single tile renderer. Props-only (CLAUDE.md §8.2). Theme tokens flow in
//  from the parent; the only hand-tuned constant is `fontScale` (returned
//  by `MergeTilePalette`).
//

import SwiftUI
import DesignKit

struct MergeTileView: View {
    let theme: Theme
    let tile: MergeTile?
    let sideLength: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(backgroundFill)

            if let tile {
                Text("\(tile.value)")
                    .font(theme.typography.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(MergeTilePalette.textColor(forValue: tile.value, theme: theme))
                    .padding(theme.spacing.xs)
                    .scaleEffect(MergeTilePalette.fontScale(forValue: tile.value))
            }
        }
        .frame(width: sideLength, height: sideLength)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundFill: Color {
        guard let tile else {
            // Empty cell — subtle inset on the surface, mirrors a 2048 board.
            return theme.colors.surface
        }
        return MergeTilePalette.tileColor(forValue: tile.value, theme: theme)
    }

    private var accessibilityLabel: Text {
        if let tile {
            return Text("Tile \(tile.value)")
        }
        return Text("Empty")
    }
}
