//
//  NonogramGameView+EndBanner.swift
//  gamekit
//
//  Phase 13 — Win/Loss banner adoption for NonogramGameView on the Video
//  Mode path. Per D-13-OFFPATH the existing `NonogramEndStateCard` stays
//  byte-identical on the off-path; this file owns the banner content
//  factories + the positioned banner view consumed on the Video Mode path.
//
//  Split from NonogramGameView.swift to keep `+VideoMode.swift` /
//  `+SmallZone.swift` under the CLAUDE.md §8.5 ≤500-line cap.
//
//  Single primary CTA per D-02 LOCKED — no "Change size" secondary on
//  the banner (reachable from NonogramToolbarMenu in the nav bar).
//
//  On .won the puzzle title surfaces as the banner SUBTITLE (the puzzle's
//  picture title is hidden during play and revealed on completion, mirroring
//  the v1.1 NonogramEndStateCard convention).
//

import SwiftUI
import DesignKit

extension NonogramGameView {

    // MARK: - Banner view (positioned to the router edge + alignment)

    @ViewBuilder
    var videoModeEndBanner: some View {
        if bannerDismissed {
            EmptyView()
        } else {
            // User override round 2 — banner CENTERED in all modes.
            let content = bannerContent()

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

    // MARK: - Content factory (D-13-COPY LOCKED — match v1.1 EndStateCard copy)

    private func bannerContent() -> VideoModeBannerContent {
        let viewBoardLabel = String(localized: "View board")
        let dismissBanner = { bannerDismissed = true }
        let changeSize = { showDifficultyPicker = true }
        let changeSizeLabel = String(localized: "Change size")
        let isWon = viewModel.state == .won
        if isWon {
            let puzzleTitle = viewModel.currentPuzzle?.title ?? ""
            return VideoModeBannerContent(
                outcome: .win,
                title: String(localized: "Solved"),
                subtitle: puzzleTitle.isEmpty ? nil : puzzleTitle,
                primaryButtonLabel: String(localized: "New puzzle"),
                accessibilityLabel: puzzleTitle.isEmpty
                    ? String(localized: "Solved. New puzzle")
                    : String(format: String(localized: "Solved: %@. New puzzle"), puzzleTitle),
                onPrimary: { viewModel.newPuzzle() },
                secondaryButtonLabel: viewBoardLabel,
                secondaryAction: dismissBanner,
                tertiaryButtonLabel: changeSizeLabel,
                tertiaryAction: changeSize
            )
        } else {
            return VideoModeBannerContent(
                outcome: .loss,
                title: String(localized: "Out of lives"),
                subtitle: nil,
                primaryButtonLabel: String(localized: "Try again"),
                accessibilityLabel: String(localized: "Out of lives. Try again"),
                onPrimary: { viewModel.restart() },
                secondaryButtonLabel: viewBoardLabel,
                secondaryAction: dismissBanner,
                tertiaryButtonLabel: changeSizeLabel,
                tertiaryAction: changeSize
            )
        }
    }

    // MARK: - Anchor → SwiftUI Alignment mapping

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
}
