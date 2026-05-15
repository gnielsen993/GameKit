//
//  MinesweeperGameView+EndBanner.swift
//  gamekit
//
//  Phase 13 — Win/Loss banner adoption for MinesweeperGameView on the
//  Video Mode path. Per D-13-OFFPATH the existing `MinesweeperEndStateCard`
//  stays byte-identical on the off-path (`videoModeStore.isEnabled == false`);
//  this file owns the banner content factories + the positioned banner view
//  consumed on the Video Mode path.
//
//  Split from MinesweeperGameView.swift to keep that file under the
//  CLAUDE.md §8.5 ≤500-line cap (the +VideoMode.swift host is at 486 LOC).
//
//  Single primary CTA per D-02 LOCKED — no "Change difficulty" secondary
//  on the banner (reachable from MinesweeperToolbarMenu in the nav bar).
//

import SwiftUI
import DesignKit

extension MinesweeperGameView {

    // MARK: - Banner view (positioned to the router edge + alignment)

    /// Banner for a win/loss outcome on the Video Mode path. Anchors to the
    /// edge + alignment returned by `VideoModeBannerRouter.anchor(for:)`
    /// per 08-BANNER-PLACEMENT.md D-09 — banner docks OPPOSITE the covered
    /// PiP corner so the board stays visible behind it.
    ///
    /// Returns an `EmptyView` when `bannerDismissed == true` (user tapped
    /// "View board" — banner hides so user can inspect the final board).
    @ViewBuilder
    func videoModeEndBanner(outcome: GameOutcome) -> some View {
        if bannerDismissed {
            EmptyView()
        } else {
            // User override 2026-05-14 (round 2): banner CENTERED in ALL
            // modes — "View board" dismiss button handles the
            // banner-covers-board concern. Edge-anchored router retained
            // for reference but not consumed.
            let content = bannerContent(for: outcome)

            VideoModeBanner(
                theme: theme,
                content: content,
                location: videoModeStore.location,
                hapticsEnabled: settingsStore.hapticsEnabled,
                reduceMotion: reduceMotion,
                animationsEnabled: settingsStore.animationsEnabled
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .center
            )
            .videoModeBannerTransition(
                reduceMotion: reduceMotion,
                animationsEnabled: settingsStore.animationsEnabled
            )
        }
    }

    // MARK: - Content factories (D-13-COPY LOCKED — match v1.x EndStateCard copy)

    private func bannerContent(for outcome: GameOutcome) -> VideoModeBannerContent {
        let viewBoardLabel = String(localized: "View board")
        let dismissBanner = { bannerDismissed = true }
        let changeDifficulty = { showDifficultyPicker = true }
        let changeDifficultyLabel = String(localized: "Change difficulty")
        switch outcome {
        case .win:
            return VideoModeBannerContent(
                outcome: .win,
                title: String(localized: "You won!"),
                subtitle: nil,
                primaryButtonLabel: String(localized: "Restart"),
                accessibilityLabel: String(
                    format: String(localized: "You won! Time: %@. Restart"),
                    formatElapsedShort(viewModel.frozenElapsed)
                ),
                onPrimary: { viewModel.restart() },
                secondaryButtonLabel: viewBoardLabel,
                secondaryAction: dismissBanner,
                tertiaryButtonLabel: changeDifficultyLabel,
                tertiaryAction: changeDifficulty
            )
        case .loss:
            return VideoModeBannerContent(
                outcome: .loss,
                title: String(localized: "Bad luck"),
                subtitle: nil,
                primaryButtonLabel: String(localized: "Restart"),
                accessibilityLabel: String(localized: "Bad luck. Restart"),
                onPrimary: { viewModel.restart() },
                secondaryButtonLabel: viewBoardLabel,
                secondaryAction: dismissBanner,
                tertiaryButtonLabel: changeDifficultyLabel,
                tertiaryAction: changeDifficulty
            )
        }
    }

    // MARK: - Anchor → SwiftUI Alignment mapping

    /// Maps the banner anchor (edge + alignment) to a SwiftUI `Alignment`
    /// for the parent ZStack frame. The banner self-sizes; the alignment
    /// pins it to the right corner of the parent.
    static func bannerAlignment(for anchor: VideoModeBannerAnchor) -> Alignment {
        switch (anchor.edge, anchor.alignment) {
        case (.top, .fullWidth):       return .top
        case (.top, .leading):         return .topLeading
        case (.top, .trailing):        return .topTrailing
        case (.bottom, .fullWidth):    return .bottom
        case (.bottom, .leading):      return .bottomLeading
        case (.bottom, .trailing):     return .bottomTrailing
        }
    }

    // MARK: - Elapsed formatting (mirrors MinesweeperEndStateCard.formatElapsed)

    private func formatElapsedShort(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
