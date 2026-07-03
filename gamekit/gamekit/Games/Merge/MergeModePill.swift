//
//  MergeModePill.swift
//  gamekit
//
//  Two-segment pill flipper for winMode / infinite. Props-only. Mirrors
//  MinesweeperModePill at MinesweeperModePill.swift:12 in structure +
//  compact-variant API (P11-04 round 2 polish 2026-05-13; carried to P12
//  per CONTEXT D-12-CHIPS).
//

import SwiftUI
import DesignKit

struct MergeModePill: View {
    let theme: Theme
    let mode: MergeMode
    let onSelect: (MergeMode) -> Void
    /// Compact variant for Video Mode slot 3 (P12 D-12-CHIPS mirror of
    /// MinesweeperModePill compact API). When `true`, drops one Dynamic
    /// Type step (body instead of headline), reduces horizontal segment
    /// padding (s instead of l), and constrains Text via `.lineLimit(1)`
    /// + `.minimumScaleFactor(0.7)` so both "Win" + "Infinite" labels
    /// survive without truncating in the narrow center-anchored slot.
    /// Off-path callers (existingLayout) leave this defaulted to `false`
    /// and get the v1.1 pill byte-identical (D-12-OFFRESTORE).
    var compact: Bool = false

    /// Namespace for the sliding active-segment thumb (DESIGN.md §10.2 —
    /// hard-cuts to instant when animations are gated off).
    @Namespace private var pillNamespace

    var body: some View {
        Button {
            onSelect(toggledMode)
        } label: {
            HStack(spacing: 0) {
                segment(.winMode,
                        glyph: "trophy.fill",
                        label: String(localized: "Win"))
                segment(.infinite,
                        glyph: "infinity",
                        label: String(localized: "Infinite"))
            }
            .feedbackAnimation(.spring(response: 0.3, dampingFraction: 0.82), value: mode)
            .padding(theme.spacing.xs)
            .background(Capsule().fill(theme.colors.surface))
            .overlay(Capsule().stroke(theme.colors.border, lineWidth: 1))
            .chipShadow()
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "Toggle mode")))
        .accessibilityValue(Text(mode == .winMode ? String(localized: "Win") : String(localized: "Infinite")))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func segment(_ target: MergeMode, glyph: String, label: String) -> some View {
        let isActive = mode == target
        HStack(spacing: theme.spacing.xs) {
            Image(systemName: glyph)
                .font(.system(size: compact ? 13 : 16, weight: .semibold))
            Text(label)
                .font(compact ? theme.typography.body : theme.typography.headline)
                .lineLimit(1)
                .minimumScaleFactor(compact ? 0.7 : 1.0)
        }
        .foregroundStyle(isActive ? theme.colors.background : theme.colors.textPrimary)
        .padding(.horizontal, compact ? theme.spacing.s : theme.spacing.l)
        .padding(.vertical, compact ? theme.spacing.xs : theme.spacing.s)
        .frame(minHeight: compact ? theme.spacing.l : 44)
        .background {
            if isActive {
                Capsule()
                    .fill(theme.colors.accentPrimary)
                    .matchedGeometryEffect(id: "activeSegment", in: pillNamespace)
            }
        }
    }

    private var toggledMode: MergeMode {
        mode == .winMode ? .infinite : .winMode
    }
}
