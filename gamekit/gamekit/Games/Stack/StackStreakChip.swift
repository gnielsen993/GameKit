//
//  StackStreakChip.swift
//  gamekit
//
//  Props-only perfect-streak chip for Stack's Video Mode compact row
//  (slot 4, compact: true — rendered only while streak > 0, matching the
//  off-path overlay's conditional streak line). §3.3 generic-info-chip
//  shell; value tinted accentPrimary to mirror the off-path streak text
//  (streak is earned player momentum — accent, not danger, per DESIGN §2).
//

import SwiftUI
import DesignKit

struct StackStreakChip: View {
    let theme: Theme
    let streak: Int
    /// Compact variant for the Video Mode compact row (§3.5).
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Streak").uppercased())
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)
            Text("\(streak)")
                .font(compact ? theme.typography.caption : theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.accentPrimary)
        }
        .padding(.horizontal, compact ? theme.spacing.xs : theme.spacing.m)
        .padding(.vertical, compact ? theme.spacing.xs : theme.spacing.s)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Perfect streak \(streak)"))
    }
}
