//
//  GameDescriptor.swift
//  gamekit
//
//  Single source of truth for the catalog of playable games surfaced on
//  the Home screen. Each entry pairs a GameKind (canonical persistence key,
//  see GameKind.swift) with display metadata (title, SF Symbol, accent
//  role) and a NavigationStack route.
//
//  Adding game #N (e.g. Nonogram) is a single descriptor entry here plus
//  a new case in GameRoute + the destination switch in HomeView. Home
//  body, @State, and modifiers do not change.
//
//  `accentRole` is an enum, not a `Color` — Color values come from
//  DesignKit tokens that resolve per-render against `theme`. The
//  descriptor stays Foundation-only / theme-agnostic.
//
//  `titleKey` and `captionKey` are raw English strings consumed by
//  `String(localized:)` at render time inside the consuming view, so
//  Localizable.xcstrings auto-extraction keeps working.
//

import Foundation

/// Which DesignKit accent token a tile / icon should resolve to.
/// Concrete `Color` values come from `theme.colors.accent{Primary,Secondary}`
/// inside the rendering view — the descriptor stays UI-token-agnostic.
enum AccentRole: Sendable {
    case primary
    case secondary
}

struct GameDescriptor: Identifiable, Hashable, Sendable {
    /// Canonical persistence key. Must match the GameKind raw value used
    /// in stats records / best-times rows / JSON export envelope.
    let kind: GameKind

    /// English source string for the tile title — passed to
    /// `String(localized:)` at render time.
    let titleKey: String

    /// English source string for the tile caption (e.g. "Tap to play").
    let captionKey: String

    /// SF Symbol identifier rendered as the tile glyph.
    let symbol: String

    /// Which accent token the glyph should resolve to per-render.
    let accent: AccentRole

    /// NavigationStack route this tile pushes when tapped.
    let route: GameRoute

    var id: GameKind { kind }
}

extension GameDescriptor {
    /// Catalog of currently-playable games surfaced as tiles on Home.
    /// Order = render order in the grid. Append new entries here when
    /// a game ships; remove or reorder freely.
    static let all: [GameDescriptor] = [
        GameDescriptor(
            kind: .minesweeper,
            titleKey: "Minesweeper",
            captionKey: "Tap to play",
            symbol: "square.grid.4x3.fill",
            accent: .primary,
            route: .minesweeper
        ),
        GameDescriptor(
            kind: .merge,
            titleKey: "Merge",
            captionKey: "Tap to play",
            symbol: "square.stack.3d.up.fill",
            accent: .secondary,
            route: .merge
        )
    ]
}
