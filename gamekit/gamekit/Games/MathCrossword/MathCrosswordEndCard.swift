import SwiftUI
import DesignKit

struct MathCrosswordEndCard: View {
    let theme: Theme
    let difficulty: MathCrosswordDifficulty
    let elapsed: TimeInterval
    let assistsUsed: Int
    let location: VideoModeLocation
    let hapticsEnabled: Bool
    let reduceMotion: Bool
    let animationsEnabled: Bool
    let onNewPuzzle: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VideoModeBanner(
            theme: theme,
            content: VideoModeBannerContent(
                outcome: .win,
                title: "Crossword complete",
                subtitle: subtitle,
                primaryButtonLabel: "New puzzle",
                accessibilityLabel: "Math crossword complete in \(formattedElapsed)",
                onPrimary: onNewPuzzle,
                secondaryButtonLabel: "View board",
                secondaryAction: onDismiss
            ),
            location: location,
            hapticsEnabled: hapticsEnabled,
            reduceMotion: reduceMotion,
            animationsEnabled: animationsEnabled
        )
    }

    private var subtitle: String {
        let base = "\(difficulty.displayName) · \(formattedElapsed)"
        guard assistsUsed > 0 else { return base }
        return "\(base) · solved with \(assistsUsed) \(assistsUsed == 1 ? "hint" : "hints")"
    }

    private var formattedElapsed: String {
        let total = max(0, Int(elapsed))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
