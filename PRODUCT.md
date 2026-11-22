# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

People who want a quick, calm classic game on iPhone or iPad: a puzzle, a hand of cards, a word game or a short arcade run. They often play while a video runs in Picture in Picture, so the game shares the screen and their attention. They do not want to manage an account, a currency or a streak in order to play.

## Product Purpose

GameDrawer is a small collection of classic games that is ready when the player is. It ships eleven games (Minesweeper, Merge, Nonogram, Sudoku, Klondike, FreeCell, Five Letter, Word Grid, Stack, Snake, Math Crossword) that work fully offline. Success means a player reaches the game they want quickly, is never punished silently, and has an honest reason to come back without being pushed to.

## Positioning

Undecided (2.0 vision, open decision 5). The two candidates:

- A calm, personal game home, with Video Mode as its signature capability.
- The games app built to be played alongside video, with the personal Home in support.

Do not write copy or design a surface that commits to one until Gabe decides. What both share, and what is settled: no ads shipped, no coins, no fake currency, no energy systems, no aggressive subscriptions, no required account.

## Operating Context

- Sessions are short and frequently interrupted. Eight of the turn-based games save state and resume.
- Video Mode adapts each game's layout around a Picture in Picture window in one of six positions. Arcade games (Stack, Snake) are deliberate exemptions.
- Players choose a theme preset (Classic, Sweet, Bright, Soft, Moody, Loud families) and every screen must stay legible under any of them.
- Assists explain the deduction rather than reveal the answer. An assisted win counts as a win but sets no record.
- iCloud sync through Sign in with Apple is optional and never gates play.

## Capabilities and Constraints

- Swift 6, SwiftUI, lightweight MVVM, SwiftData. iOS 17 and later.
- Offline-first. The CloudKit private database is the only network surface; no third-party backend and no analytics SDK.
- All styling reads DesignKit semantic tokens. No hard-coded colors, radii or spacing.
- The app must launch instantly, and shows no popups or pushy prompts on first run.
- Settings stays small: theme, haptics, sound, reset stats, about.
- Haptics, sound and celebratory motion must respect the user's settings and Reduce Motion.
- Stats export and import as JSON with a schema version. User data is never deleted automatically.
- The bundle identifier is fixed.
- 2.0 direction (approved 2026-07-12): the current grid becomes Library, the permanent complete view of every game. A new Home sits above it with Pinned shortcuts, Continue Playing and one recommendation, and later a Daily.
- Undecided: whether Home replaces the root or sits beside Library; whether a pin launches a mode directly; which game gets the first Daily; the monetization model.

## Brand Commitments

- The product name is GameDrawer. GameKit remains the repository, scheme and target name.
- "No ads" is stated in the present tense only. Never "no ads ever", "never ads" or any permanent ad claim; the stance has been under review since 2026-07-12.
- The Classic preset is Chrome Diner: cream paper, white cards, brushed-grey bezels, diner-red accent. Classic changes color and surface treatment only; layout, spacing, radii, motion and type weights stay modern.
- Guide without coercing. No anxiety, punishment or manufactured urgency as a reason to return.
- `DESIGN.md` is the binding visual and interaction contract.

## Evidence on Hand

- Store copy and metadata: `Docs/store/app-store-copy.md`, `Marketing/AppStore-1.6/`.
- Visual and interaction contract: `DESIGN.md`.
- 2.0 direction and open decisions: `.planning/v2.0-VISION.md`.
- Shipped behavior by version: `Docs/releases/`.
- Layout and assist audits for 1.6: `Docs/audits/`.
- No usage analytics exist (none are collected). No testimonials, benchmarks or retention figures are established; do not invent them.

## Product Principles

- Guide without coercing: a recommendation may reduce choice, never create pressure.
- User choice outranks recency: pinned shortcuts are permanent, Continue Playing is automatic and temporary.
- The complete Library is always one tap away.
- Be kind: never punish the player silently, and teach rather than reveal.
- Personality comes from the preset and layout emphasis, not from one-off styling.

## Accessibility & Inclusion

Support Dynamic Type, VoiceOver labels that carry game meaning (coordinates, suits, hint roles), sufficient contrast under every shipped preset, state cues that do not rely on color alone, and Reduce Motion with a clean non-animated path for every effect.
