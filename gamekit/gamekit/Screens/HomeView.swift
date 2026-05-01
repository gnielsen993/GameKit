//
//  HomeView.swift
//  gamekit
//
//  The Drawer — entry point to all playable games. Renders one square
//  tile per `GameDescriptor.all` entry plus a static Upcoming tile that
//  presents `UpcomingGamesView` in a sheet.
//
//  Routing (refactored 2026-05-01 to fix expansibility audit finding):
//    - NavigationStack owns a `path: [GameRoute]` instead of a per-game
//      `@State navigateToX: Bool` flag.
//    - A single `.navigationDestination(for: GameRoute.self)` switch
//      maps a route case to its game view.
//    - Adding game #N = one descriptor entry in GameDescriptor.all +
//      one case in GameRoute + one switch arm here. HomeView body,
//      @State, and modifiers stay constant.
//
//  Per P1 D-02: this file owns its own NavigationStack — RootTabView
//  does not (Anti-Pattern 3 in ARCHITECTURE.md).
//

import SwiftUI
import DesignKit

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var path: [GameRoute] = []
    @State private var showingComingSoon: GameCard?
    @State private var showingUpcoming: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingStats: Bool = false

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: theme.spacing.m),
                        GridItem(.flexible(), spacing: theme.spacing.m)
                    ],
                    spacing: theme.spacing.m
                ) {
                    ForEach(GameDescriptor.all) { descriptor in
                        gameTile(for: descriptor)
                    }
                    upcomingTile
                }
                .padding(.horizontal, theme.spacing.l)
                .padding(.vertical, theme.spacing.l)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "The Drawer"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    profileMenu
                }
            }
            .navigationDestination(for: GameRoute.self) { route in
                destination(for: route)
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingStats) {
                StatsView()
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

    // MARK: - Routing

    @ViewBuilder
    private func destination(for route: GameRoute) -> some View {
        switch route {
        case .minesweeper:
            MinesweeperGameView()
        case .merge:
            MergeGameView()
        }
    }

    // MARK: - Tiles

    @ViewBuilder
    private func gameTile(for descriptor: GameDescriptor) -> some View {
        Button {
            path.append(descriptor.route)
        } label: {
            tileCard(
                symbol: descriptor.symbol,
                iconColor: accentColor(for: descriptor.accent),
                title: String(localized: String.LocalizationValue(descriptor.titleKey)),
                caption: String(localized: String.LocalizationValue(descriptor.captionKey))
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
    private var profileMenu: some View {
        Menu {
            Button {
                showingStats = true
            } label: {
                Label(String(localized: "Stats"), systemImage: "chart.bar")
            }
            Button {
                showingSettings = true
            } label: {
                Label(String(localized: "Settings"), systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 22))
                .foregroundStyle(theme.colors.textPrimary)
        }
        .accessibilityLabel(Text("Profile"))
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

    private func accentColor(for role: AccentRole) -> Color {
        switch role {
        case .primary:   return theme.colors.accentPrimary
        case .secondary: return theme.colors.accentSecondary
        }
    }
}

// MARK: - GameCard model (used by UpcomingGamesView)

struct GameCard: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let isEnabled: Bool
}
