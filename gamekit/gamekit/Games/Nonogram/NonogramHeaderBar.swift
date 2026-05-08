//
//  NonogramHeaderBar.swift
//  gamekit
//
//  Title strip above the board. Shows the current puzzle's name + a
//  position counter ("3 / 12") flanked by left/right chevrons that drive
//  gallery navigation.
//
//  Props-only; the parent owns the VM and feeds in title + label +
//  enabled state for the chevrons. Cross-game shape mirrors
//  MinesweeperHeaderBar (theme + readouts only, no logic).
//

import SwiftUI
import DesignKit

struct NonogramHeaderBar: View {
    let theme: Theme
    let title: String
    let positionLabel: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            chevronButton(systemName: "chevron.left", action: onPrevious)
                .accessibilityLabel(Text("Previous puzzle"))

            VStack(spacing: theme.spacing.xs) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary)
                Text(positionLabel)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            chevronButton(systemName: "chevron.right", action: onNext)
                .accessibilityLabel(Text("Next puzzle"))
        }
        .padding(.horizontal, theme.spacing.m)
    }

    private func chevronButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
