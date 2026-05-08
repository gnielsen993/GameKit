//
//  NonogramToolbarMenu.swift
//  gamekit
//
//  Toolbar trailing item — difficulty (size) picker. Mirrors
//  MinesweeperToolbarMenu shape: a Menu with one Button per difficulty,
//  current pick gets a checkmark.
//

import SwiftUI
import DesignKit

struct NonogramToolbarMenu: View {
    let theme: Theme
    let currentDifficulty: NonogramDifficulty
    let onSelect: (NonogramDifficulty) -> Void

    var body: some View {
        Menu {
            ForEach(NonogramDifficulty.allCases, id: \.self) { d in
                Button {
                    onSelect(d)
                } label: {
                    if d == currentDifficulty {
                        Label(displayName(d), systemImage: "checkmark")
                    } else {
                        Text(displayName(d))
                    }
                }
            }
        } label: {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Choose size"))
    }

    private func displayName(_ d: NonogramDifficulty) -> String {
        switch d {
        case .tiny:   return String(localized: "Tiny  -  5 × 5")
        case .small:  return String(localized: "Small  -  10 × 10")
        case .medium: return String(localized: "Medium  -  15 × 15")
        case .large:  return String(localized: "Large  -  20 × 20")
        }
    }
}
