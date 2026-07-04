//
//  ArcadePalette.swift
//  gamekit
//
//  Accent-derived per-index color ramp for arcade games; consumed by
//  Stack (tower layer) and Snake (body segment). Promoted from
//  Games/Stack/StackPalette in Phase 17 (2-game promotion threshold —
//  CLAUDE.md §4, D-02).
//
//  Every color comes from DesignKit semantic tokens — no raw color
//  initializers or SwiftUI system color names anywhere in this file
//  (CLAUDE.md §1, D-07).
//
//  Background: DesignKit ColorDerivation.derivedCharts builds chart1…6
//  by rotating hue around the active accent and varying brightness/saturation,
//  so the ramp literally becomes the current preset's accent palette (D-05).
//
//  Smooth ramp: instead of hard-cycling the 6 chart tokens per segment,
//  each index exposes a (base, next, blend) triple. The renderer composites
//  `next` over `base` at `blend` opacity — an alpha-blend lerp that keeps
//  every drawn color a pure token derivation while the display shifts hue
//  gradually, one segment at a time (period = 6 stops × segmentsPerStop).
//
//  Index contract:
//  - `forIndex: 0` yields the head/most-saturated end of the ramp (chart1).
//    For Snake: index 0 = head segment (darkest/most saturated per D-02).
//    For Stack: index 0 = bottom of the tower.
//  - Higher indices fade toward chart6 (least saturated direction).
//  - Plan 04 (SnakeBoardCanvas) uses `layer(forIndex: i)` where i = 0 is
//    the head segment. Per assumption A4, the §8.12 audit may reverse the
//    mapping if a preset's chart1 is not the most saturated in practice.
//

import SwiftUI
import DesignKit

/// Accent-derived per-index color ramp for arcade games.
///
/// Consumed by:
/// - Stack: `StackPalette` (forwarding shim) — tower layer index
/// - Snake (Plan 04): body segment index, where 0 = head
///
/// - D-05: ramp becomes the active preset's accent palette.
/// - D-06: color is fixed by index — a placed block / body segment never
///   changes color as the structure grows. The ramp cycles smoothly
///   through chart1…6.
/// - D-07: brightness variation in `derivedCharts` provides lightness
///   steps even on monochrome presets; no special-casing required.
enum ArcadePalette {

    /// Segments per chart stop — the ramp crossfades to the next chart token
    /// over this many indices, so adjacent segments differ subtly instead of
    /// jumping between tokens. (Renamed from `blocksPerStop` at promotion.)
    static let segmentsPerStop = 4

    /// Backward-compat alias so existing `StackPalette.blocksPerStop` call
    /// sites compile unchanged through the typealias shim.
    static var blocksPerStop: Int { segmentsPerStop }

    /// One segment's color as a token pair + blend factor.
    /// Renderers draw `base`, then `next` at `blend` opacity on top —
    /// an exact alpha-blend lerp using only token colors.
    struct Layer {
        let base: Color
        let next: Color
        let blend: Double   // 0…1
    }

    /// Returns the blended layer colors for a segment at the given index.
    ///
    /// Index 0 maps to `chart1` (head / most-saturated end of the ramp).
    /// Higher indices cycle through chart2…6 with smooth interpolation.
    static func layer(forIndex i: Int, theme: Theme) -> Layer {
        let ramp: [Color] = [
            theme.charts.chart1,
            theme.charts.chart2,
            theme.charts.chart3,
            theme.charts.chart4,
            theme.charts.chart5,
            theme.charts.chart6,
        ]
        let pos = Double(max(i, 0)) / Double(segmentsPerStop)
        let seg = Int(pos) % ramp.count
        let frac = pos - pos.rounded(.down)
        return Layer(base: ramp[seg],
                     next: ramp[(seg + 1) % ramp.count],
                     blend: frac)
    }
}
