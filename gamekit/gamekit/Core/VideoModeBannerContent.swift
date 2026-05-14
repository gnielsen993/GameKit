//
//  VideoModeBannerContent.swift
//  gamekit
//
//  Phase 13 — PoD content struct consumed by VideoModeBanner. C-02 LOCKED
//  at UI-SPEC time: struct (not @ViewBuilder slots) gives a checklist of
//  fields the per-game adopter can't accidentally omit (compile error)
//  and can't extend with a second button (no slot exists). Per CONTEXT
//  D-02 the banner is single-action by lock.
//
//  Per-game adopters pre-compose `accessibilityLabel` (mirrors the
//  existing EndStateCard `overlayAccessibilityLabel` plumbing per
//  MinesweeperEndStateCard.swift:102). The banner does NOT re-build
//  the a11y string from game-specific state.
//
//  Nested `Outcome` (not the top-level `Core/Outcome.swift` raw-string
//  enum) — banner outcome is a presentation distinction (color tint,
//  haptic cue) decoupled from the persistence-shape Outcome that drives
//  `GameRecord.outcomeRaw`. Per-game adopters map their game-specific
//  end-state to this enum at the banner content site.
//
//  Foundation-only — no SwiftUI import keeps the struct usable from
//  view-model layers and snapshot rigs.
//

import Foundation

/// Plain-old-data content for the shared `VideoModeBanner` view. Per
/// UI-SPEC C-02 LOCKED — adopters pass this struct to the banner; the
/// banner does NOT take @ViewBuilder slots (no second button slot exists).
struct VideoModeBannerContent: Sendable {
    /// Presentation outcome — drives title color tint (success vs danger)
    /// and haptic cue (success vs error). Decoupled from the top-level
    /// `Outcome` raw-string enum (`Core/Outcome.swift`) which is the
    /// persistence-shape used by `GameRecord`.
    enum Outcome: Sendable, Equatable {
        case win
        case loss
    }

    /// Win/loss for color + haptic differentiation.
    let outcome: Outcome

    /// Headline string — mirrors the existing EndStateCard title verbatim
    /// per CONTEXT D-01 (e.g. "You won!", "Bad luck", "You reached 2048!").
    let title: String

    /// Optional secondary line. Nonogram appends the puzzle title here on
    /// `.win`; Mines / Merge pass `nil`.
    let subtitle: String?

    /// Localized DKButton label — e.g. "Restart", "Continue", "New puzzle".
    let primaryButtonLabel: String

    /// Pre-composed VoiceOver label combining title + game-state context
    /// (e.g. "You won! Time: 0:42"). Built by the per-game adopter
    /// because elapsed/score/lives plumbing already lives there.
    let accessibilityLabel: String

    /// Primary CTA closure — invoked when the DKButton is tapped.
    let onPrimary: () -> Void
}
