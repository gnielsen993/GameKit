//
//  NonogramCellView.swift
//  gamekit
//
//  Single Nonogram cell. Renders one of three states:
//    - .filled : solid accent fill (the picture pixel)
//    - .marked : a small X glyph, hidden during gallery review
//    - .empty  : surface fill (background)
//
//  Props-only — receives state, theme, size; routes taps via closure.
//  No DesignKit token reads beyond `theme` per CLAUDE §1 + Pattern 5.
//

import SwiftUI
import DesignKit

struct NonogramCellView: View {
    let state: NonogramCellState
    let cellSize: CGFloat
    let theme: Theme
    let isInteractive: Bool
    /// True when this cell is the most-recent wrong-tap in Lives mode.
    /// Drives a brief red flash + horizontal jitter for clear feedback.
    let wrongFlash: Bool
    /// True when this cell sits in a row OR column that just completed
    /// — drives a brief accent-tint pulse so the player can feel the
    /// completion across the whole line, not just at the touched cell.
    let completionFlash: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundFill)
            glyph
            if completionFlash {
                Rectangle()
                    .fill(theme.colors.accentPrimary.opacity(0.40))
                    .transition(.opacity)
            }
            if wrongFlash {
                Rectangle()
                    .fill(theme.colors.danger.opacity(0.55))
                    .transition(.opacity)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(
            Rectangle()
                .stroke(theme.colors.textPrimary.opacity(0.18), lineWidth: 0.5)
        )
        .offset(x: wrongFlash ? 3 : 0)
        .animation(.spring(response: 0.18, dampingFraction: 0.35), value: wrongFlash)
        .animation(.easeOut(duration: 0.35), value: completionFlash)
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.25)
                .exclusively(before: TapGesture())
                .onEnded { result in
                    guard isInteractive else { return }
                    switch result {
                    case .first:  onLongPress()
                    case .second: onTap()
                    }
                }
        )
    }

    @ViewBuilder
    private var glyph: some View {
        switch state {
        case .marked:
            Image(systemName: "xmark")
                .resizable().scaledToFit()
                .frame(width: cellSize * 0.55, height: cellSize * 0.55)
                .foregroundStyle(theme.colors.textPrimary.opacity(0.55))
        case .filled, .empty:
            EmptyView()
        }
    }

    private var backgroundFill: Color {
        switch state {
        case .filled: return theme.colors.accentPrimary
        case .marked, .empty: return theme.colors.surface
        }
    }

}
