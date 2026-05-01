//
//  UpcomingGamesView.swift
//  gamekit
//
//  Phase 6.1 (SHELL-05): sheet-presented list of 8 planned games.
//  Tapping any row bubbles back to HomeView via onSelectComingSoon
//  closure, surfacing the existing ComingSoonOverlay 1.8s auto-dismiss.
//
//  Props-only per CLAUDE.md §8.2 — receives theme + selection callback;
//  owns no SwiftData context-environment / state-store reads.
//  Static 8-game list lives at file scope.
//

import SwiftUI
import DesignKit

struct UpcomingGamesView: View {
    let theme: Theme
    let onSelectComingSoon: (GameCard) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(upcomingGames) { card in
                    Button {
                        onSelectComingSoon(card)
                        dismiss()
                    } label: {
                        HStack(spacing: theme.spacing.m) {
                            Image(systemName: card.symbol)
                                .font(.title2)
                                .foregroundStyle(theme.colors.textTertiary)
                            Text(card.title)
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)
                            Spacer()
                            Image(systemName: "lock")
                                .foregroundStyle(theme.colors.textTertiary)
                        }
                        .padding(.vertical, theme.spacing.xs)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.colors.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Upcoming"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                        .foregroundStyle(theme.colors.accentPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// Merge graduated to a playable game (`GameDescriptor.all` in Core/),
// removed from this list 2026-05-01. Add new entries here as games
// move from "planned" to "playable" — descriptor entry in
// `GameDescriptor.swift` removes them from the upcoming sheet.
private let upcomingGames: [GameCard] = [
    GameCard(id: "wordGrid",      title: String(localized: "Word Grid"),      symbol: "textformat.abc",       isEnabled: false),
    GameCard(id: "solitaire",     title: String(localized: "Solitaire"),      symbol: "suit.spade",           isEnabled: false),
    GameCard(id: "sudoku",        title: String(localized: "Sudoku"),         symbol: "9.square",             isEnabled: false),
    GameCard(id: "nonogram",      title: String(localized: "Nonogram"),       symbol: "square.grid.3x3",      isEnabled: false),
    GameCard(id: "flow",          title: String(localized: "Flow"),           symbol: "scribble.variable",    isEnabled: false),
    GameCard(id: "patternMemory", title: String(localized: "Pattern Memory"), symbol: "rectangle.grid.2x2",   isEnabled: false),
    GameCard(id: "chessPuzzles",  title: String(localized: "Chess Puzzles"),  symbol: "checkmark.shield",     isEnabled: false),
]
