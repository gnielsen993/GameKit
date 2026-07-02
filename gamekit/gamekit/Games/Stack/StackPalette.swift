//
//  StackPalette.swift
//  gamekit
//
//  Token-only accent-derived block color ramp for the Stack tower.
//  Every color comes from DesignKit semantic tokens — no raw color
//  initializers or SwiftUI system color names anywhere in this file
//  (CLAUDE.md §1, D-07).
//
//  Background: DesignKit ColorDerivation.derivedCharts builds chart1…6
//  by rotating hue around the active accent and varying brightness/saturation,
//  so the tower literally becomes the current preset's accent palette (D-05).
//
//  Smooth ramp: instead of hard-cycling the 6 chart tokens per layer, each
//  layer exposes a (base, next, blend) triple. The renderer composites
//  `next` over `base` at `blend` opacity — an alpha-blend lerp that keeps
//  every drawn color a pure token derivation while the tower shifts hue
//  gradually, one layer at a time (period = 6 stops × blocksPerStop).
//

import SwiftUI
import DesignKit

/// Accent-derived per-layer color ramp for the Stack tower.
///
/// - D-05: tower becomes the active preset's accent palette.
/// - D-06: color is fixed by index — a placed block never changes color
///   as the tower grows. The ramp cycles smoothly through chart1…6.
/// - D-07: brightness variation in `derivedCharts` provides lightness
///   steps even on monochrome presets; no special-casing required.
enum StackPalette {

    /// Layers per chart stop — the ramp crossfades to the next chart token
    /// over this many blocks, so adjacent layers differ subtly instead of
    /// jumping between tokens.
    static let blocksPerStop = 4

    /// One tower layer's color as a token pair + blend factor.
    /// Renderers draw `base`, then `next` at `blend` opacity on top —
    /// an exact alpha-blend lerp using only token colors.
    struct Layer {
        let base: Color
        let next: Color
        let blend: Double   // 0…1
    }

    /// Returns the blended layer colors for a block at the given index.
    static func layer(forIndex i: Int, theme: Theme) -> Layer {
        let ramp: [Color] = [
            theme.charts.chart1,
            theme.charts.chart2,
            theme.charts.chart3,
            theme.charts.chart4,
            theme.charts.chart5,
            theme.charts.chart6,
        ]
        let pos = Double(max(i, 0)) / Double(blocksPerStop)
        let seg = Int(pos) % ramp.count
        let frac = pos - pos.rounded(.down)
        return Layer(base: ramp[seg],
                     next: ramp[(seg + 1) % ramp.count],
                     blend: frac)
    }
}
