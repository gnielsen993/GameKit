//
//  MergeTilePalette.swift
//  gamekit
//
//  Local-to-Merge tile palette derived from DesignKit semantic tokens.
//  Per CLAUDE.md §2: promote to DesignKit only when ≥2 games need the same
//  ramp. v1 keeps this game-local.
//
//  Strategy:
//    - Values 2..256 use the per-preset `gameNumberPalette` (8 colors, the
//      same ramp Minesweeper uses for adjacency numbers 1..8). The palette
//      is preset-tuned and CVD-audited (DesignKit THEME-02).
//    - Values 512..2048 layer accent colors over surface for visual punch.
//    - Values >2048 (continuation past the win banner) use accentPrimary —
//      a single distinguished tier so the player sees they're past 2048.
//
//  Light vs dark text is selected from the tile color's perceived
//  luminance: bright tiles get textPrimary; dark tiles get the background
//  color so digits stay legible across all 6 audit presets (CLAUDE.md §8.12).
//

import SwiftUI
import DesignKit

enum MergeTilePalette {

    /// Tile background color for the given value. `theme` is the resolved
    /// active theme — call sites read `themeManager.theme(using: colorScheme)`
    /// once at the parent and pass it down (CLAUDE.md §8.2 +
    /// MinesweeperGameView.swift:58 pattern).
    static func tileColor(forValue value: Int, theme: Theme) -> Color {
        let palette = theme.colors.gameNumberPalette
        // Defensive: if the resolver hasn't filled the palette (would be a
        // DesignKit bug, but cheap to guard) fall back to surface.
        guard !palette.isEmpty else { return theme.colors.surface }

        switch value {
        case 2:    return palette[0]
        case 4:    return palette[1]
        case 8:    return palette[2]
        case 16:   return palette[3]
        case 32:   return palette[4]
        case 64:   return palette[5]
        case 128:  return palette[6]
        case 256:  return palette[7]
        case 512:  return theme.colors.accentSecondary
        case 1024: return theme.colors.highlight
        case 2048: return theme.colors.success
        default:   return theme.colors.accentPrimary  // continuation past 2048
        }
    }

    /// Foreground text color for the given tile value. Picks textPrimary on
    /// dark tiles and background on light tiles so the digit reads on every
    /// audit preset.
    static func textColor(forValue value: Int, theme: Theme) -> Color {
        // Higher tiers use saturated accents — flip to the background color
        // (typically near-white in light mode, near-black in dark mode) for
        // legibility.
        if value >= 512 { return theme.colors.background }
        return theme.colors.textPrimary
    }

    /// Font scaling: 1024+ digits need to fit within the tile, so step the
    /// size down. The DesignKit `monoNumber` typography is the base; we
    /// scale via `.font(...)` modifier in the view.
    static func fontScale(forValue value: Int) -> CGFloat {
        switch value {
        case ..<128:   return 1.0
        case ..<1024:  return 0.85
        default:       return 0.70
        }
    }
}
