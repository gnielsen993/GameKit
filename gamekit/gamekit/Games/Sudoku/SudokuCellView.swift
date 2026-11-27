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
    /// True while this cell belongs to a just-completed row, column, or box.
    var isGlowing: Bool = false
    /// True when this cell holds a user digit that disagrees with the
    /// solution. Free mode only — Lives mode never commits a wrong value.
    var isIncorrect: Bool = false
    /// The square the active hint names — ringed in accent.
    var isHintTarget: Bool = false
    /// A square carrying the hint's argument — softly shaded.
    var isHintSupporting: Bool = false
    var row: Int = 0
    var column: Int = 0
    /// This cell's step in the running unit or win wave, nil when it is not
    /// part of one. Read when `waveCount` changes (spike A3).
    var waveStep: Int? = nil
    /// Shared monotonic trigger: a change starts every cell's wave.
    var waveCount: Int = 0
    /// Bumped on each wrong attempt; the flashing cell shakes.
    var shakeCount: Int = 0
    /// Animations setting on and Reduce Motion off (MotionGate idiom). When
    /// false nothing pops, ripples or shakes; a completed unit shows a
    /// static glow instead and a wrong move still flashes.
    var motion: Bool = true

    enum HighlightTier: Equatable {
        case none                  // no overlay
        case peer                  // ~6% accent
        case sameNumber            // ~10% accent
        case selected              // ~18% accent
    }

    var body: some View {
        KeyframeAnimator(
            initialValue: SudokuWaveValues(),
            trigger: motion ? waveCount : 0
        ) { values in
            cellBody(values)
        } keyframes: { _ in
            SudokuCellFeedback.waveKeyframes(step: waveStep)
        }
        .keyframeAnimator(
            initialValue: 0.0,
            trigger: motion ? shakeCount : 0
        ) { view, dx in
            view.offset(x: dx)
        } keyframes: { _ in
            SudokuCellFeedback.shakeKeyframes(active: isWrongFlashing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText + Text(", row \(row + 1), column \(column + 1)"))
        .accessibilityValue(isHintTarget ? Text("Hint target") : isHintSupporting ? Text("Hint evidence") : Text(""))
    }

    private func cellBody(_ values: SudokuWaveValues) -> some View {
        ZStack {
            background
            staticGlow
            Rectangle()
                .fill(theme.colors.accentPrimary.opacity(values.fill))
                .allowsHitTesting(false)
            content(onAccent: values.fill > 0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(hintOverlay)
        .overlay(wrongFlashOverlay)
        .scaleEffect(values.scale)
        .feedbackAnimation(SudokuCellFeedback.popSpring, value: cell)
        .contentShape(Rectangle())
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

    /// Ring on the named square, wash on the squares that prove it.
    @ViewBuilder
    private var hintOverlay: some View {
        if isHintTarget {
            Rectangle()
                .stroke(theme.colors.accentPrimary, lineWidth: 2)
                .allowsHitTesting(false)
        } else if isHintSupporting {
            Rectangle()
                .fill(theme.colors.accentPrimary.opacity(0.12))
                .allowsHitTesting(false)
        }
    }

    /// Motion off: a completed unit still registers as a quiet accent glow
    /// with no animation (DESIGN 10.4). With motion on, the wave replaces it.
    @ViewBuilder
    private var staticGlow: some View {
        if !motion && isGlowing {
            Rectangle()
                .fill(theme.colors.accentPrimary.opacity(0.22))
                .allowsHitTesting(false)
        }
    }

    /// `onAccent` flips the digit to the background colour at the wave's peak
    /// so it stays legible on the accent fill (sketch 012).
    @ViewBuilder
    private func content(onAccent: Bool) -> some View {
        switch cell {
        case .given(let v):
            Text("\(v)")
                .font(theme.typography.title.weight(.bold))
                .foregroundStyle(onAccent ? theme.colors.background : theme.colors.textPrimary)
        case .user(let v):
            Text("\(v)")
                .font(theme.typography.title.weight(.regular))
                // danger = errors per DESIGN.md §2; accent = the player's own
                // correct choices.
                .foregroundStyle(onAccent
                    ? theme.colors.background
                    : isIncorrect ? theme.colors.danger : theme.colors.accentPrimary)
                // Placed digits pop in small and faint with a slight
                // overshoot (gated via feedbackAnimation on the cell
                // container); erased/replaced digits cut instantly.
                .transition(SudokuCellFeedback.popTransition)
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
            ZStack {
                Rectangle()
                    .fill(theme.colors.danger.opacity(0.24))
                Rectangle()
                    .inset(by: 1)
                    .stroke(theme.colors.danger, lineWidth: 2)
            }
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    private var accessibilityText: Text {
        switch cell {
        case .given(let v): return Text("Given \(v)")
        // Colour alone must not carry the information (DESIGN.md a11y).
        case .user(let v):  return isIncorrect ? Text("\(v), incorrect") : Text("\(v)")
        case .empty(let notes):
            if notes.isEmpty { return Text("Empty") }
            return Text("Notes: \(notes.sorted().map(String.init).joined(separator: ", "))")
        }
    }
}
