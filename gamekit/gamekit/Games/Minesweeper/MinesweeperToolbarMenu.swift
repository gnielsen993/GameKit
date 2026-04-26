//
//  MinesweeperToolbarMenu.swift
//  gamekit
//
//  Trailing toolbar Menu with Easy / Medium / Hard buttons. Props-only:
//  routes selection through `onSelect` closure — the parent VM (consumed
//  in Plan 04) decides whether to alert mid-game (D-10) before applying.
//
//  Phase 3 invariants (per D-09, D-11, P2 D-03):
//    - View layer owns localized display strings ("Easy"/"Medium"/"Hard");
//      engine layer (P2) carries only mechanical raw values.
//    - Selection writes through `onSelect` — NOT directly to vm.setDifficulty;
//      parent routes via vm.requestDifficultyChange(_:) so the abandon-alert
//      path runs from .playing state (D-10 + RESEARCH Pitfall 4).
//    - Menu trigger glyph = `slider.horizontal.3` (UI-SPEC §Component Inventory).
//    - Trigger label uses theme.typography.headline (17pt semibold) — chosen
//      over .title (22pt) so "Medium" / "Hard" fit toolbar width on iPhone SE.
//

import SwiftUI
import DesignKit

struct MinesweeperToolbarMenu: View {
    let theme: Theme
    let currentDifficulty: MinesweeperDifficulty
    let onSelect: (MinesweeperDifficulty) -> Void

    var body: some View {
        Menu {
            ForEach(MinesweeperDifficulty.allCases, id: \.self) { difficulty in
                Button {
                    onSelect(difficulty)
                } label: {
                    if currentDifficulty == difficulty {
                        Label(displayName(for: difficulty), systemImage: "checkmark")
                    } else {
                        Text(displayName(for: difficulty))
                    }
                }
            }
        } label: {
            HStack(spacing: theme.spacing.xs) {
                Text(displayName(for: currentDifficulty))
                    .font(theme.typography.headline)
                Image(systemName: "slider.horizontal.3")
            }
            .foregroundStyle(theme.colors.textPrimary)
        }
        .accessibilityLabel(Text("Difficulty"))
        .accessibilityValue(Text(displayName(for: currentDifficulty)))
    }

    // MARK: - Display name mapping (engine D-03 — view layer owns localization)

    private func displayName(for d: MinesweeperDifficulty) -> String {
        switch d {
        case .easy:   return String(localized: "Easy")
        case .medium: return String(localized: "Medium")
        case .hard:   return String(localized: "Hard")
        }
    }
}
