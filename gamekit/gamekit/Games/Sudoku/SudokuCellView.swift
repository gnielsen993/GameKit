//
//  SudokuCellView.swift
//  gamekit
//
//  Single cell renderer. Pure-presentation — takes a SudokuCell + a
//  HighlightTier + an isWrongFlashing flag and renders accordingly.
//  No interaction logic; SudokuBoardView handles taps and feeds back
//  the selected/peer state via props.
//
//  Token note: plan referenced `theme.colors.accent` which does not exist;
//  using `theme.colors.accentPrimary` (the correct token name per ThemeColors).
//

import SwiftUI
import DesignKit

struct SudokuCellView: View {
    let cell: SudokuCell
    let highlight: HighlightTier
    let isWrongFlashing: Bool
    let theme: Theme
    /// When non-nil, notes cells render this digit in accentPrimary to pop.
    var noteHighlightDigit: Int? = nil

    enum HighlightTier: Equatable {
        case none                  // no overlay
        case peer                  // ~6% accent
        case sameNumber            // ~10% accent
        case selected              // ~18% accent
    }

    var body: some View {
        ZStack {
            background
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(wrongFlashOverlay)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var background: some View {
        let opacity: Double = {
            switch highlight {
            case .none:       return 0
            case .peer:       return 0.06
            case .sameNumber: return 0.10
            case .selected:   return 0.18
            }
        }()
        return Rectangle().fill(theme.colors.accentPrimary.opacity(opacity))
    }

    @ViewBuilder
    private var content: some View {
        switch cell {
        case .given(let v):
            Text("\(v)")
                .font(theme.typography.title.weight(.bold))
                .foregroundStyle(theme.colors.textPrimary)
        case .user(let v):
            Text("\(v)")
                .font(theme.typography.title.weight(.regular))
                .foregroundStyle(theme.colors.accentPrimary)
        case .empty(let notes):
            if notes.isEmpty {
                Color.clear
            } else {
                notesGrid(notes)
            }
        }
    }

    private func notesGrid(_ notes: Set<Int>) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let digit = r * 3 + c + 1
                        let isHighlighted = notes.contains(digit) && noteHighlightDigit == digit
                        Text(notes.contains(digit) ? "\(digit)" : " ")
                            .font(theme.typography.caption)
                            .foregroundStyle(isHighlighted
                                ? theme.colors.accentPrimary
                                : theme.colors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var wrongFlashOverlay: some View {
        if isWrongFlashing {
            Rectangle()
                .fill(theme.colors.danger.opacity(0.30))
                .transition(.opacity)
        }
    }

    private var accessibilityText: Text {
        switch cell {
        case .given(let v): return Text("Given \(v)")
        case .user(let v):  return Text("\(v)")
        case .empty(let notes):
            if notes.isEmpty { return Text("Empty") }
            return Text("Notes: \(notes.sorted().map(String.init).joined(separator: ", "))")
        }
    }
}
