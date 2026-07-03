//
//  NonogramModePill.swift
//  gamekit
//
//  Two-segment pill for place / mark interaction mode. Mirrors
//  MinesweeperModePill exactly (typography, padding, min-height, capsule
//  fill semantics) so the bottom picker reads the same across games.
//  Compact-variant API added per Plan 12-04 / CONTEXT D-12-CHIPS (mirror
//  of P11-04 round 2 polish + Plan 12-02 MergeModePill polish).
//

import SwiftUI
import DesignKit

struct NonogramModePill: View {
    let theme: Theme
    let mode: NonogramInteractionMode
    let isInteractive: Bool
    let onSelect: (NonogramInteractionMode) -> Void
    /// Compact variant for Video Mode slot 3 (P12 D-12-CHIPS). When `true`,
    /// drops one Dynamic Type step (body instead of headline), reduces
    /// horizontal segment padding (s instead of l), and constrains Text via
    /// `.lineLimit(1)` + `.minimumScaleFactor(0.7)` so both "Place" + "Mark"
    /// labels survive without truncating in the narrow center-anchored slot.
    /// Off-path callers (NonogramGameView existingLayout) leave defaulted to
    /// `false` and get the v1.1 pill byte-identical (D-12-OFFRESTORE).
    var compact: Bool = false

    /// Namespace for the sliding active-segment thumb (DESIGN.md §10.2 —
    /// hard-cuts to instant when animations are gated off).
    @Namespace private var pillNamespace

    var body: some View {
        Button {
            guard isInteractive else { return }
            onSelect(toggledMode)
        } label: {
            HStack(spacing: 0) {
                segment(.place,
                        glyph: "square.fill",
                        label: String(localized: "Place"))
                segment(.mark,
                        glyph: "xmark",
                        label: String(localized: "Mark"))
            }
            .feedbackAnimation(.spring(response: 0.3, dampingFraction: 0.82), value: mode)
            .padding(theme.spacing.xs)
            .background(
                Capsule().fill(theme.colors.surface)
            )
            .overlay(
                Capsule().stroke(theme.colors.border, lineWidth: 1)
            )
            .chipShadow()
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .accessibilityLabel(Text(String(localized: "Toggle mode")))
        .accessibilityValue(Text(mode == .place ? String(localized: "Place") : String(localized: "Mark")))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func segment(_ target: NonogramInteractionMode,
                         glyph: String,
                         label: String) -> some View {
        let isActive = mode == target
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
        .background {
            if isActive {
                Capsule()
                    .fill(target == .mark ? theme.colors.danger : theme.colors.accentPrimary)
                    .matchedGeometryEffect(id: "activeSegment", in: pillNamespace)
            }
        }
    }

    private var toggledMode: NonogramInteractionMode {
        mode == .place ? .mark : .place
    }
}
