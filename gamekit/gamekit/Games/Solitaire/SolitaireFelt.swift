import SwiftUI
import DesignKit

// MARK: - SolitaireFelt
//
// Single source of truth for the Solitaire-family board ("felt") surface.
//
// The Classic preset shows green baize; every other preset uses a muted
// theme fill. This was previously copy-pasted as an identical `boardColor`
// computed property in SolitaireGameView, FreeCellGameView, and
// InteractiveTableauView — keeping the magic baize color in one place so
// the swap to the `classicAnchorOverride` hook (CLAUDE.md §1 Classic
// restomod policy) only has to happen here.

enum SolitaireFelt {
    /// Classic-preset green baize. Placeholder until the
    /// `classicAnchorOverride` hook lands.
    static let classicBaize = Color(hue: 0.426, saturation: 0.576, brightness: 0.416)

    /// Board background for the given theme + preset.
    static func boardColor(theme: Theme, isClassic: Bool) -> Color {
        isClassic ? classicBaize : theme.colors.fillSelected.opacity(0.35)
    }
}
