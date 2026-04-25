//
//  HomeView.swift
//  gamekit
//
//  Phase 1 (SHELL-01): 9 game cards in PROJECT.md long-term-vision order.
//  Minesweeper is the only enabled card. The other 8 are disabled
//  placeholders that surface a ComingSoonOverlay on tap (D-03, D-06).
//
//  Per D-02: this file owns its own NavigationStack — RootTabView
//  does not (Anti-Pattern 3 in ARCHITECTURE.md).
//
//  Real Minesweeper destination ships at Phase 3 (MINES-02..07);
//  P1 destination is a token-styled "Coming in P3" placeholder.
//

import SwiftUI
import DesignKit

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingComingSoon: GameCard?
    @State private var navigateToMines: Bool = false

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.s) {
                    ForEach(cards) { card in
                        cardRow(card)
                    }
                }
                .padding(.vertical, theme.spacing.l)
                .padding(.horizontal, theme.spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "GameKit"))
            .navigationDestination(isPresented: $navigateToMines) {
                minesweeperPlaceholder
            }
            .overlay(alignment: .bottom) {
                if let card = showingComingSoon {
                    ComingSoonOverlay(
                        title: String(localized: "\(card.title) coming soon"),
                        theme: theme
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func cardRow(_ card: GameCard) -> some View {
        Button {
            handleTap(card)
        } label: {
            DKCard(theme: theme) {
                HStack(spacing: theme.spacing.m) {
                    Image(systemName: card.symbol)
                        .font(.title2)
                        .foregroundStyle(card.isEnabled
                            ? theme.colors.accentPrimary
                            : theme.colors.textTertiary)

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text(card.title)
                            .font(theme.typography.headline)
                            .foregroundStyle(card.isEnabled
                                ? theme.colors.textPrimary
                                : theme.colors.textTertiary)
                        if !card.isEnabled {
                            Text(String(localized: "Coming soon"))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textTertiary)
                        }
                    }
                    Spacer()
                    Image(systemName: card.isEnabled ? "chevron.right" : "lock")
                        .foregroundStyle(theme.colors.textTertiary)
                }
                .opacity(card.isEnabled ? 1.0 : 0.6)
            }
        }
        .buttonStyle(.plain)
    }

    private func handleTap(_ card: GameCard) {
        if card.isEnabled {
            navigateToMines = true
        } else {
            showingComingSoon = card
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                if showingComingSoon?.id == card.id {
                    showingComingSoon = nil
                }
            }
        }
    }

    @ViewBuilder
    private var minesweeperPlaceholder: some View {
        VStack(spacing: theme.spacing.m) {
            Image(systemName: "square.grid.4x3.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme.colors.accentPrimary)
            Text(String(localized: "Minesweeper coming in Phase 3"))
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
            Text(String(localized: "The board, gestures, and timer arrive next."))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(String(localized: "Minesweeper"))
    }
}

// MARK: - GameCard model + data

struct GameCard: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let isEnabled: Bool
}

private let cards: [GameCard] = [
    GameCard(id: "minesweeper",   title: String(localized: "Minesweeper"),    symbol: "square.grid.4x3.fill", isEnabled: true),
    GameCard(id: "merge",         title: String(localized: "Merge"),          symbol: "square.stack.3d.up",   isEnabled: false),
    GameCard(id: "wordGrid",      title: String(localized: "Word Grid"),      symbol: "textformat.abc",       isEnabled: false),
    GameCard(id: "solitaire",     title: String(localized: "Solitaire"),      symbol: "suit.spade",           isEnabled: false),
    GameCard(id: "sudoku",        title: String(localized: "Sudoku"),         symbol: "9.square",             isEnabled: false),
    GameCard(id: "nonogram",      title: String(localized: "Nonogram"),       symbol: "square.grid.3x3",      isEnabled: false),
    GameCard(id: "flow",          title: String(localized: "Flow"),           symbol: "scribble.variable",    isEnabled: false),
    GameCard(id: "patternMemory", title: String(localized: "Pattern Memory"), symbol: "rectangle.grid.2x2",   isEnabled: false),
    GameCard(id: "chessPuzzles",  title: String(localized: "Chess Puzzles"),  symbol: "checkmark.shield",     isEnabled: false),
]
