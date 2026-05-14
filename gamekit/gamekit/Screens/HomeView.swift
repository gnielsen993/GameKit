//
//  HomeView.swift
//  gamekit
//
//  The Drawer — entry point to all playable games. Renders one full-width
//  drawer row per `GameDescriptor.all` entry plus a static Upcoming row
//  that presents `UpcomingGamesView` in a sheet.
//
//  Drawer interaction (2026-05-11):
//    - Each row is a closed drawer face. Tap → expand, revealing the
//      game's mode chips inside the drawer cavity (see DrawerRow.swift).
//    - Single accordion: only one drawer open at a time. Sibling drawers
//      dim to 0.4 opacity while another is expanded so the open one
//      reads as the focused element.
//    - Tap a mode chip → push the chip's GameRoute (carries the chosen
//      difficulty/mode as an associated value, see GameRoute.swift).
//    - Tap the open drawer's face again, or tap any dimmed sibling, to
//      collapse / switch.
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
            // Plain ZStack — no ScrollView. With 3 playable drawers +
            // Upcoming the catalogue comfortably fits on every supported
            // device; dropping ScrollView lets the whole page background
            // receive taps so "tap anywhere outside" closes a drawer
            // even above the first row or below Upcoming.
            ZStack(alignment: .top) {
                theme.colors.background
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if expandedKind != nil { expandedKind = nil }
                    }

                VStack(spacing: theme.spacing.s) {
                    ForEach(GameDescriptor.all) { descriptor in
                        DrawerRow(
                            descriptor: descriptor,
                            theme: theme,
                            isExpanded: expandedKind == descriptor.kind,
                            onToggle: {
                                // When another drawer is open, tapping
                                // any closed drawer collapses the cabinet
                                // rather than switching expansion. Open
                                // drawer's own face is hidden under the
                                // cavity so its onToggle won't fire.
                                if let active = expandedKind, active != descriptor.kind {
                                    expandedKind = nil
                                } else {
                                    toggle(descriptor.kind)
                                }
                            },
                            onSelectMode: { route in
                                expandedKind = nil
                                path.append(route)
                            }
                        )
                        .opacity(opacity(for: descriptor.kind))
                        .scaleEffect(scale(for: descriptor.kind), anchor: .top)
                    }

                    upcomingRow
                        .opacity(expandedKind == nil ? 1 : 0.4)
                }
                .padding(.horizontal, theme.spacing.m)
                .padding(.top, theme.spacing.s)
                .frame(maxWidth: .infinity, alignment: .top)
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: expandedKind)
            }
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

    // MARK: - Accordion state

    private func toggle(_ kind: GameKind) {
        if expandedKind == kind {
            expandedKind = nil
        } else {
            expandedKind = kind
        }
    }

    private func opacity(for kind: GameKind) -> Double {
        guard let expandedKind else { return 1 }
        return expandedKind == kind ? 1 : 0.4
    }

    private func scale(for kind: GameKind) -> CGFloat {
        guard let expandedKind else { return 1 }
        return expandedKind == kind ? 1 : 0.98
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
        case .nonogram(let difficulty):
            NonogramGameView(initialDifficulty: difficulty)
        }
    }

    // MARK: - Upcoming row

    @ViewBuilder
    private var upcomingRow: some View {
        Button {
            expandedKind = nil
            showingUpcoming = true
        } label: {
            HStack(spacing: theme.spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                        .fill(theme.colors.accentSecondary.opacity(0.18))
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(theme.colors.accentSecondary)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Upcoming"))
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(String(localized: "6 games coming"))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Spacer(minLength: theme.spacing.s)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(theme.colors.background.opacity(0.6)))
            }
            .padding(.horizontal, theme.spacing.l)
            .padding(.vertical, theme.spacing.m)
            .background(
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .fill(theme.colors.surface)
                    .shadow(color: DrawerChrome.shadow.opacity(0.08), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .stroke(theme.colors.border.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
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
