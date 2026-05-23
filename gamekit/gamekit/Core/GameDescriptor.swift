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
///
/// Two variants:
/// - **Leaf chip** (`route != nil`, `subModes` empty): tapping pushes the
///   route directly — single-step games (Minesweeper, Merge) use this.
/// - **Parent chip** (`route == nil`, `subModes` non-empty): tapping drills
///   to a second tier inside the same fixed-height cavity — two-step games
///   (Sudoku, Nonogram) use this to surface Free vs Lives before difficulty.
struct GameModeChip: Identifiable, Hashable, Sendable {
    let id: String
    let labelKey: String
    /// Optional secondary line (e.g. "Easy" under "Free"). Empty = single-line.
    let detailKey: String
    /// nil for parent chips (drill-down); non-nil for leaf chips (launch).
    let route: GameRoute?
    /// Non-empty only on parent chips. Shown in the cavity after drill-in.
    let subModes: [GameModeChip]

    init(id: String, labelKey: String, detailKey: String = "", route: GameRoute) {
        self.id = id; self.labelKey = labelKey; self.detailKey = detailKey
        self.route = route; self.subModes = []
    }

    init(id: String, labelKey: String, subModes: [GameModeChip]) {
        self.id = id; self.labelKey = labelKey; self.detailKey = ""
        self.route = nil; self.subModes = subModes
    }
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
            route: .nonogram(nil, nil),
            modes: [
                GameModeChip(id: "nono-free", labelKey: "Free", subModes: [
                    GameModeChip(id: "nono-free-tiny",   labelKey: "5×5",   detailKey: "Tiny",   route: .nonogram(.tiny,   .free)),
                    GameModeChip(id: "nono-free-small",  labelKey: "10×10", detailKey: "Small",  route: .nonogram(.small,  .free)),
                    GameModeChip(id: "nono-free-medium", labelKey: "15×15", detailKey: "Medium", route: .nonogram(.medium, .free)),
                    GameModeChip(id: "nono-free-large",  labelKey: "20×20", detailKey: "Large",  route: .nonogram(.large,  .free))
                ]),
                GameModeChip(id: "nono-lives", labelKey: "Lives", subModes: [
                    GameModeChip(id: "nono-lives-tiny",   labelKey: "5×5",   detailKey: "Tiny",   route: .nonogram(.tiny,   .lives)),
                    GameModeChip(id: "nono-lives-small",  labelKey: "10×10", detailKey: "Small",  route: .nonogram(.small,  .lives)),
                    GameModeChip(id: "nono-lives-medium", labelKey: "15×15", detailKey: "Medium", route: .nonogram(.medium, .lives)),
                    GameModeChip(id: "nono-lives-large",  labelKey: "20×20", detailKey: "Large",  route: .nonogram(.large,  .lives))
                ])
            ]
        ),
        GameDescriptor(
            kind: .sudoku,
            titleKey: "Sudoku",
            captionKey: "Tap to play",
            symbol: "square.grid.3x3.fill",
            accent: .slot4,
            route: .sudoku(nil, nil),
            modes: [
                GameModeChip(id: "sudoku-free", labelKey: "Free", subModes: [
                    GameModeChip(id: "sudoku-free-easy",    labelKey: "Easy",    route: .sudoku(.easy,    .free)),
                    GameModeChip(id: "sudoku-free-medium",  labelKey: "Medium",  route: .sudoku(.medium,  .free)),
                    GameModeChip(id: "sudoku-free-hard",    labelKey: "Hard",    route: .sudoku(.hard,    .free)),
                    GameModeChip(id: "sudoku-free-extreme", labelKey: "Extreme", route: .sudoku(.extreme, .free))
                ]),
                GameModeChip(id: "sudoku-lives", labelKey: "Lives", subModes: [
                    GameModeChip(id: "sudoku-lives-easy",    labelKey: "Easy",    route: .sudoku(.easy,    .lives)),
                    GameModeChip(id: "sudoku-lives-medium",  labelKey: "Medium",  route: .sudoku(.medium,  .lives)),
                    GameModeChip(id: "sudoku-lives-hard",    labelKey: "Hard",    route: .sudoku(.hard,    .lives)),
                    GameModeChip(id: "sudoku-lives-extreme", labelKey: "Extreme", route: .sudoku(.extreme, .lives))
                ])
            ]
        ),
        GameDescriptor(
            kind: .freeCell,
            titleKey: "FreeCell",
            captionKey: "Tap to play",
            symbol: "suit.spade.fill",
            accent: .slot5,
            route: .freeCell(nil),
            modes: [
                GameModeChip(id: "fc-easy",   labelKey: "Easy",   route: .freeCell(.random(.easy))),
                GameModeChip(id: "fc-medium", labelKey: "Medium", route: .freeCell(.random(.medium))),
                GameModeChip(id: "fc-hard",   labelKey: "Hard",   route: .freeCell(.random(.hard))),
                GameModeChip(id: "fc-expert", labelKey: "Expert", route: .freeCell(.random(.expert))),
                GameModeChip(id: "fc-deal",   labelKey: "Deal #", route: .freeCell(.enterDeal))
            ]
        )
    ]
}
