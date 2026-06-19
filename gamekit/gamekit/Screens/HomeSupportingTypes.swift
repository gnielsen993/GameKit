//
//  HomeSupportingTypes.swift
//  gamekit
//
//  Small data shapes used by HomeView.
//

import Foundation

struct GameCard: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let isEnabled: Bool
}

// Stats sheet item: wraps optional GameKind so .sheet(item:) can carry both
// "focused on one game" and "show all" through the same binding.
struct StatsRequest: Identifiable {
    let id = UUID()
    let kind: GameKind?
}

// Upcoming games catalog. Entries here move to GameDescriptor.all when they
// graduate to playable. Order determines display order in the panel.
let homeUpcomingGames: [GameCard] = [
    GameCard(id: "flow",          title: String(localized: "Flow"),           symbol: "scribble.variable",  isEnabled: false),
    GameCard(id: "patternMemory", title: String(localized: "Pattern Memory"), symbol: "rectangle.grid.2x2", isEnabled: false),
    GameCard(id: "chessPuzzles",  title: String(localized: "Chess Puzzles"),  symbol: "checkmark.shield",   isEnabled: false),
]
