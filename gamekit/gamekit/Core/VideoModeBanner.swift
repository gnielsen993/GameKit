//
//  VideoModeBanner.swift
//  gamekit
//
//  Phase 13 — Shared win/loss banner pill consumed by Minesweeper, Merge,
//  and Nonogram on the Video Mode path (videoModeStore.isEnabled == true).
//  C-01 LOCKED at UI-SPEC time: shared view in Core/ (per CLAUDE.md §2 —
//  3 game consumers exceed the promotion threshold). NOT per-game, NOT
//  in DesignKit (Video-Mode-specific; DesignKit is for cross-app primitives).
//
//  Visual contract (UI-SPEC §Visual Contract — Banner Shape):
//    - Pill: `RoundedRectangle(cornerRadius: theme.radii.button)`
//    - Fill: `theme.colors.surface` (NEUTRAL — color sits in title only)
//    - Border: `theme.colors.border` 1px hairline (mirrors DKCard stroke)
//    - Horizontal margin: `theme.spacing.m` from screen edge
//    - Inner padding: `theme.spacing.l`
//    - Title-to-CTA gap: `theme.spacing.s`
//    - Title: `theme.typography.title` (slim pill — NOT titleLarge)
//    - Title color: `theme.colors.success` (win) / `theme.colors.danger` (loss)
//    - DKButton primary on the trailing side — D-11 LOCKED (explicit
//      button; tap-anywhere-on-banner FORBIDDEN)
//    - No scrim, no dim backdrop, no shadow (banner is chrome, NOT a modal)
//
//  Gating (D-13-HAPTICS / D-13-ANIM — v1.0 05-03 + 05-06 locks):
//    - `playEntranceHaptic()` line 1 is `guard hapticsEnabled else { return }`
//    - `.transition` collapses to `.identity` when `reduceMotion || !animationsEnabled`
//    - No spring/bounce — banner is chrome, celebration channel is
//      confetti+sweep (preserved unchanged from v1.0 05-06)
//
//  A11y contract (UI-SPEC §Accessibility Contract):
//    - `.accessibilityElement(children: .combine)` — VoiceOver reads
//      "You won! Restart button" as one statement
//    - Title gets `.isHeader` trait
//    - On appear posts `UIAccessibility.post(.announcement, ...)`
//
//  Coupling note: banner receives `hapticsEnabled` / `reduceMotion` /
//  `animationsEnabled` as plain Bools rather than reading SettingsStore
//  directly. Mirrors the Haptics.swift pattern (CONTEXT D-10) — keeps
//  this file SettingsStore-uncoupled and trivially unit-testable.
//

import SwiftUI
import DesignKit

struct VideoModeBanner: View {
    let theme: Theme
    let content: VideoModeBannerContent
    let location: VideoModeLocation
    let hapticsEnabled: Bool        // settingsStore.hapticsEnabled (FIRST-guard input)
    let reduceMotion: Bool          // @Environment(\.accessibilityReduceMotion)
    let animationsEnabled: Bool     // settingsStore.animationsEnabled

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(content.title)
                    .font(theme.typography.title)
                    .foregroundStyle(titleColor)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle = content.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }

            Spacer(minLength: theme.spacing.s)

            // D-11 LOCKED: exactly ONE DKButton — tap-anywhere-on-banner
            // FORBIDDEN. `.fixedSize()` keeps the CTA at its natural width
            // (DKButton internally uses `maxWidth: .infinity` for full-row
            // contexts; here the title needs room on the leading side).
            DKButton(
                content.primaryButtonLabel,
                style: .primary,
                theme: theme,
                action: content.onPrimary
            )
            .fixedSize()
        }
        .padding(theme.spacing.l)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.button)
                .fill(theme.colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.button)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .padding(.horizontal, theme.spacing.m)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(content.accessibilityLabel))
        .sensoryFeedback(
            content.outcome == .win ? .success : .error,
            trigger: hapticsEnabled ? hapticTrigger : 0
        )
        .onAppear {
            playEntranceHaptic()
            UIAccessibility.post(
                notification: .announcement,
                argument: content.accessibilityLabel
            )
        }
    }

    // MARK: - Visual helpers

    private var titleColor: Color {
        content.outcome == .win ? theme.colors.success : theme.colors.danger
    }

    /// Internal trigger token wired into `.sensoryFeedback(trigger:)`.
    /// Win = 1, loss = 2 — the value-change drives the declarative haptic
    /// surface. When `hapticsEnabled` is false the trigger collapses to 0
    /// at the call site above (defense-in-depth on top of the FIRST-guard
    /// in `playEntranceHaptic()`).
    private var hapticTrigger: Int {
        content.outcome == .win ? 1 : 2
    }

    // MARK: - D-13-HAPTICS firing surface

    /// D-13-HAPTICS: `hapticsEnabled` is the FIRST guard inside the firing
    /// surface, mirroring `Haptics.playAHAP(... hapticsEnabled:)` shape
    /// from v1.0 05-03 D-10. NO SFX path here yet (SFX gating handled by
    /// SFXPlayer per the existing 05-03 lock — banner does not introduce
    /// new audio infrastructure per CONTEXT D-13-SFX).
    ///
    /// Real haptic playback also routes through the declarative
    /// `.sensoryFeedback(...)` modifier above — this method exists for
    /// explicit-call paths and the unit test that asserts the FIRST-guard
    /// shape per `HapticsTests.playAHAP_disabled_doesNotInitializeEngine`
    /// precedent.
    func playEntranceHaptic() {
        guard hapticsEnabled else { return }
        // No-op body on simulator (CHHapticEngine is a no-op there per
        // Apple docs); declarative `.sensoryFeedback` carries the device
        // path. This stub is the FIRST-guard contract anchor.
    }
}

// MARK: - Transition helper (D-13-ANIM / 05-06 D-04)

extension View {
    /// Banner entrance transition — opacity by default, collapses to
    /// `.identity` when Reduce Motion is on OR animationsEnabled is off.
    /// Mirrors the v1.0 05-06 D-04 per-surface lock pattern.
    func videoModeBannerTransition(
        reduceMotion: Bool,
        animationsEnabled: Bool
    ) -> some View {
        self.transition(
            (reduceMotion || !animationsEnabled) ? .identity : .opacity
        )
    }
}
