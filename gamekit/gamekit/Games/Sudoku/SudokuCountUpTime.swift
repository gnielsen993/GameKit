//
//  SudokuCountUpTime.swift
//  gamekit
//
//  The win card's large time. With motion it counts from 0 to the final time
//  (SudokuWinTime easing); with animations off or Reduce Motion it shows the
//  final time at once (D-10). A hidden copy of the final string fixes the
//  layout so the card never resizes while counting. VoiceOver always hears
//  the final time, never a number in flight.
//

import SwiftUI
import DesignKit

struct SudokuCountUpTime: View {
    let seconds: TimeInterval
    let theme: Theme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.settingsStore) private var settingsStore

    @State private var startDate = Date()
    @State private var finished = false

    private var motion: Bool { settingsStore.animationsEnabled && !reduceMotion }
    private var finalText: String { SudokuWinTime.string(seconds) }

    var body: some View {
        timeText(finalText)
            .hidden()
            .overlay { visible }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(finalText))
            .accessibilityIdentifier("sudoku.endCard.time")
    }

    @ViewBuilder
    private var visible: some View {
        if motion && !finished {
            TimelineView(.animation(minimumInterval: nil, paused: finished)) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                timeText(SudokuWinTime.string(
                    SudokuWinTime.countUpSeconds(target: seconds, elapsedSinceStart: elapsed)
                ))
            }
            .task {
                startDate = Date()
                try? await Task.sleep(for: .seconds(SudokuWinTime.countUpDelay + SudokuWinTime.countUpDuration))
                finished = true
            }
        } else {
            timeText(finalText)
        }
    }

    private func timeText(_ text: String) -> some View {
        Text(text)
            .font(RoundedType.winTime)
            .monospacedDigit()
            .foregroundStyle(theme.colors.accentPrimary)
    }
}
