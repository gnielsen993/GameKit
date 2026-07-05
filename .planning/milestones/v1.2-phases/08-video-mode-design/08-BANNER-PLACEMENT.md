# Phase 8 — Win/Loss Banner Placement

## Status

Design lock for Phase 13. Replaces the v1.0 full-screen win/loss overlays with a non-board-covering banner per plan-doc §Win/loss screens. Board stays visible behind the banner in all 6 PiP locations.

## Anchor table (D-09 opposite-of-PiP rule)

| PiP location  | Banner docks   |
| ------------- | -------------- |
| Large top     | bottom edge    |
| Large bottom  | top edge       |
| Small TL      | bottom-right   |
| Small TR      | bottom-left    |
| Small BL      | top-right      |
| Small BR      | top-left       |

*One rule, six outcomes. Downstream agents read the table — do not re-derive.*

## Shape (D-10)

- Pill, full-width-minus-margins along its anchor edge.
- Small vertical footprint — board remains fully visible behind it (the rule that defines Video Mode).
- Reads as chrome, not as a modal.
- Corner radius: `radii.button` (consistency with the picker pill anchor from 08-COMPACT-ROW-TOKENS.md D-05).
- Horizontal margin: `spacing.m` from screen edge.

## Primary action (D-11)

- Explicit `DKButton` embedded inside the banner ("Play Again" / "Continue").
- Visible affordance — one-tap reachable from the moment the banner appears.
- VoiceOver-friendly (standard DKButton accessibility traits).
- FORBIDDEN: any tap-anywhere-on-banner-to-trigger-action pattern (REQUIREMENTS VIDEO-11 SC2). The action lives on the `DKButton`, not on the banner surface itself.

## Reduce-Motion handling (D-12)

- Banner motion dampens to identity when `accessibilityReduceMotion == true`.
- Concrete surface-level rules (mirrors 05-06 D-04):
  - `.transition(.opacity)` collapses to `.transition(.identity)` when Reduce Motion is on.
  - Confetti / sweep / spring collapse to no-op (`trigger: false` / `value: 0`).
  - Static banner appears immediately, no animated entrance.
- Reference: see v1.0 05-06 D-04 for the surface-level lock pattern.

## Haptics & SFX gating (restated for the banner)

- **Win-banner haptic** — guarded by `settingsStore.hapticsEnabled` FIRST, inside the firing surface (v1.0 05-03 D-10 contract). The toggle is the first line of the function body, not an external wrapper.
- **Loss-banner haptic** — same guard: `settingsStore.hapticsEnabled` FIRST, inside the firing surface.
- **Win/loss banner SFX** — guarded by `settingsStore.sfxEnabled` FIRST. Plays on `AVAudioSession.ambient` (does NOT duck user music). Default OFF per MINES-10.
- **Optional confetti** — gated by `accessibilityReduceMotion` AND any future `animationsEnabled` toggle. If either disables motion, confetti is no-op.

## Out of scope

- Auto-dismiss timer behavior (Phase 13 decides).
- Banner stack handling for back-to-back wins (Phase 13 decides).
- Per-game banner copy variations (Phase 13 decides — design phase only locks placement/shape/action/a11y).

## Source decisions

- D-09 — opposite-of-PiP anchor rule (6-row table).
- D-10 — pill shape, full-width-minus-margins, `radii.button`.
- D-11 — `DKButton` primary action inside banner; the action surface is the button, not the whole banner.
- D-12 — Reduce-Motion dampens to identity (mirrors v1.0 05-06 D-04).

## Consumed by

- Phase 13 SC1 — non-board-covering banner in all 3 games across all 6 PiP locations.
- Phase 13 SC2 — primary action one-tap reachable (D-11 lock).
- Phase 13 SC3 — haptics gating (`hapticsEnabled` FIRST guard).
- Phase 13 SC4 — SFX gating (`sfxEnabled` FIRST guard, ambient session, default OFF).
- Phase 13 SC5 — animation + Reduce Motion gating (`accessibilityReduceMotion` dampen-to-identity).
