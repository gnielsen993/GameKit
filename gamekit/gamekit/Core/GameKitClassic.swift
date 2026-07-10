import SwiftUI
import DesignKit

// GameKitClassic — GameDrawer's "Classic" identity for the DesignKit Classic
// slot. Chrome Diner restomod: cream paper bg, white card surfaces, brushed
// charcoal text, diner-red accent in light; deep walnut + coral in dark.
//
// Registered via `DesignKit.configure(classicPreset:)` at the top of
// `GameKitApp.init()` — must run BEFORE ThemeManager constructs so any
// stored `.classicMuted` preference resolves through these anchors.
//
// Per CLAUDE.md §1 Classic restomod policy: this preset only swaps colors.
// Layout, spacing, radii, typography weights, and motion stay modern.

enum GameKitClassic {
    static let chromeDiner: PresetTheme = PresetTheme(
        id: "classicMuted",
        displayName: "Classic",
        category: .classic,
        light: chromeDinerLight,
        dark: chromeDinerDark
    )

    private static let chromeDinerLight: PresetAnchors = PresetAnchors(
        background: Color(hex: "#F5F1E8"),
        surface: Color(hex: "#FFFFFF"),
        accent: Color(hex: "#C0392B"),
        textPrimary: Color(hex: "#2A2620"),
        gameNumberPalette: PresetTheme.classicGameNumberPalette
    )

    private static let chromeDinerDark: PresetAnchors = PresetAnchors(
        background: Color(hex: "#1D1813"),
        surface: Color(hex: "#262019"),
        accent: Color(hex: "#E85A4D"),
        textPrimary: Color(hex: "#F5F1E8"),
        gameNumberPalette: PresetTheme.classicGameNumberPaletteDark
    )
}
