//
//  SudokuModePill.swift
//  gamekit
//
//  Two-segment pill toggling SudokuInteractionMode between .value and .note.
//  Mirrors NonogramModePill's shape 1:1: Capsule fill, xs padding wrapper,
//  per-segment active highlight (accentPrimary), min-height 44pt off-path.
//
//  Labels:
//    - .value → "Value" (pencil off — committing digits)
//    - .note  → "Notes" (pencil on — adding pencil marks)
//
//  Compact variant for Video Mode slot 3 (mirrors NonogramModePill.compact).
//

import SwiftUI
import DesignKit

struct SudokuModePill: View {
    let theme: Theme
    let mode: SudokuInteractionMode
    let isInteractive: Bool
    let onSelect: (SudokuInteractionMode) -> Void
    /// Compact variant for Video Mode slot 3. Reduces font, padding, min-height.
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
                segment(.value,
                        glyph: "pencil.slash",
                        label: String(localized: "Value"))
                segment(.note,
                        glyph: "pencil",
                        label: String(localized: "Notes"))
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
        .accessibilityValue(Text(mode == .value ? String(localized: "Value") : String(localized: "Notes")))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func segment(_ target: SudokuInteractionMode,
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
                    .fill(theme.colors.accentPrimary)
                    .matchedGeometryEffect(id: "activeSegment", in: pillNamespace)
            }
        }
    }

    private var toggledMode: SudokuInteractionMode {
        mode == .value ? .note : .value
    }
}
