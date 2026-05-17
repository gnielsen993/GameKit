//
//  SudokuNumberPad.swift
//  gamekit
//
//  9-digit number pad + erase button. Each digit shows a remaining-count
//  badge (9 minus the number of times that digit is already placed on
//  the board). When a digit's remaining count is 0, the button greys
//  out and disables.
//
//  Token note: plan referenced `theme.colors.accent` which does not exist;
//  using `theme.colors.accentPrimary` (the correct token name per ThemeColors).
//

import SwiftUI
import DesignKit

struct SudokuNumberPad: View {
    @Bindable var viewModel: SudokuViewModel
    let theme: Theme

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(1...9, id: \.self) { digit in
                digitButton(digit)
            }
            eraseButton
        }
        .padding(.horizontal, theme.spacing.m)
    }

    private func digitButton(_ digit: Int) -> some View {
        let remaining = viewModel.remainingPerDigit[digit] ?? 0
        let isExhausted = remaining == 0
        return Button {
            viewModel.place(value: digit)
        } label: {
            VStack(spacing: 2) {
                Text("\(digit)")
                    .font(theme.typography.title.weight(.semibold))
                    .foregroundStyle(isExhausted
                        ? theme.colors.textSecondary
                        : theme.colors.textPrimary)
                Text("\(remaining)")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing.s)
            .background(
                RoundedRectangle(cornerRadius: theme.radii.chip)
                    .fill(theme.colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.chip)
                    .stroke(theme.colors.border, lineWidth: 1)
            )
        }
        .disabled(isExhausted)
        .accessibilityLabel("Place \(digit), \(remaining) remaining")
    }

    private var eraseButton: some View {
        Button {
            viewModel.erase()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 20))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: theme.radii.chip)
                        .fill(theme.colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.chip)
                        .stroke(theme.colors.border, lineWidth: 1)
                )
        }
        .accessibilityLabel("Erase")
    }
}
