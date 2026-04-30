//
//  MergeToolbarMenu.swift
//  gamekit
//
//  Trailing toolbar Menu for Merge — pick mode (winMode / infinite).
//  Props-only. Mirrors MinesweeperToolbarMenu in spirit.
//

import SwiftUI
import DesignKit

struct MergeToolbarMenu: View {
    let theme: Theme
    let currentMode: MergeMode
    let onSelect: (MergeMode) -> Void

    var body: some View {
        Menu {
            ForEach(MergeMode.allCases, id: \.self) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    if mode == currentMode {
                        Label(displayName(for: mode), systemImage: "checkmark")
                    } else {
                        Text(displayName(for: mode))
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
        .accessibilityLabel(Text("Mode"))
    }

    private func displayName(for mode: MergeMode) -> String {
        switch mode {
        case .winMode:  return String(localized: "Win mode (stop at 2048)")
        case .infinite: return String(localized: "Infinite mode")
        }
    }
}
