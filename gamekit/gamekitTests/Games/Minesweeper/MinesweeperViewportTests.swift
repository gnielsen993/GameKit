import CoreGraphics
import Testing
@testable import gamekit

@MainActor
struct MinesweeperViewportTests {
    @Test("The entire board fits when Video Mode and a hint leave less than the preferred cell size",
          arguments: [CGSize(width: 343, height: 220), CGSize(width: 280, height: 150), .zero])
    func fitsConstrainedViewport(_ size: CGSize) {
        let cell = MinesweeperBoardView.cellSize(
            forWidth: size.width, height: size.height, cols: 16, rows: 24,
            padding: 0, spacing: 0, floor: 12
        )
        #expect(cell >= 0)
        #expect(cell * 16 <= size.width + 0.001)
        #expect(cell * 24 <= size.height + 0.001)
    }
}
