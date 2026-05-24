//
//  HomeView.swift
//  gamekit
//
//  The Drawer — entry point to all playable games.
//
//  Closed state: 3-column icon grid, each tile 78pt. Tap a tile to expand.
//  Open state: selected tile renders at 96pt; all others shrink to 44pt in
//  a horizontal ScrollView strip; HomeDetailPanel appears below.
//
//  Routing:
//    - NavigationStack owns `path: [GameRoute]`. A single
//      `.navigationDestination(for: GameRoute.self)` switch maps each
//      case (with its associated mode) to its game view's init.
//    - Adding game #N = one descriptor entry in GameDescriptor.all +
//      one case in GameRoute + one switch arm here.
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
    @State private var expandedKind: GameKind?
    @State private var showingComingSoon: GameCard?
    @State private var showingUpcoming: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingStats: Bool = false
    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                ZStack(alignment: .top) {
                    theme.colors.background
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                                expandedKind = nil
                            }
                        }

                    VStack(spacing: theme.spacing.m) {
                        if expandedKind == nil {
                            closedGrid
                        } else {
                            openStrip
                            if let kind = expandedKind,
                               let descriptor = GameDescriptor.all.first(where: { $0.kind == kind }) {
                                HomeDetailPanel(
                                    descriptor: descriptor,
                                    theme: theme,
                                    onSelect: { route in
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                                            expandedKind = nil
                                        }
                                        path.append(route)
                                    },
                                    onStats: { showingStats = true }
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }
                    .padding(.horizontal, theme.spacing.m)
                    .padding(.top, theme.spacing.s)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .animation(.spring(response: 0.42, dampingFraction: 0.78), value: expandedKind)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
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

    // MARK: - Closed grid (no selection)

    private var closedGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 26) {
            ForEach(GameDescriptor.all) { descriptor in
                gameTile(descriptor, tileSize: 78, showLabel: true)
            }
            upcomingGridTile
        }
        .padding(.top, theme.spacing.s)
    }

    // MARK: - Open strip (one game selected)

    private var openStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.m) {
                ForEach(GameDescriptor.all) { descriptor in
                    let isSelected = expandedKind == descriptor.kind
                    gameTile(descriptor, tileSize: isSelected ? 96 : 44, showLabel: isSelected)
                        .opacity(isSelected ? 1 : 0.45)
                        .blur(radius: isSelected ? 0 : 0.5)
                }
                upcomingStripTile
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.s)
        }
        .padding(.horizontal, -theme.spacing.m)
    }

    // MARK: - Tile builders

    @ViewBuilder
    private func gameTile(_ descriptor: GameDescriptor, tileSize: CGFloat, showLabel: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                expandedKind = expandedKind == descriptor.kind ? nil : descriptor.kind
            }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: tileSize * 0.26, style: .continuous)
                            .fill(descriptor.kind.accentColor)
                            .shadow(
                                color: descriptor.kind.accentColor.opacity(
                                    expandedKind == descriptor.kind ? 0.55 : 0.38
                                ),
                                radius: expandedKind == descriptor.kind ? 18 : 10,
                                x: 0, y: expandedKind == descriptor.kind ? 10 : 6
                            )
                        GameIconView(kind: descriptor.kind, size: tileSize * 0.54)
                    }
                    .frame(width: tileSize, height: tileSize)

                    if descriptor.isNew && expandedKind == nil {
                        newBadge
                            .offset(x: 4, y: -4)
                    }
                }

                if showLabel {
                    Text(String(localized: "\(descriptor.titleKey)"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(descriptor.titleKey))
    }

    private var newBadge: some View {
        Text("!")
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundStyle(theme.colors.textPrimary)
            .frame(width: 18, height: 18)
            .background(Circle().fill(theme.colors.surface))
            .shadow(color: theme.colors.textPrimary.opacity(0.12), radius: 3, x: 0, y: 1)
    }

    private var upcomingGridTile: some View {
        Button {
            expandedKind = nil
            showingUpcoming = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                        .fill(theme.colors.accentSecondary.opacity(0.14))
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(theme.colors.accentSecondary)
                }
                .frame(width: 78, height: 78)

                Text(String(localized: "Upcoming"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Upcoming games"))
    }

    private var upcomingStripTile: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                expandedKind = nil
            }
            showingUpcoming = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                    .fill(theme.colors.accentSecondary.opacity(0.14))
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.colors.accentSecondary)
            }
            .frame(width: 44, height: 44)
            .opacity(0.55)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Upcoming games"))
    }

    // MARK: - Routing

    @ViewBuilder
    private func destination(for route: GameRoute) -> some View {
        switch route {
        case .minesweeper(let difficulty):
            MinesweeperGameView(initialDifficulty: difficulty)
                .videoModeAware(minBoardHeight: 480)
        case .merge(let mode):
            MergeGameView(initialMode: mode)
                .videoModeAware(minBoardHeight: 480)
        case .nonogram(let difficulty, let mode):
            NonogramGameView(initialDifficulty: difficulty, initialMode: mode)
                .videoModeAware(minBoardHeight: 480)
        case .sudoku(let difficulty, let mode):
            SudokuGameView(initialDifficulty: difficulty, initialMode: mode)
                .videoModeAware(minBoardHeight: 480)
        case .klondike(let difficulty):
            SolitaireGameView(initialDifficulty: difficulty ?? .easy)
        case .freeCell(let mode):
            FreeCellGameView(initialMode: mode ?? .random(.easy))
                .videoModeAware(minBoardHeight: 480)
        }
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
}

// MARK: - GameCard model (used by UpcomingGamesView)

struct GameCard: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let isEnabled: Bool
}
