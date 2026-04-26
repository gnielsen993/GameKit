//
//  MinesweeperEndStateCard.swift
//  gamekit
//
//  End-state overlay shown after win or loss. Composed DKCard (D-01) — the
//  card itself supplies radii.card, spacing.l outer padding, surface fill,
//  and border stroke (DKCard.swift); this view contributes content composition only.
//
//  Phase 3 invariants (per D-01..D-04, UI-SPEC §Copywriting):
//    - Outcome title tinted theme.colors.success (win) / theme.colors.danger
//      (loss); body text stays theme.colors.textPrimary so the card reads
//      identically across all 6 audit presets (CLAUDE.md §8.12 + D-04).
//    - Loss surfaces "X mines hit / Y safe cells left" educational line
//      (D-03 part 3).
//    - Two buttons via DKButton — Restart (.primary) and Change difficulty
//      (.secondary). Do NOT redeclare button styles (PATTERNS §"DKButton
//      primary/secondary").
//    - Refined D-03 (W-02): "Change difficulty" calls viewModel.restart() via
//      the onChangeDifficulty closure (resets to fresh idle, same difficulty);
//      user changes difficulty via the toolbar Menu themselves. Sheet-presented
//      picker deferred to P5.
//    - No tap-to-dismiss on the backdrop (D-02). Backdrop dim is the GameView's
//      job (Plan 04); this card renders content only.
//

import SwiftUI
import DesignKit

struct MinesweeperEndStateCard: View {
    let theme: Theme
    let outcome: GameOutcome                // .win or .loss (defined in MinesweeperViewModel.swift, Plan 02)
    let elapsed: TimeInterval
    let lossContext: LossContext?           // populated only when outcome == .loss
    let onRestart: () -> Void
    let onChangeDifficulty: () -> Void

    var body: some View {
        DKCard(theme: theme) {
            VStack(spacing: theme.spacing.l) {
                Text(outcomeTitleKey)
                    .font(theme.typography.titleLarge)
                    .foregroundStyle(outcome == .win ? theme.colors.success : theme.colors.danger)
                    .multilineTextAlignment(.center)

                Text(formatElapsed(elapsed))
                    .font(theme.typography.title)
                    .foregroundStyle(theme.colors.textPrimary)
                    .monospacedDigit()

                if outcome == .loss, let ctx = lossContext {
                    Text("\(ctx.minesHit) mines hit / \(ctx.safeCellsRemaining) safe cells left")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textPrimary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: theme.spacing.s) {
                    DKButton(
                        String(localized: "Restart"),
                        style: .primary,
                        theme: theme,
                        action: onRestart
                    )
                    DKButton(
                        String(localized: "Change difficulty"),
                        style: .secondary,
                        theme: theme,
                        action: onChangeDifficulty
                    )
                }
            }
        }
        .frame(maxWidth: 320)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(overlayAccessibilityLabel)
    }

    // MARK: - Localized title (D-03 part 1)

    private var outcomeTitleKey: LocalizedStringKey {
        switch outcome {
        case .win:  return "You won!"
        case .loss: return "Bad luck"
        }
    }

    // MARK: - Elapsed format (mirrors HeaderBar's format — duplicate intentional;
    //                        per CLAUDE.md §4 a 2-call-site duplicate within one
    //                        game is below the DesignKit-promotion bar)

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Overlay-level a11y (D-20 — baked at view creation)

    private var overlayAccessibilityLabel: LocalizedStringKey {
        switch outcome {
        case .win:
            return "You won! Time: \(formatElapsed(elapsed))"
        case .loss:
            if let ctx = lossContext {
                return "Bad luck. \(ctx.minesHit) mines hit, \(ctx.safeCellsRemaining) safe cells left."
            }
            return "Bad luck."
        }
    }
}
