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
import UIKit
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
    /// light tiles and background on dark tiles so the digit reads on every
    /// audit preset (CLAUDE.md §8.12).
    ///
    /// P7 polish: replaced the original "≥512 = light text" cutoff with
    /// per-tile relative-luminance lookup. Classic gameNumberPalette[3] (the
    /// `16` tile) is `#212121` near-black, so the old logic painted dark text
    /// on a near-black tile and the digit disappeared. The new logic compares
    /// the perceived luminance of the tile color to the perceived luminance
    /// of the theme's `textPrimary` and `background` and picks whichever has
    /// the larger contrast distance — works for every preset without per-
    /// preset special-casing.
    static func textColor(forValue value: Int, theme: Theme) -> Color {
        let bg = tileColor(forValue: value, theme: theme)
        return Self.bestContrastingForeground(
            for: bg,
            candidates: [theme.colors.textPrimary, theme.colors.background]
        )
    }

    /// Returns whichever candidate has the larger absolute relative-luminance
    /// distance from the given background color. Mirrors the WCAG contrast
    /// approach without the full ratio math — a luminance gap >= ~0.5 reads
    /// cleanly at body / titleNumber type sizes (Wong audit basis).
    private static func bestContrastingForeground(
        for background: Color,
        candidates: [Color]
    ) -> Color {
        let bgLum = relativeLuminance(of: background)
        var best = candidates[0]
        var bestGap = abs(bgLum - relativeLuminance(of: best))
        for candidate in candidates.dropFirst() {
            let gap = abs(bgLum - relativeLuminance(of: candidate))
            if gap > bestGap {
                bestGap = gap
                best = candidate
            }
        }
        return best
    }

    /// Perceived luminance per ITU-R BT.601 (cheap, good enough for tile
    /// digits). Returns 0..1.
    private static func relativeLuminance(of color: Color) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b
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
