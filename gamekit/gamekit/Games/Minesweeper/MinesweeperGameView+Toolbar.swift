import SwiftUI
import DesignKit

extension MinesweeperGameView {
    // MARK: - Toolbar contents (off-path + Small-zone)

    @ToolbarContentBuilder
    var existingToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { backButton }
        ToolbarItem(placement: .topBarLeading) { restartButton }
        if assistIsAvailable {
            ToolbarItem(placement: .topBarTrailing) {
                GameAssistToolbarButton(
                    theme: theme,
                    label: String(localized: "Show a Minesweeper hint"),
                    action: { viewModel.requestHint() }
                )
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            MinesweeperToolbarMenu(
                theme: theme,
                currentDifficulty: viewModel.difficulty,
                onSelect: { viewModel.requestDifficultyChange($0) },
                onHint: assistIsAvailable ? { viewModel.requestHint() } : nil,
                onOpenSafeSquare: settingsStore.assistsEnabled && viewModel.hintFoundNothing
                    ? { viewModel.openASafeSquare() } : nil
            )
        }
    }

    @ToolbarContentBuilder
    var smallZoneToolbarContent: some ToolbarContent {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) { backButton }
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) { restartButton }
        if assistIsAvailable {
            ToolbarItem(placement: Self.toolbarPlacement(for: anchors.settings)) {
                GameAssistToolbarButton(
                    theme: theme,
                    label: String(localized: "Show a Minesweeper hint"),
                    action: { viewModel.requestHint() }
                )
            }
        }
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.settings)) {
            MinesweeperToolbarMenu(
                theme: theme,
                currentDifficulty: viewModel.difficulty,
                onSelect: { viewModel.requestDifficultyChange($0) },
                compact: true,
                onHint: assistIsAvailable ? { viewModel.requestHint() } : nil,
                onOpenSafeSquare: settingsStore.assistsEnabled && viewModel.hintFoundNothing
                    ? { viewModel.openASafeSquare() } : nil
            )
        }
    }

    var assistIsAvailable: Bool {
        settingsStore.assistsEnabled
            && (viewModel.gameState == .idle || viewModel.gameState == .playing)
    }

    static func toolbarPlacement(for anchor: SlotAnchor) -> ToolbarItemPlacement {
        switch anchor {
        case .topLeading: return .topBarLeading
        case .topTrailing: return .topBarTrailing
        case .bottomLeading, .bottomTrailing: return .bottomBar
        case .inCompactRow, .hidden: return .topBarLeading
        }
    }
}
