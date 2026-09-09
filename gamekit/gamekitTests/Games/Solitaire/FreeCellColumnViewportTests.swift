import Testing
import Foundation
@testable import gamekit

@MainActor
struct FreeCellColumnViewportTests {
    @Test("Long FreeCell columns stay inside the available board height", arguments: [9, 16, 20])
    func longColumnsFit(_ count: Int) {
        let offset = FreeCellColumnView.fanOffset(for: count, cardWidth: 48, availableHeight: 180)
        #expect(offset >= 0)
        #expect(48 * 1.4 + Double(count - 1) * offset <= 180.001)
    }

    @Test("Short and empty columns keep their normal fan spacing", arguments: [0, 1, 5])
    func shortColumnsKeepSpacing(_ count: Int) {
        #expect(FreeCellColumnView.fanOffset(for: count, cardWidth: 48, availableHeight: 400)
                == FreeCellColumnView.fanOffset(for: count, cardWidth: 48))
    }
}
