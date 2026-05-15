//
//  MergeGameView+EndBanner.swift
//  gamekit
//
//  Phase 13 — Win/Loss banner adoption for MergeGameView on the Video
//  Mode path. Per D-13-OFFPATH the existing `MergeEndStateCard` stays
//  byte-identical on the off-path; this file owns the banner content
//  factories + the positioned banner view consumed on the Video Mode path.
//
//  Split from MergeGameView.swift to keep the host `+VideoMode.swift`
//  under the CLAUDE.md §8.5 ≤500-line cap.
//
//  Single primary CTA per D-02 LOCKED — no "Change mode" secondary on
//  the banner (reachable from MergeToolbarMenu in the nav bar).
//

import SwiftUI
import DesignKit

extension MergeGameView {

    // MARK: - Banner view (positioned to the router edge + alignment)

    @ViewBuilder
    func videoModeEndBanner(state: MergeEndState) -> some View {
        if bannerDismissed {
            EmptyView()
        } else {
            // User override round 2 — banner CENTERED in all modes.
            let content = bannerContent(for: state)

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

    // MARK: - Content factories (D-13-COPY LOCKED — match v1.1 EndStateCard copy)

    private func bannerContent(for state: MergeEndState) -> VideoModeBannerContent {
        let viewBoardLabel = String(localized: "View board")
        let dismissBanner = { bannerDismissed = true }
        switch state {
        case .won:
            // Win in winMode → primary "Continue" infinite; tertiary
            // "Restart" lets the user start over instead of continuing.
            return VideoModeBannerContent(
                outcome: .win,
                title: String(localized: "You reached 2048!"),
                subtitle: nil,
                primaryButtonLabel: String(localized: "Continue"),
                accessibilityLabel: String(
                    format: String(localized: "You reached 2048! Score %d. Continue"),
                    viewModel.score
                ),
                onPrimary: { viewModel.continuePastWin() },
                secondaryButtonLabel: viewBoardLabel,
                secondaryAction: dismissBanner,
                tertiaryButtonLabel: String(localized: "Restart"),
                tertiaryAction: { viewModel.restart() }
            )
        case .gameOver:
            return VideoModeBannerContent(
                outcome: .loss,
                title: String(localized: "Game over"),
                subtitle: nil,
                primaryButtonLabel: String(localized: "Restart"),
                accessibilityLabel: String(
                    format: String(localized: "Game over. Score %d. Restart"),
                    viewModel.score
                ),
                onPrimary: { viewModel.restart() },
                secondaryButtonLabel: viewBoardLabel,
                secondaryAction: dismissBanner
                // No tertiary — Merge mode picker lives in toolbar menu.
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
