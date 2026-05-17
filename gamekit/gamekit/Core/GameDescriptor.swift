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

/// Catalogue accent slot a tile / drawer should render in. Each game pins
/// a stable slot so neighboring drawers always read as visually distinct
/// regardless of the active preset. Concrete `Color` values resolve via
/// `theme.catalogueColor(slot.index)` at render time so the descriptor
/// stays UI-token-agnostic (CLAUDE.md §1).
///
/// Slots are named, not numbered, so a reorder of `GameDescriptor.all`
/// does not silently swap every game's color. Adding game #N = pick the
/// next unused slot.
enum AccentRole: Sendable {
    case slot1
    case slot2
    case slot3
    case slot4
    case slot5
    case slot6

    /// Index into `theme.catalogueColor(_:)`.
    var index: Int {
        switch self {
        case .slot1: return 0
        case .slot2: return 1
        case .slot3: return 2
        case .slot4: return 3
        case .slot5: return 4
        case .slot6: return 5
        }
    }
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

    /// NavigationStack route this tile pushes when tapped with no mode
    /// selected (resume last-played, see GameRoute.swift).
    let route: GameRoute

    /// Mode chips revealed inside the drawer when this row is expanded.
    /// Empty = no mode selection surfaced (drawer just opens the game).
    let modes: [GameModeChip]

    var id: GameKind { kind }
}

/// One mode/difficulty chip rendered inside an expanded drawer.
/// `route` already carries the concrete mode/difficulty as an associated
/// value, so tapping the chip is a single `path.append(chip.route)` — no
/// chip-to-route translation table needed at the call site.
struct GameModeChip: Identifiable, Hashable, Sendable {
    /// Stable id for ForEach. Game-scoped string, not globally unique.
    let id: String

    /// English source string for the chip label — passed to
    /// `String(localized:)` at render time.
    let labelKey: String

    /// Optional secondary line (e.g. "9×9" under "Easy"). Empty = single-line chip.
    let detailKey: String

    /// NavigationStack route pushed when this chip is tapped.
    let route: GameRoute
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
            accent: .slot1,
            route: .minesweeper(nil),
            modes: [
                GameModeChip(id: "easy",   labelKey: "Easy",   detailKey: "9×9 · 10",  route: .minesweeper(.easy)),
                GameModeChip(id: "medium", labelKey: "Medium", detailKey: "16×16 · 40", route: .minesweeper(.medium)),
                GameModeChip(id: "hard",   labelKey: "Hard",   detailKey: "24×16 · 80", route: .minesweeper(.hard))
            ]
        ),
        GameDescriptor(
            kind: .merge,
            titleKey: "Merge",
            captionKey: "Tap to play",
            symbol: "square.stack.3d.up.fill",
            accent: .slot2,
            route: .merge(nil),
            modes: [
                GameModeChip(id: "win",      labelKey: "2048",     detailKey: "Classic", route: .merge(.winMode)),
                GameModeChip(id: "infinite", labelKey: "Infinite", detailKey: "Endless", route: .merge(.infinite))
            ]
        ),
        GameDescriptor(
            kind: .nonogram,
            titleKey: "Nonogram",
            captionKey: "Tap to play",
            symbol: "square.grid.3x3.square",
            accent: .slot3,
            route: .nonogram(nil),
            modes: [
                GameModeChip(id: "tiny",   labelKey: "5×5",   detailKey: "Tiny",   route: .nonogram(.tiny)),
                GameModeChip(id: "small",  labelKey: "10×10", detailKey: "Small",  route: .nonogram(.small)),
                GameModeChip(id: "medium", labelKey: "15×15", detailKey: "Medium", route: .nonogram(.medium)),
                GameModeChip(id: "large",  labelKey: "20×20", detailKey: "Large",  route: .nonogram(.large))
            ]
        ),
        GameDescriptor(
            kind: .sudoku,
            titleKey: "Sudoku",
            captionKey: "Tap to play",
            symbol: "square.grid.3x3.fill",
            accent: .slot4,
            route: .sudoku(nil),
            modes: [
                GameModeChip(id: "easy",    labelKey: "Easy",    detailKey: "9×9", route: .sudoku(.easy)),
                GameModeChip(id: "medium",  labelKey: "Medium",  detailKey: "9×9", route: .sudoku(.medium)),
                GameModeChip(id: "hard",    labelKey: "Hard",    detailKey: "9×9", route: .sudoku(.hard)),
                GameModeChip(id: "extreme", labelKey: "Extreme", detailKey: "9×9", route: .sudoku(.extreme))
            ]
        )
    ]
}
