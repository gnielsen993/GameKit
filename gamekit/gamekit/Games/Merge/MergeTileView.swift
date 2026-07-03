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
    /// When true (the animated tile layer), a value change — i.e. this tile
    /// just absorbed another — jolts to 1.15× and springs back. The static
    /// empty-cell layer leaves this false. Gate resolved by the parent
    /// (DESIGN.md §10.2).
    var animated: Bool = false

    @State private var popCount = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(backgroundFill)

            // Raised-tile lighting on real tiles only — empty wells stay flat.
            if tile != nil {
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .fill(SurfaceDepth.raisedSheen)
            }

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
                    .contentTransition(.identity)
            }
        }
        .frame(width: sideLength, height: sideLength)
        .shadow(
            color: tile == nil ? SurfaceDepth.shadow.opacity(0) : SurfaceDepth.shadow,
            radius: 4, x: 0, y: 2
        )
        .keyframeAnimator(initialValue: 1.0, trigger: popCount) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.15, duration: 0.08)
                SpringKeyframe(1.0, duration: 0.28, spring: Spring(response: 0.22, dampingRatio: 0.6))
            }
        }
        .onChange(of: tile?.value) { oldValue, newValue in
            guard animated, oldValue != nil, newValue != nil else { return }
            popCount += 1
        }
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
