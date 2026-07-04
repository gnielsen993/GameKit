//
//  HomeView.swift
//  gamekit
//
//  The Drawer — entry point to all playable games.
//
//  Closed state: 3-column icon grid. Tap a tile to expand.
//  Open state: selected tile at 96pt; all others shrink to 44pt in
//  a horizontal ScrollView strip; HomeDetailPanel (or upcoming panel)
//  appears below.
//
//  Expanded state covers both games (expandedKind) and the Upcoming
//  tile (expandedUpcoming). A 36pt clear zone at the top of the
//  expanded content gives a tap-to-dismiss target above the strip.
//
//  Stats sheet uses .sheet(item:) so focusedKind is always captured
//  at presentation time, not at closure-capture time.
//

import SwiftUI
import DesignKit

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.settingsStore) private var settingsStore

    @State private var path: [GameRoute] = []
    @State private var expandedKind: GameKind?
    @State private var expandedUpcoming = false
    @State private var showingComingSoon: GameCard?
    @State private var showingSettings: Bool = false
    @State private var showingVideoMode: Bool = false
    @State private var statsRequest: StatsRequest? = nil

    private var theme: Theme { themeManager.theme(using: colorScheme) }
    private var isExpanded: Bool { expandedKind != nil || expandedUpcoming }

    /// Expansion spring, hard-cut to instant under Reduce Motion or when
    /// animations are disabled in Settings (DESIGN.md §10.2).
    private var expansionSpring: Animation? {
        settingsStore.animationsEnabled && !reduceMotion
            ? .spring(response: 0.42, dampingFraction: 0.78)
            : nil
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                ZStack(alignment: .top) {
                    theme.colors.background
                        .contentShape(Rectangle())
                        .onTapGesture { collapse() }

                    VStack(spacing: theme.spacing.m) {
                        if !isExpanded {
                            closedGrid
                        } else {
                            openStrip

                            if let kind = expandedKind,
                               let descriptor = GameDescriptor.all.first(where: { $0.kind == kind }) {
                                HomeDetailPanel(
                                    descriptor: descriptor,
                                    theme: theme,
                                    onSelect: { route in
                                        collapse()
                                        path.append(route)
                                    },
                                    onStats: {
                                        statsRequest = StatsRequest(kind: expandedKind)
                                    }
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            } else if expandedUpcoming {
                                upcomingDetailPanel
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }
                    .padding(.horizontal, theme.spacing.m)
                    .padding(.top, theme.spacing.s)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .animation(expansionSpring, value: expandedKind)
                    .animation(expansionSpring, value: expandedUpcoming)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "The Drawer"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HomeVideoModeButton(theme: theme) {
                        showingVideoMode = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    profileMenu
                }
            }
            .navigationDestination(for: GameRoute.self) { route in
                destination(for: route)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingVideoMode) {
                HomeVideoModeSheet()
            }
            .sheet(item: $statsRequest) { req in
                StatsView(focusedKind: req.kind)
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

    // MARK: - Collapse helper

    private func collapse() {
        withAnimation(expansionSpring) {
            expandedKind = nil
            expandedUpcoming = false
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

    // MARK: - Open strip (one tile selected)

    private var openStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.m) {
                ForEach(GameDescriptor.all) { descriptor in
                    let isSelected = expandedKind == descriptor.kind
                    gameTile(descriptor, tileSize: isSelected ? 96 : 44, showLabel: isSelected)
                        .opacity(isSelected ? 1 : (expandedUpcoming ? 0.35 : 0.45))
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
            // Modeless games (endless arcade — Stack / Snake, captioned "Tap to play")
            // have no mode/difficulty picker, so a tap navigates straight to the game
            // instead of expanding an empty HomeDetailPanel (ARCADE-09).
            if descriptor.modes.isEmpty {
                collapse()
                path.append(descriptor.route)
                return
            }
            withAnimation(expansionSpring) {
                expandedUpcoming = false
                expandedKind = expandedKind == descriptor.kind ? nil : descriptor.kind
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: tileSize * 0.26, style: .continuous)
                        .fill(descriptor.kind.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: tileSize * 0.26, style: .continuous)
                                .fill(SurfaceDepth.raisedSheen)
                        )
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

                if showLabel {
                    Text(String(localized: "\(descriptor.titleKey)"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.pressableSubtle)
        .accessibilityLabel(Text(descriptor.titleKey))
    }

    // MARK: - Upcoming tile (closed grid)

    private var upcomingGridTile: some View {
        Button {
            withAnimation(expansionSpring) {
                expandedKind = nil
                expandedUpcoming = true
            }
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
        .buttonStyle(.pressableSubtle)
        .accessibilityLabel(Text("Upcoming games"))
    }

    // MARK: - Upcoming tile (open strip)

    private var upcomingStripTile: some View {
        let isSelected = expandedUpcoming
        let size: CGFloat = isSelected ? 96 : 44
        return Button {
            withAnimation(expansionSpring) {
                if isSelected {
                    expandedUpcoming = false
                } else {
                    expandedKind = nil
                    expandedUpcoming = true
                }
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .fill(theme.colors.accentSecondary.opacity(isSelected ? 0.22 : 0.14))
                        .shadow(
                            color: theme.colors.accentSecondary.opacity(isSelected ? 0.45 : 0),
                            radius: isSelected ? 14 : 0,
                            x: 0, y: isSelected ? 8 : 0
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: size * 0.33, weight: .semibold))
                        .foregroundStyle(theme.colors.accentSecondary)
                }
                .frame(width: size, height: size)

                if isSelected {
                    Text(String(localized: "Upcoming"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.pressableSubtle)
        .opacity(isSelected ? 1 : (expandedKind != nil ? 0.45 : 0.55))
        .accessibilityLabel(Text("Upcoming games"))
    }

    // MARK: - Upcoming detail panel (inline, mirrors HomeDetailPanel structure)

    private var upcomingDetailPanel: some View {
        let iconSz: CGFloat = 64
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: theme.spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: iconSz * 0.26, style: .continuous)
                        .fill(theme.colors.accentSecondary.opacity(0.18))
                        .shadow(color: theme.colors.accentSecondary.opacity(0.35), radius: 10, x: 0, y: 6)
                    Image(systemName: "sparkles")
                        .font(.system(size: iconSz * 0.36, weight: .semibold))
                        .foregroundStyle(theme.colors.accentSecondary)
                }
                .frame(width: iconSz, height: iconSz)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Upcoming"))
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(String(localized: "In development"))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                Spacer(minLength: 0)
            }

            Divider().padding(.vertical, theme.spacing.m)

            VStack(spacing: theme.spacing.s) {
                ForEach(homeUpcomingGames) { card in
                    Button {
                        showingComingSoon = card
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_800_000_000)
                            if showingComingSoon?.id == card.id { showingComingSoon = nil }
                        }
                    } label: {
                        HStack(spacing: theme.spacing.m) {
                            Image(systemName: card.symbol)
                                .font(.body)
                                .foregroundStyle(theme.colors.textSecondary)
                                .frame(width: 28)
                            Text(card.title)
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textPrimary)
                            Spacer()
                            Image(systemName: "lock")
                                .font(.caption)
                                .foregroundStyle(theme.colors.textTertiary)
                        }
                        .padding(.vertical, theme.spacing.xs)
                    }
                    .buttonStyle(.plain)

                    if card.id != homeUpcomingGames.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(theme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(theme.colors.surface)
                .shadow(color: theme.colors.textPrimary.opacity(0.10), radius: 16, x: 0, y: 8)
        )
    }

    // MARK: - Routing

    @ViewBuilder
    private func destination(for route: GameRoute) -> some View {
        switch route {
        case .minesweeper(let difficulty):
            MinesweeperGameView(initialDifficulty: difficulty)
                .videoModeAware(minBoardHeight: 480)
                .disableInteractivePop()
        case .merge(let mode):
            MergeGameView(initialMode: mode)
                .videoModeAware(minBoardHeight: 480)
                .disableInteractivePop()
        case .nonogram(let difficulty, let mode):
            NonogramGameView(initialDifficulty: difficulty, initialMode: mode)
                .videoModeAware(minBoardHeight: 480)
                .disableInteractivePop()
        case .sudoku(let difficulty, let mode):
            SudokuGameView(initialDifficulty: difficulty, initialMode: mode)
                .videoModeAware(minBoardHeight: 480)
                .disableInteractivePop()
        case .klondike(let difficulty):
            SolitaireGameView(initialDifficulty: difficulty ?? .easy)
                .disableInteractivePop()
        case .freeCell(let mode):
            FreeCellGameView(initialMode: mode ?? .random(.easy))
                .videoModeAware(minBoardHeight: 480)
                .disableInteractivePop()
        case .fiveLetter(let mode):
            FiveLetterGameView(initialMode: mode)
                .videoModeAware(minBoardHeight: 480)
                .disableInteractivePop()
        case .wordGrid(let mode):
            WordGridGameView(initialMode: mode)
                .videoModeAware(minBoardHeight: 480)
                .disableInteractivePop()
        // ADR ARCADE-08 amendment (15-VIDEO-MODE-ADR.md, 2026-07-02): Stack adopts Video Mode —
        // its engine is pure normalized-coordinate and the canvas rescales per frame, so a PiP
        // reflow cannot desync state. Snake stays exempt (pixel-derived grid cells + continuous
        // steering); Klondike stays exempt by convention (drag interactions).
        case .stack:
            StackGameView()
                .videoModeAware(minBoardHeight: 480)
                .disableInteractivePop()
        case .snake:
            // NOTE: NO Video Mode modifier — Snake exempt per 15-VIDEO-MODE-ADR.md
            // (pixel-derived grid cells + continuous steering; PiP reflow would desync state).
            // Compare Stack above: StackGameView().videoModeAware(...).disableInteractivePop()
            SnakeGameView()
                .disableInteractivePop()
        }
    }

    @ViewBuilder
    private var profileMenu: some View {
        Menu {
            Button {
                statsRequest = StatsRequest(kind: nil)
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
