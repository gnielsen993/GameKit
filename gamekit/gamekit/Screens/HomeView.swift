//
//  HomeView.swift
//  gamekit
//
//  Phase 6.1 (SHELL-05): Home shows 2 square tiles in a 2-column
//  LazyVGrid — Minesweeper (enabled hero) + Upcoming (placeholder).
//  Tapping the Upcoming tile presents UpcomingGamesView in a sheet
//  listing the 8 planned games. Tapping any sheet row dismisses the
//  sheet and surfaces the existing ComingSoonOverlay (1.8s).
//
//  Per P1 D-02: this file owns its own NavigationStack — RootTabView
//  does not (Anti-Pattern 3 in ARCHITECTURE.md). The Mines push via
//  navigationDestination(isPresented:) is preserved verbatim from P1.
//
//  Real Minesweeper destination ships at Phase 3 (MINES-02..07).
//

import SwiftUI
import DesignKit

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingComingSoon: GameCard?
    @State private var navigateToMines: Bool = false
    @State private var showingUpcoming: Bool = false

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: theme.spacing.m),
                        GridItem(.flexible(), spacing: theme.spacing.m)
                    ],
                    spacing: theme.spacing.m
                ) {
                    minesTile
                    upcomingTile
                }
                .padding(.horizontal, theme.spacing.l)
                .padding(.vertical, theme.spacing.l)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "GameKit"))
            .navigationDestination(isPresented: $navigateToMines) {
                MinesweeperGameView()
            }
            .sheet(isPresented: $showingUpcoming) {
                UpcomingGamesView(theme: theme) { card in
                    showingComingSoon = card
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        if showingComingSoon?.id == card.id {
                            showingComingSoon = nil
                        }
                    }
                }
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

    // MARK: - Tiles

    @ViewBuilder
    private var minesTile: some View {
        Button {
            navigateToMines = true
        } label: {
            tileCard(
                symbol: "square.grid.4x3.fill",
                iconColor: theme.colors.accentPrimary,
                title: String(localized: "Minesweeper"),
                caption: String(localized: "Tap to play")
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var upcomingTile: some View {
        Button {
            showingUpcoming = true
        } label: {
            tileCard(
                symbol: "sparkles",
                iconColor: theme.colors.accentSecondary,
                title: String(localized: "Upcoming"),
                caption: String(localized: "8 games coming")
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tileCard(
        symbol: String,
        iconColor: Color,
        title: String,
        caption: String
    ) -> some View {
        DKCard(theme: theme) {
            VStack(spacing: theme.spacing.s) {
                Image(systemName: symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(caption)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - GameCard model

struct GameCard: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let isEnabled: Bool
}
