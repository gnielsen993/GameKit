import Foundation
import SwiftData
import Testing
@testable import gamekit

@MainActor
struct MathCrosswordStatsTests {
    @Test("Math Crossword assisted wins survive export/import without earning records")
    func assistedWinRoundTrip() throws {
        let container = try InMemoryStatsContainer.make()
        let context = ModelContext(container)
        let stats = GameStats(modelContext: context)
        try stats.record(gameKind: .mathCrossword, difficulty: "easy", outcome: .win,
                         durationSeconds: 120, puzzleId: "math-test-1", assistCount: 1)
        #expect(try context.fetch(FetchDescriptor<BestTime>()).isEmpty)
        let data = try StatsExporter.export(modelContext: context)
        let restoredContainer = try InMemoryStatsContainer.make()
        let restored = ModelContext(restoredContainer)
        try StatsExporter.importing(data, modelContext: restored)
        let records = try restored.fetch(FetchDescriptor<GameRecord>())
        #expect(records.count == 1)
        #expect(records.first?.gameKindRaw == "mathCrossword")
        #expect(records.first?.assistCount == 1)
        #expect(records.first?.puzzleIdRaw == "math-test-1")
        #expect(try restored.fetch(FetchDescriptor<BestTime>()).isEmpty)
    }
}
