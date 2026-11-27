//
//  SudokuEraseButton.swift
//  gamekit
//
//  Erase as a piece (DESIGN.md §3.8). One implementation for the pill row
//  (regular circle) and the Video Mode large-zone control row (compact
//  rounded square). Props only; the parent owns the action.
//

import SwiftUI
import DesignKit

struct SudokuEraseButton: View {
    let theme: Theme
    let isInteractive: Bool
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "delete.left")
                .font(.system(size: 16, weight: compact ? .semibold : .medium))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(
                    width: compact ? theme.spacing.xl : 36,
                    height: compact ? theme.spacing.xl : 36
                )
        }
        .buttonStyle(.piece(
            theme: theme,
            shape: compact ? .rounded(theme.radii.button) : .circle,
            size: compact ? .compact : .regular
        ))
        .disabled(!isInteractive)
        .opacity(isInteractive ? 1 : 0.4)
        .accessibilityLabel(Text("Erase"))
    }
}
