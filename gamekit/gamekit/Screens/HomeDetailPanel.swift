import SwiftUI
import DesignKit

struct HomeDetailPanel: View {
    let descriptor: GameDescriptor
    let theme: Theme
    var onSelect: (GameRoute) -> Void
    var onStats: () -> Void

    @State private var selectedModeId: String

    init(descriptor: GameDescriptor, theme: Theme,
         onSelect: @escaping (GameRoute) -> Void,
         onStats: @escaping () -> Void) {
        self.descriptor = descriptor
        self.theme = theme
        self.onSelect = onSelect
        self.onStats = onStats
        _selectedModeId = State(initialValue: descriptor.modes.first?.id ?? "")
    }

    private var hasParentChips: Bool { descriptor.modes.first?.route == nil }

    private var selectedParent: GameModeChip? {
        descriptor.modes.first(where: { $0.id == selectedModeId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, theme.spacing.m)
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

    // MARK: - Mode section

    @ViewBuilder
    private var modeSection: some View {
        if hasParentChips {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                sectionLabel("MODE")
                modePillRow
                sectionLabel("DIFFICULTY")
                    .padding(.top, theme.spacing.xs)
                if let parent = selectedParent {
                    difficultyGrid(parent.subModes)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                sectionLabel("MODE / DIFFICULTY")
                leafGrid(descriptor.modes)
            }
        }
    }

    // MARK: - Mode pill row

    private var modePillRow: some View {
        HStack(spacing: theme.spacing.s) {
            ForEach(descriptor.modes) { chip in modePill(chip) }
        }
    }

    private func modePill(_ chip: GameModeChip) -> some View {
        let selected = chip.id == selectedModeId
        return Button { selectedModeId = chip.id } label: {
            Text(String(localized: "\(chip.labelKey)"))
                .font(theme.typography.body.weight(.semibold))
                .foregroundStyle(selected ? .white : theme.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                        .fill(selected ? descriptor.kind.accentColor : theme.colors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                                .stroke(
                                    selected ? descriptor.kind.accentColor : theme.colors.border.opacity(0.6),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Difficulty grid

    private func difficultyGrid(_ chips: [GameModeChip]) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: theme.spacing.s) {
            ForEach(chips) { chip in
                if let route = chip.route {
                    Button { onSelect(route) } label: { chipLabel(chip) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func leafGrid(_ chips: [GameModeChip]) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: theme.spacing.s) {
            ForEach(chips) { chip in
                if let route = chip.route {
                    Button { onSelect(route) } label: { chipLabel(chip) }
                        .buttonStyle(.plain)
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
        .padding(.vertical, theme.spacing.s)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .fill(theme.colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                        .stroke(theme.colors.border.opacity(0.6), lineWidth: 1)
                )
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(theme.colors.textSecondary)
            .kerning(1.4)
    }

    private var statsLink: some View {
        Button(action: onStats) {
            HStack(spacing: theme.spacing.xs) {
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

    private func iconTile(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(descriptor.kind.accentColor)
                .shadow(color: descriptor.kind.accentColor.opacity(0.45), radius: 10, x: 0, y: 6)
            GameIconView(kind: descriptor.kind, size: size * 0.54)
        }
        .frame(width: size, height: size)
    }
}
