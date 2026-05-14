//
//  MinesweeperModePill.swift
//  gamekit
//
//  Two-segment pill flipper for Reveal / Flag interaction mode.
//  Props-only (CLAUDE.md §8.2): receives current mode + onSelect closure.
//

import SwiftUI
import DesignKit

struct MinesweeperModePill: View {
    let theme: Theme
    let mode: MinesweeperInteractionMode
    let onSelect: (MinesweeperInteractionMode) -> Void
    /// Compact variant for Video Mode slot 3 (P11 11-04 user-feedback polish
    /// 2026-05-13). When `true`, the pill drops one Dynamic Type step (body
    /// instead of headline), reduces horizontal segment padding (s instead
    /// of l), and constrains Text via `.lineLimit(1)` + `.minimumScaleFactor(0.7)`
    /// so both "Reveal" + "Flag" labels survive without truncating to single
    /// chars ("I" / "F") the way they did at native size in the compact row.
    /// Off-path callers (existingLayout) leave this defaulted to `false` and
    /// get the v1.0 pill byte-identical.
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            segment(.reveal,
                    glyph: "cursorarrow.click",
                    label: String(localized: "Reveal"))
            segment(.flag,
                    glyph: "flag.fill",
                    label: String(localized: "Flag"))
        }
        .padding(theme.spacing.xs)
        .background(
            Capsule().fill(theme.colors.surface)
        )
        .overlay(
            Capsule().stroke(theme.colors.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segment(_ target: MinesweeperInteractionMode,
                         glyph: String,
                         label: String) -> some View {
        let isActive = mode == target
        Button {
            onSelect(target)
        } label: {
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: glyph)
                    .font(.system(size: compact ? 13 : 16, weight: .semibold))
                Text(label)
                    .font(compact ? theme.typography.body : theme.typography.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(compact ? 0.7 : 1.0)
            }
            .foregroundStyle(isActive
                             ? theme.colors.background
                             : theme.colors.textPrimary)
            .padding(.horizontal, compact ? theme.spacing.s : theme.spacing.l)
            .padding(.vertical, compact ? theme.spacing.xs : theme.spacing.s)
            .frame(minHeight: compact ? theme.spacing.l : 44)
            .background(
                Capsule().fill(
                    isActive
                    ? (target == .flag ? theme.colors.danger : theme.colors.accentPrimary)
                    : Color.clear
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}
