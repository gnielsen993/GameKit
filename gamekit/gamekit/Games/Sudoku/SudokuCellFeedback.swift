//
//  SudokuCellFeedback.swift
//  gamekit
//
//  Per-cell answers to a move (Phase 19.1, sketch 012, DESIGN.md 10.2):
//  the placement pop, the unit/win wave and the wrong-cell shake. Values
//  and keyframe tracks only; SudokuCellView gates them on motion.
//
//  The wave is a counter-triggered KeyframeAnimator per cell (spike A3):
//  the board bumps one shared counter and hands each cell its own step, so
//  a cell holds for `step x stepInterval` and then rises and falls. The step
//  is read when the trigger fires, so clearing the set later never re-fires.
//

import SwiftUI

/// Animated values of one cell's wave: an accent fill and a scale.
struct SudokuWaveValues: Equatable {
    var fill: Double = 0
    var scale: Double = 1
}

enum SudokuCellFeedback {

    // MARK: Placement pop

    static let popStartScale: Double = 0.3
    static let popStartOpacity: Double = 0.2
    /// Slight overshoot, matching sketch 012's .45s spring.
    static let popSpring: Animation = .spring(response: 0.45, dampingFraction: 0.6)

    /// Digits scale in small and faint; erased digits cut (identity removal).
    static var popTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: SudokuPopModifier(scale: popStartScale, opacity: popStartOpacity),
                identity: SudokuPopModifier(scale: 1, opacity: 1)
            ),
            removal: .identity
        )
    }

    // MARK: Wave

    /// Hold for the cell's step, rise to the peak, fall back. A cell that is
    /// not in the wave (`step == nil`) runs the same durations with flat
    /// values: a zero-length timeline made the whole board render blank
    /// when it fired (seen on the first simulator run).
    ///
    /// The leading hold is never zero: a zero-length first keyframe blanked
    /// every cell that had one (the origin cell and all cells outside the
    /// unit) for the first ~200ms of every unit ripple (plan 06 matrix).
    @KeyframesBuilder<SudokuWaveValues>
    static func waveKeyframes(step: Int?) -> some Keyframes<SudokuWaveValues> {
        let live = step != nil
        let hold = waveHold(step: step)
        let rise = SudokuCompletionWave.cellDuration * SudokuCompletionWave.peakFraction
        let fall = SudokuCompletionWave.cellDuration * (1 - SudokuCompletionWave.peakFraction)
        KeyframeTrack(\.fill) {
            LinearKeyframe(0, duration: hold)
            CubicKeyframe(live ? 1 : 0, duration: rise)
            CubicKeyframe(0, duration: fall)
        }
        KeyframeTrack(\.scale) {
            LinearKeyframe(1, duration: hold)
            CubicKeyframe(live ? SudokuCompletionWave.peakScale : 1, duration: rise)
            CubicKeyframe(1, duration: fall)
        }
    }

    /// Seconds a cell holds before its rise: its step times the step
    /// interval, floored at `minimumHold` so no keyframe has zero length.
    static func waveHold(step: Int?) -> Double {
        max(Double(step ?? 0) * SudokuCompletionWave.stepInterval, minimumHold)
    }

    /// One millisecond: invisible as a delay, and not a zero-length keyframe.
    static let minimumHold: Double = 0.001

    // MARK: Wrong-cell shake

    /// Horizontal offsets in points: -4, +4, -3, then rest (sketch 012).
    static let shakeOffsets: [Double] = [-4, 4, -3, 0]
    static let shakeDuration: Double = 0.35

    /// Moves only the cell that is flashing wrong; every other cell runs the
    /// same duration with flat zero values (a zero-length timeline blanked
    /// the board).
    @KeyframesBuilder<Double>
    static func shakeKeyframes(active: Bool) -> some Keyframes<Double> {
        let frame = shakeDuration / Double(shakeOffsets.count)
        KeyframeTrack(\.self) {
            LinearKeyframe(active ? shakeOffsets[0] : 0, duration: frame)
            LinearKeyframe(active ? shakeOffsets[1] : 0, duration: frame)
            LinearKeyframe(active ? shakeOffsets[2] : 0, duration: frame)
            LinearKeyframe(0, duration: frame)
        }
    }
}

/// Transition body: scale and opacity, so the start opacity can be 0.2.
struct SudokuPopModifier: ViewModifier {
    let scale: Double
    let opacity: Double

    func body(content: Content) -> some View {
        content.scaleEffect(scale).opacity(opacity)
    }
}
