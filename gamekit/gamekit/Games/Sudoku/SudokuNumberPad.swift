//
//  SudokuNumberPad.swift
//  gamekit
//
//  9-digit number pad. Each digit shows a remaining-count badge
//  (9 minus how many times that digit is already placed). When a digit's
//  remaining count reaches 0, the button greys out and disables.
//
//  Erase lives in SudokuGameView alongside the mode pill so the 9 digits
//  span the full pad width without an off-center 10th button.
//

import SwiftUI
import DesignKit

struct SudokuNumberPad: View {
    let viewModel: SudokuViewModel
    let theme: Theme
    @State private var pulsing: Set<Int> = []

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(1...9, id: \.self) { digit in
                digitButton(digit)
            }
        }
        .padding(.horizontal, theme.spacing.m)
        .onChange(of: viewModel.justCompletedDigit) { _, newDigit in
            guard let d = newDigit else { return }
            pulsing.insert(d)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                pulsing.remove(d)
            }
        }
    }

    private func digitButton(_ digit: Int) -> some View {
        let remaining = viewModel.remainingPerDigit[digit] ?? 0
        let isExhausted = remaining == 0
        let isSelected = viewModel.selectedCell?.value == digit
        return Button {
            viewModel.place(value: digit)
        } label: {
            VStack(spacing: 2) {
                Text("\(digit)")
                    .font(theme.typography.title.weight(.semibold))
                    .foregroundStyle(isExhausted
                        ? theme.colors.textSecondary
                        : isSelected
                            ? theme.colors.background
                            : theme.colors.textPrimary)
                Text(isExhausted ? " " : "\(remaining)")
                    .font(theme.typography.caption)
                    .foregroundStyle(isSelected
                        ? theme.colors.background.opacity(0.8)
                        : theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing.s)
            .background(
                RoundedRectangle(cornerRadius: theme.radii.chip)
                    .fill(isSelected ? theme.colors.accentPrimary : theme.colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.chip)
                    .stroke(theme.colors.border, lineWidth: 1)
            )
            .chipShadow()
            .overlay {
                if isExhausted {
                    GeometryReader { g in
                        Path { p in
                            p.move(to: CGPoint(x: g.size.width * 0.18, y: g.size.height * 0.18))
                            p.addLine(to: CGPoint(x: g.size.width * 0.82, y: g.size.height * 0.82))
                        }
                        .stroke(
                            theme.colors.textSecondary.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip))
                    .allowsHitTesting(false)
                }
            }
        }
        .scaleEffect(pulsing.contains(digit) ? 1.12 : 1.0)
        .feedbackAnimation(
            .spring(response: 0.25, dampingFraction: 0.5),
            value: pulsing.contains(digit)
        )
        .feedbackAnimation(theme.motion.ease, value: isSelected)
        .buttonStyle(.pressable)
        .disabled(isExhausted)
        .accessibilityLabel("Place \(digit), \(remaining) remaining")
    }
}
