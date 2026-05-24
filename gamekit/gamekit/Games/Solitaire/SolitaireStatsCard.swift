import SwiftUI
import DesignKit

struct SolitaireStatsCard: View {
    let records:   [GameRecord]
    let bestTimes: [BestTime]

    var body: some View {
        if records.isEmpty {
            Text("No Solitaire games played yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 12) {
                ForEach(SolitaireDifficulty.allCases, id: \.self) { d in
                    SolitaireDifficultyRow(difficulty: d,
                                          records: records,
                                          bestTimes: bestTimes)
                }
            }
        }
    }
}

private struct SolitaireDifficultyRow: View {
    let difficulty: SolitaireDifficulty
    let records:   [GameRecord]
    let bestTimes: [BestTime]

    private var cohort: [GameRecord] {
        records.filter { $0.difficultyRaw == difficulty.rawValue }
    }
    private var played: Int { cohort.count }
    private var wins:   Int { cohort.filter { $0.outcomeRaw == Outcome.win.rawValue }.count }
    private var winPct: String {
        guard played > 0 else { return "—" }
        return "\(Int((Double(wins) / Double(played) * 100).rounded()))%"
    }
    private var bestText: String {
        guard let s = bestTimes.first(where: { $0.difficultyRaw == difficulty.rawValue })?.seconds else { return "—" }
        let m = Int(s) / 60; let sec = Int(s) % 60
        return String(format: "%d:%02d", m, sec)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(difficulty.label)
                    .font(.subheadline.weight(.semibold))
                Text(difficulty.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statNum("\(wins)")
            statNum(winPct)
            statNum(bestText)
        }
        .accessibilityElement(children: .combine)
    }

    private func statNum(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .frame(minWidth: 44, alignment: .trailing)
    }
}
