//
//  NonogramToolbarMenu.swift
//  gamekit
//
//  Toolbar trailing menu — size picker + game-mode picker (Free / Lives).
//  Mirrors MinesweeperToolbarMenu shape: a Menu with sectioned content,
//  current pick gets a checkmark.
//

import SwiftUI
import DesignKit

struct NonogramToolbarMenu: View {
    let theme: Theme
    let currentDifficulty: NonogramDifficulty
    let currentGameMode: NonogramGameMode
    let onSelectDifficulty: (NonogramDifficulty) -> Void
    let onSelectGameMode: (NonogramGameMode) -> Void

    var body: some View {
        Menu {
            Section(String(localized: "Mode")) {
                ForEach(NonogramGameMode.allCases, id: \.self) { mode in
                    Button {
                        onSelectGameMode(mode)
                    } label: {
                        if mode == currentGameMode {
                            Label(modeDisplayName(mode), systemImage: "checkmark")
                        } else {
                            Text(modeDisplayName(mode))
                        }
                    }
                }
            }

            Section(String(localized: "Size")) {
                ForEach(NonogramDifficulty.allCases, id: \.self) { d in
                    Button {
                        onSelectDifficulty(d)
                    } label: {
                        if d == currentDifficulty {
                            Label(difficultyDisplayName(d), systemImage: "checkmark")
                        } else {
                            Text(difficultyDisplayName(d))
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Game settings"))
    }

    private func difficultyDisplayName(_ d: NonogramDifficulty) -> String {
        switch d {
        case .tiny:   return String(localized: "Tiny  -  5 × 5")
        case .small:  return String(localized: "Small  -  10 × 10")
        case .medium: return String(localized: "Medium  -  15 × 15")
        case .large:  return String(localized: "Large  -  20 × 20")
        }
    }

    private func modeDisplayName(_ m: NonogramGameMode) -> String {
        switch m {
        case .free:  return String(localized: "Free")
        case .lives: return String(localized: "Lives  -  3 strikes")
        }
    }
}
