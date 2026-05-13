# Phase 10: Layout Primitives - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship two reusable SwiftUI layout primitives that encode the v1.2 reflow
contract from `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §Core rule:

- **Small PiP = control-aware** — controls reposition away from the covered
  corner; the board stays at normal size.
- **Large PiP = board-aware** — a top or bottom band is reserved; the board
  fits between the band and the compact control row; secondary controls
  collapse before the board becomes unplayable.

Plus the **VIDEO-13 off-restore guarantee** — toggling Video Mode Off
immediately restores each adopted game view to its baseline layout with no
visual residue (no relaunch).

This phase **locks the adoption API** that Phases 11 / 12 / 13 will use to
wrap their existing game views — the API surface is the load-bearing decision
of this phase. Phase 10 ships zero per-game adoption; that's Phases 11+.

In scope: `VideoModeAware` ViewModifier + `VideoModeSlotRouter` helper +
`#Preview`-only stub satisfying SC5 + Swift Testing coverage of SC3 off-restore.

Out of scope: per-game adoption (Phase 11 Mines / Phase 12 Merge + Nonogram /
Phase 13 banner), modification to the existing `MinesweeperBoardView`
`MagnifyGesture` + auto-scale stack (locked by Phase 8 ADR — only
`Self.minCellSize` becomes Video-Mode-aware, and that lives in Phase 11), and
banner placement (Phase 13 consumes `08-BANNER-PLACEMENT.md` directly).

</domain>

<decisions>
## Implementation Decisions

### Adoption API surface (SC4)

- **D-01:** Adoption surface is **`.videoModeAware()` ViewModifier** — a single
  chainable modifier any game view applies at its outermost layer. Locks the
  call site for Phases 11 / 12 / 13 to one line per game. Resolves the
  ROADMAP §v1.2 Research Flags §Phase 10 tradeoff in favor of the ViewModifier
  shape; the `VideoModeContainer { ... }` wrapper and the explicit
  slot-based `VideoModeLayout(board:controls:)` are rejected because the
  per-game game-view source already contains the compact-row + board layout,
  and a modifier wraps that as-is without forcing each game to re-express its
  layout in slots.
- **D-02:** Slot reposition (the in-view rearrangement — e.g., move back from
  TL to TR when PiP is in TL) lives in the **game view**, not the modifier.
  The game view reads `@Environment(\.videoModeStore)` and rearranges its own
  slots. To prevent drift across the 3 games, P10 ships a shared pure helper
  `VideoModeSlotRouter` — `static func anchors(for: VideoModeLocation) -> SlotAnchorMap`
  — that returns where each slot goes for a given PiP zone. Every adopting
  game view in Phases 11 / 12 calls the same helper. The modifier itself
  handles only container-level concerns (band reservation, safe-area inset,
  off-restore short-circuit).
- **D-03:** Files live **flat in `gamekit/gamekit/Core/`** as siblings to the
  P9-shipped `VideoModeStore.swift` / `VideoModeLocation.swift` /
  `VideoCompactControlRow.swift`:
  - `gamekit/gamekit/Core/VideoModeAware.swift` — modifier + `.videoModeAware()`
    extension + `VideoModeCompactness` enum
  - `gamekit/gamekit/Core/VideoModeSlotRouter.swift` — pure helper + `SlotAnchorMap`
  No new subdirectory — keeps consistency with P9's flat-Core/ choice; avoids
  re-shuffling already-shipped P9 files. Future Phase 13 banner can join the
  flat layout.
- **D-04:** The modifier reads `VideoModeStore` directly via
  `@Environment(\.videoModeStore)` — the same env-key seam P9 D-05 locked.
  No duplicate env keys (`\.videoModeEnabled` / `\.videoModeLocation` are
  NOT introduced as scalars). No location-as-parameter. The store is the
  single source of truth.

### Off-restore mechanism (SC3 / VIDEO-13)

- **D-05:** Off-restore = **hard short-circuit**. First line of the modifier's
  body branches:
  ```swift
  if !store.isEnabled { return AnyView(content) }
  ```
  Off-path = zero env publishing, zero compactness measurement, zero band
  reservation, zero slot-router invocation. Byte-identical view tree to a
  build that never knew about Video Mode. Accepts the minor SwiftUI
  type-erasure cost of `AnyView` on the off-path in exchange for trivial
  verifiability. The off-path is the dominant runtime path (most users will
  never enable Video Mode); blast-radius minimization is the priority.
- **D-06:** SC3 verification = **Swift Testing unit test + manual spot-check**
  per the P9 SC5 pattern from `09-VALIDATION.md`. The unit test asserts that
  with `store.isEnabled = false`, `.videoModeAware()` returns content
  byte-identical to the un-wrapped view (verified via a generic equality
  probe — exact mechanism is a planner concern). Manual spot-check: enable
  Video Mode in Settings, return to the stub game screen, toggle Off via the
  Settings toggle without relaunching, confirm immediate reversion. Matches
  the v1.0 5-Wave verification rhythm.
- **D-07:** **P10 SC3 supersedes P9 SC5 for games that adopt
  `.videoModeAware()`.** Once a game view in P11 / P12 is wrapped, P10's
  hard-short-circuit owns the off-restore contract for that view. P9 SC5
  ("game doesn't read the store at all") remains in force only for games
  not yet adopted. Cleaner contract ownership — no two-layered guarantee
  to debug if regression appears.

### Large-PiP reserved band sizing (SC2)

- **D-08:** Band height is **a fixed percent of screen height**, computed at
  runtime via `GeometryReader`. The modifier reads `geometry.size.height`
  and reserves `geometry.size.height * largeBandFraction` at the top edge
  (when `location == .largeTop`) or bottom edge (when `.largeBottom`). The
  reservation is applied via `.safeAreaInset(edge:)` so SwiftUI's layout
  engine adjusts the board's available height natively. Scales automatically
  to any device height — fulfills SC5's "smallest supported device" implicit
  requirement.
- **D-09:** The fraction value is **measured from Phase 8 screenshots first**,
  not picked from intuition. Plan task: open
  `Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png` (and
  `home-classic-pip-large-top.png`), measure the simulated PiP band height in
  pixels, divide by the screen height (iPhone 17 Pro Max @ 932pt logical /
  2796px physical). Use the derived ratio as `largeBandFraction`. Working
  estimate: ~0.30 (iOS native PiP large band is roughly 28–32% of screen).
  The measurement is a P10 plan task, not a guess. Documented inline with
  the source screenshot reference + iOS native PiP rationale.
- **D-10:** Constant lives as **a private static on `VideoModeAware`**:
  ```swift
  private static let largeBandFraction: CGFloat = <measured>
  ```
  Single source of truth, easy to grep, doc-commented with the screenshot
  reference. Tunable post-P10 if Phase 11 Hard-Mines validation (P8 ADR
  squeeze case) surfaces a regression — adjusting one constant does not
  require an ADR amendment. NOT promoted to a DesignKit token (CLAUDE.md §2
  promotion rule: needs 2+ consumers; v1.2 has 1).
- **D-11:** **Small PiP is pure controls-routing** — the modifier does NOT
  reserve a corner inset or touch the board's frame / safe area on small
  zones (TL / TR / BL / BR). Phase 8 evidence (the 4-corner Hard Dracula
  canonical set —
  `mines-hard-dracula-pip-small-{tl,tr,bl,br}.png`) proves the board fits at
  normal cell size for every game / difficulty when PiP is Small. On Small
  zones, the modifier publishes the slot-router's anchors via env (D-12) and
  leaves the rest of the layout alone.

### Compromise order surface

- **D-12:** Compromise order **is encoded in the primitive**, not in
  individual game views. The modifier measures available board height
  (`geometry.size.height − largeBand − compactRowHeight − safeArea`) and
  publishes a discrete `VideoModeCompactness` value via env
  (`\.videoModeCompactness`). Game views read the env value and react —
  game-aware reaction (which slot to drop) lives in the game view; threshold
  decision lives in the primitive. Mirrors the slot-routing seam from D-02
  (data published by primitive, decision applied by game).
- **D-13:** `VideoModeCompactness` exposes **3 levels** mapping plan-doc
  Compromise order steps:
  ```swift
  enum VideoModeCompactness {
      case normal              // plan-doc steps 1–3 satisfied
      case collapsedSettings   // plan-doc step 4 — Settings into overflow menu
      case reducedTime         // plan-doc step 5 — hide time / secondary stats
  }
  ```
  Step 6 (board shrink) is NOT a primitive concern — it's the Hard-Mines
  smaller-cells path from `08-HARD-MINES-ADR.md`, gated on
  `videoModeStore.isEnabled` inside `MinesweeperBoardView.cellSize` (Phase 11).
  Three levels are sufficient for v1.2; future steps are added when a
  game needs them.
- **D-14:** Each adopting game passes its **minimum board height** at the
  adoption site:
  ```swift
  MinesweeperGameView()
      .videoModeAware(minBoardHeight: 480)
  ```
  The modifier compares available height to this floor and picks the
  compactness level (≥ floor → `.normal`; ≥ 0.85 × floor → `.collapsedSettings`;
  < 0.85 × floor → `.reducedTime`). Each game owns its own floor (Mines Medium
  ≠ Merge 4x4 ≠ Nonogram 10x10) — contract is explicit at the call site.
  Default floor (when caller omits) is documented in Claude's Discretion below.

### Cross-cutting & deconfliction

- **D-15:** The Phase 8 `08-HARD-MINES-ADR.md` smaller-cells contract is
  **untouched** by Phase 10. The existing `MagnifyGesture` + auto-scale
  `cellSize(forWidth:cols:padding:spacing:)` stack from Plan 06.1-03 /
  A11Y-05 stays byte-identical. The only Video-Mode-aware seam in Mines is
  `Self.minCellSize`, which becomes a `videoModeStore.isEnabled`-conditional
  lookup in Phase 11 — outside Phase 10's scope. Phase 10's modifier wraps
  `MinesweeperGameView` at the outermost layer (in Phase 11 adoption) and
  does NOT reach into the board-level `MagnifyGesture`.
- **D-16:** **SC5 stub = `#Preview` only.** Mirrors P9 D-04 — no DEBUG-only
  app screen, no HomeView dev hook, no trailing dev surface for P11/P12 to
  clean up. The `#Preview` block in `VideoModeAware.swift` renders a stub
  game view (board placeholder + `VideoCompactControlRow`) under all 6 PiP
  zones × Classic + Dracula presets. Verifies legibility per CLAUDE.md §8.12.

### Claude's Discretion

- Exact name of the ViewModifier — `videoModeAware` is the working name.
  Alternatives (`videoModeAdaptive` / `videoModeLayout`) considered during
  plan-phase if the working name conflicts with existing API.
- Exact name of the slot-router type — `VideoModeSlotRouter` working name.
- Exact final value of `largeBandFraction` — measured from P8 screenshots
  during plan-phase. Expected range 0.28–0.35. Locked once measured.
- Default value of `minBoardHeight` when caller omits — proposed `320pt`
  (smallest device safe minimum); revisit if any game needs a different floor.
- Compactness env key name — proposed `\.videoModeCompactness`.
- Exact `SlotAnchorMap` shape (named fields vs `[SlotID: Anchor]` dict) —
  planner picks based on call-site ergonomics. Either is fine.
- Whether `VideoModeSlotRouter` shares its anchor table with the future
  Phase 13 banner placement table (`08-BANNER-PLACEMENT.md`) — both encode
  "opposite-of-PiP" geometry. Phase 10 builds standalone; Phase 13 may
  refactor to share.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner) MUST read these before planning.**

### Phase 10 scope source

- `.planning/ROADMAP.md` §"Phase 10: Layout Primitives" — SC1–SC5 verbatim
- `.planning/REQUIREMENTS.md` VIDEO-05, VIDEO-06, VIDEO-13
- `.planning/PROJECT.md` §"Current Milestone: v1.2 Video Mode" — milestone
  framing + out-of-scope list
- `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` — milestone master plan;
  §"Core rule" (Small PiP = control-aware / Large PiP = board-aware),
  §"Layout behavior" (Small + Large rules), §"Compact control row"
  (slot order), §"Compromise order" (the 6 steps D-12 encodes)

### Locked design from Phase 8 (mandatory)

- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` — 6-zone
  per-game reposition tables; the slot-router data is derived from this doc
- `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` — token
  anchors the modifier respects when computing compact-row height
- `.planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md` —
  opposite-of-PiP anchor table; mirror geometry to D-12 slot-router, P13 consumer
- `.planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md` — D-15
  deconfliction contract; chosen smaller-cells variant + the untouched
  `MagnifyGesture` + auto-scale stack
- `.planning/phases/08-video-mode-design/08-DESIGN-LOCK.md` — Phase 8
  exit artifact; confirms Phase 10 inputs are stable

### Locked foundation from Phase 9 (mandatory)

- `.planning/phases/09-video-mode-foundation/09-CONTEXT.md` D-04 (#Preview
  stub pattern → D-16), D-05 (`@Observable` + custom EnvironmentKey → D-04),
  D-12 (`VideoCompactControlRow` composition → modifier reads its height),
  D-13 (token anchors → modifier respects), D-15 (off-state byte-identical
  → P10 SC3 supersedes per D-07)
- `gamekit/gamekit/Core/VideoModeStore.swift` — env-injected via
  `EnvironmentValues.videoModeStore`; primitive reads `isEnabled` + `location`
- `gamekit/gamekit/Core/VideoModeLocation.swift` — 6-case enum; slot-router
  switches over this exhaustively
- `gamekit/gamekit/Core/VideoCompactControlRow.swift` — compact-row primitive
  the modifier composes with (read for height anchor; do not modify)

### Band-sizing measurement source (D-09)

- `Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png` — primary
  measurement source for `largeBandFraction`
- `Docs/screenshots/v1.2-design/home-classic-pip-large-top.png` —
  cross-check / symmetry verification
- `Docs/screenshots/v1.2-design/README.md` — full 17-shot inventory with
  device + preset annotations

### Hard-Mines untouched contract (D-15)

- `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` — A11Y-05 /
  06.1-03 `MagnifyGesture` + auto-scale `cellSize` stack; P10 wraps Mines
  at the outermost layer in P11 and does NOT touch this file

### Cross-cutting rules

- `CLAUDE.md` §1 (Lightweight MVVM — primitive is a pure view modifier,
  no VM coupling), §2 (DesignKit token discipline; no new token
  speculatively introduced — D-10 keeps `largeBandFraction` private),
  §8.4 (verify tokens exist), §8.5 (file size cap — split if either P10
  file approaches 400 lines), §8.12 (theme audit on Classic + 1 Loud
  preset → SC5 #Preview matrix), §8.13 (status table updates if needed)

### Localization (none new)

Phase 10 introduces no user-facing strings — pure layout primitives + stub
`#Preview`. Phases 11–13 ship any new copy when they adopt.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`VideoModeStore` env-injected** (`Core/VideoModeStore.swift`) — primitive
  reads via `@Environment(\.videoModeStore)`. No new env key (D-04). Store
  is already `@Observable @MainActor`; SwiftUI re-renders on `isEnabled` or
  `location` change → off-restore reverts immediately without relaunch (SC3).
- **`VideoModeLocation` 6-case enum** (`Core/VideoModeLocation.swift`) — the
  slot-router's `anchors(for:)` switches over this exhaustively; new case
  = compile-time error in every adopter.
- **`VideoCompactControlRow`** (`Core/VideoCompactControlRow.swift`) — the
  compact-row primitive game views render below the band. The modifier
  reads its height (`theme.spacing.xl`) to compute available board height
  for compactness measurement (D-14). NO modification to this file in P10.
- **`SettingsStore` pattern** (`Core/SettingsStore.swift`) — established
  `@Observable` + env-key seam Phase 9 mirrored; Phase 10 modifier follows
  the same seam (read store via env, no @StateObject, no @EnvironmentObject).
- **GeometryReader pattern** — `VideoLocationPickerView` (Phase 9 07-PLAN)
  already uses `GeometryReader` to render the iPhone outline; same pattern
  the modifier uses to read screen height for D-08 / D-14.

### Established patterns

- **ViewModifier with private static constants** — DesignKit modifiers
  (`DKButton`, `DKCard`) use private static let for engine numbers
  not promoted to tokens. P10 follows this for `largeBandFraction` (D-10).
- **`@Environment(\.foo)` for env-driven config** — pattern used by every
  P9 surface; no @StateObject; no @EnvironmentObject (incompatible with
  `@Observable`, P4 RESEARCH Pitfall 1).
- **Pre-commit hook scope** — hook targets `Games/` + `Screens/` per
  CLAUDE.md §8.8. `Core/` is exempt — but token discipline carries.
  No hardcoded `cornerRadius:` or `padding(N)` integers in P10 code;
  `largeBandFraction` is a fraction, not a hardcoded points value.
- **`#Preview`-only SC satisfaction** — P9 D-04 locked this; P10 SC5
  inherits per D-16.

### Integration points

- **Adoption call site (P11/P12/P13 only)** — outermost layer of each
  game view:
  ```swift
  // P11 example
  MinesweeperGameView()
      .videoModeAware(minBoardHeight: 480)
  ```
  Phase 10 ships zero adoption — P10 commit touches only
  `Core/VideoModeAware.swift`, `Core/VideoModeSlotRouter.swift`, and the
  matching test files.
- **Slot-router consumer (P11/P12 only)** — game view reads
  `@Environment(\.videoModeStore)` + calls `VideoModeSlotRouter.anchors(for: store.location)`
  to know where its back / settings / FAB / picker anchor in this zone.
- **Compactness consumer (P11/P12 only)** — game view reads
  `@Environment(\.videoModeCompactness)` and adjusts its
  `VideoCompactControlRow` slot population (drop Settings into menu /
  hide time chip / etc.).
- **Hard-Mines `MinesweeperBoardView` boundary** — `MinesweeperGameView`
  is wrapped; `MinesweeperBoardView` (which holds the `MagnifyGesture`
  stack) is reached transitively but NOT modified by P10. Phase 11's
  `Self.minCellSize` change is the only board-level Video-Mode seam.

</code_context>

<specifics>
## Specific Ideas

- **Match P9 D-04 `#Preview`-only pattern for SC5 stub.** Consistency with
  P9; avoids leaving a dev-only screen P11/P12 has to clean up.
- **Document `largeBandFraction` with the P8 screenshot it was measured
  from.** Future-Claude (or future-Gabe) sees `0.30 // measured from
  Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png`
  and knows where to re-derive if needed.
- **Slot-router anchor data is the same geometry as P13 banner placement.**
  Both encode "opposite-of-PiP" rules. P10 builds standalone; Phase 13
  may refactor to share. Note for the planner: consider whether the
  `VideoModeSlotRouter` data type is general enough to absorb banner
  anchors later (cheaper now than refactoring at P13).
- **Hard short-circuit + `AnyView`** is a deliberate type-erasure cost
  trade. The off-path runs through a single `AnyView` wrap; the on-path
  doesn't matter (rare, on-screen feedback acceptable). Don't optimize
  this away — the simplicity of SC3 verification is the point.

</specifics>

<deferred>
## Deferred Ideas

- **DEBUG-only stub game screen in HomeView** — rejected by P9 D-04
  precedent (D-16). Revisit only if `#Preview` proves insufficient for
  SC5 verification.
- **Promote `.videoModeAware()` or `VideoModeSlotRouter` to DesignKit** —
  CLAUDE.md §2: needs 2+ consumers. v1.2 has 1 (this primitive). Revisit
  if a future GameKit milestone adds another use.
- **New DesignKit token `theme.spacing.video.bandHeight`** — same §2
  promotion rule blocks. D-10 keeps the constant private.
- **Vertical / portrait PiP layouts** — PROJECT.md v1.2 §Out of Scope;
  v1.3+ candidate.
- **Large left / large right PiP positions** — PROJECT.md v1.2 §Out of
  Scope.
- **Per-game compactness response variation beyond 3 levels** — P11/P12
  can extend the enum if a game needs `.minimal` or similar. Not adopted
  in P10 to keep the contract small.
- **PreferenceKey-based threshold publishing** — rejected in favor of
  direct modifier parameter (D-14). Revisit if call-site ergonomics
  become painful in P11/P12.
- **Sharing slot-router data with Phase 13 banner table** — possible
  refactor at P13; out of scope for P10.

</deferred>

---

*Phase: 10-layout-primitives*
*Context gathered: 2026-05-12*
