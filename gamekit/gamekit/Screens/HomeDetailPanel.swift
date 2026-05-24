//
//  HomeDetailPanel.swift
//  gamekit
//
//  Appears below the horizontal tile strip when a game is expanded on HomeView.
//  Driven entirely by GameDescriptor props — no SwiftData access here.
//

import SwiftUI
import DesignKit

struct HomeDetailPanel: View {
    let descriptor: GameDescriptor
    let theme: Theme
    var onSelect: (GameRoute) -> Void
    var onStats: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.vertical, theme.spacing.m)
            modeSection
            statsLink
        }
        .padding(theme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(theme.colors.surface)
                .shadow(color: theme.colors.textPrimary.opacity(0.10), radius: 16, x: 0, y: 8)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacing.m) {
            iconTile(size: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "\(descriptor.titleKey)"))
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(descriptor.shortMeta)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Mode chips

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text("MODE / DIFFICULTY")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.colors.textSecondary)
                .kerning(1.4)

            modeChips(descriptor.modes)
        }
    }

    @ViewBuilder
    private func modeChips(_ chips: [GameModeChip]) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        LazyVGrid(columns: columns, spacing: theme.spacing.s) {
            ForEach(chips) { chip in
                if let route = chip.route {
                    // Leaf chip — tapping launches the game
                    Button {
                        onSelect(route)
                    } label: {
                        chipLabel(chip)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Parent chip with sub-modes — show sub-modes inline
                    ForEach(chip.subModes) { sub in
                        if let route = sub.route {
                            Button {
                                onSelect(route)
                            } label: {
                                chipLabel(sub)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipLabel(_ chip: GameModeChip) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(localized: "\(chip.labelKey)"))
                .font(theme.typography.body.weight(.semibold))
                .foregroundStyle(theme.colors.textPrimary)
            if !chip.detailKey.isEmpty {
                Text(chip.detailKey.uppercased())
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.colors.textSecondary)
                    .kerning(0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .fill(theme.colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                        .stroke(theme.colors.border.opacity(0.6), lineWidth: 1)
                )
        )
    }

    // MARK: - Stats link

    private var statsLink: some View {
        Button(action: onStats) {
            HStack(spacing: 6) {
                Text(String(localized: "Stats"))
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(descriptor.kind.accentColor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(descriptor.kind.accentColor.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
        .padding(.top, theme.spacing.m)
    }

    // MARK: - Icon tile helper

    private func iconTile(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(descriptor.kind.accentColor)
                .shadow(
                    color: descriptor.kind.accentColor.opacity(0.45),
                    radius: 10, x: 0, y: 6
                )
            GameIconView(kind: descriptor.kind, size: size * 0.54)
        }
        .frame(width: size, height: size)
    }
}
