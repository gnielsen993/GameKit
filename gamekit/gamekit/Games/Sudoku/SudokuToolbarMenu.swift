//
//  SudokuToolbarMenu.swift
//  gamekit
//
//  Toolbar trailing menu — difficulty picker + game-mode picker.
//  Mirrors NonogramToolbarMenu shape: a Menu with sectioned content,
//  current pick gets a checkmark.
//

import SwiftUI
import DesignKit

struct SudokuToolbarMenu: View {
    let theme: Theme
    let currentDifficulty: SudokuDifficulty
    let currentGameMode: SudokuGameMode
    let onSelectDifficulty: (SudokuDifficulty) -> Void
    let onSelectGameMode: (SudokuGameMode) -> Void

    var body: some View {
        Menu {
            Section(String(localized: "Mode")) {
                ForEach(SudokuGameMode.allCases, id: \.self) { mode in
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

            Section(String(localized: "Difficulty")) {
                ForEach(SudokuDifficulty.allCases, id: \.self) { d in
                    Button {
                        onSelectDifficulty(d)
                    } label: {
                        if d == currentDifficulty {
                            Label(d.displayName, systemImage: "checkmark")
                        } else {
                            Text(d.displayName)
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

    private func modeDisplayName(_ m: SudokuGameMode) -> String {
        switch m {
        case .free:  return String(localized: "Free")
        case .lives: return String(localized: "Lives  -  3 strikes")
        }
    }
}
