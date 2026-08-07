import SwiftUI
import Testing
@testable import gamekit

@Suite("Game assist placement")
@MainActor
struct GameAssistPlacementTests {
    @Test("normal play reserves space above the game")
    func normalPlayUsesTopEdge() {
        for location in VideoModeLocation.allCases {
            #expect(GameAssistPlacement.edge(videoModeEnabled: false, location: location) == .top)
        }
    }

    @Test("top Video Mode windows move coaching below the game")
    func topVideoZonesUseBottomEdge() {
        for location in [
            VideoModeLocation.largeTop,
            .smallTopLeft,
            .smallTopRight
        ] {
            #expect(GameAssistPlacement.edge(videoModeEnabled: true, location: location) == .bottom)
        }
    }

    @Test("bottom Video Mode windows keep coaching above the game")
    func bottomVideoZonesUseTopEdge() {
        for location in [
            VideoModeLocation.largeBottom,
            .smallBottomLeft,
            .smallBottomRight
        ] {
            #expect(GameAssistPlacement.edge(videoModeEnabled: true, location: location) == .top)
        }
    }
}
