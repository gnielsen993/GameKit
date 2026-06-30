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
//  Brightness variation also gives visibly distinct steps on low-saturation
//  presets (D-07 low-hue fallback — no special-casing needed).
//
//  Cycle length 6 (tuning constant — matches theme.charts count, D-06).
//

import SwiftUI
import DesignKit

/// Accent-derived per-layer color ramp for the Stack tower.
///
/// Cycles `theme.charts.chart1…chart6` by block index:
/// - D-05: tower becomes the active preset's accent palette.
/// - D-06: color is fixed by index and cycles every 6 layers. A placed
///   block never changes color as the tower grows.
/// - D-07: brightness variation in `derivedCharts` provides lightness
///   steps even on monochrome presets; no special-casing required.
///
/// All colors come from DesignKit semantic tokens only.
enum StackPalette {

    /// Returns the token color for a block at the given index.
    ///
    /// - Parameters:
    ///   - i: Block index (0-based from the base block). Cycles every 6.
    ///   - theme: Active DesignKit theme; tokens update on preset changes.
    /// - Returns: A `Color` from `theme.charts.chart1…chart6`.
    static func color(forIndex i: Int, theme: Theme) -> Color {
        // Cycle length 6 — tuning constant matching the chart token count.
        // Only DesignKit semantic tokens appear here (D-07 purity rule).
        let ramp: [Color] = [
            theme.charts.chart1,
            theme.charts.chart2,
            theme.charts.chart3,
            theme.charts.chart4,
            theme.charts.chart5,
            theme.charts.chart6,
        ]
        return ramp[i % ramp.count]   // D-06: color fixed by index, cycles (length 6)
    }
}
