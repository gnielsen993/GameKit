# Phase 10: Layout Primitives - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-12
**Phase:** 10-layout-primitives
**Areas discussed:** API shape, Off-restore mechanism, Large-PiP band sizing, Compromise order surface

---

## Adoption API shape (SC4)

### Q1 — Which API shape should P11/P12 use to adopt the primitives?

| Option | Description | Selected |
|--------|-------------|----------|
| `.videoModeAware()` ViewModifier | Single chainable modifier on any View. Adoption: `MinesweeperGameView().videoModeAware()`. Minimal call-site, idiomatic SwiftUI. | ✓ |
| `VideoModeContainer { ... }` wrapper view | Explicit container takes board + compact-row as slots. More invasive — game view must split into slots. | |
| Slot-based `VideoModeLayout(board:controls:)` | Flat layout takes 6 closures and routes each to right anchor per zone. Heavy call-site. | |
| Pair of small modifiers | Split into `.videoModeBoardAware()` + `.videoModeControlsAware()`. Doubles SC3 surface area. | |

**User's choice:** `.videoModeAware()` ViewModifier.
**Notes:** Locks the simplest one-line adoption shape for P11/P12/P13.

### Q2 — Slot reposition: modifier or game view?

| Option | Description | Selected |
|--------|-------------|----------|
| Game view reads env, routes slots itself | Modifier handles container concerns; game view rearranges slots via shared helper. Requires `VideoModeSlotRouter` to avoid drift. | ✓ |
| Modifier provides routing via Environment | Modifier publishes derived anchor values into env; game reads named anchors. Env namespace bloat. | |
| Shared `SlotRouter` struct + modifier reads it | Pure function consumed by both. Extra layer. | |

**User's choice:** Game view reads env and routes slots itself.
**Notes:** A shared `VideoModeSlotRouter` pure helper is required to prevent the 3 games from drifting.

### Q3 — Where do the 2 new P10 files live?

| Option | Description | Selected |
|--------|-------------|----------|
| Flat in `Core/` alongside P9 files | Add `VideoModeAware.swift` + `VideoModeSlotRouter.swift` as siblings to existing P9 files. Consistent with P9 layout. | ✓ |
| Move all video-mode files into `Core/VideoMode/` subdir | Cleaner namespace but rewrites P9-shipped commits. | |
| Only the 2 new files go in `Core/VideoMode/` | Half-and-half split. Inconsistent. | |

**User's choice:** Flat in `Core/`.
**Notes:** User asked for clarification on what the file layout question meant before answering. Assistant clarified: 2 new files total for Phase 10 (not per view); game views modified in P11/P12, not here.

### Q4 — What does `.videoModeAware()` read from environment?

| Option | Description | Selected |
|--------|-------------|----------|
| Reads `VideoModeStore` directly | Single env key, consistent with rest of codebase. | ✓ |
| Reads two scalar env values | `\.videoModeEnabled` + `\.videoModeLocation` separately. Duplicate source-of-truth. | |
| Takes `location` as a parameter | Trivially testable, but every adoption site must pull from env first. | |

**User's choice:** Reads `VideoModeStore` directly.

---

## Off-restore mechanism (SC3 / VIDEO-13)

### Q1 — How does `.videoModeAware()` restore the baseline when `isEnabled==false`?

| Option | Description | Selected |
|--------|-------------|----------|
| Hard short-circuit — return content verbatim | `if !store.isEnabled { return AnyView(content) }`. Off-path = zero changes. | ✓ |
| Pass-through with zero offsets | Always wrap; offsets evaluate to 0 when off. Extra view nodes on off-path. | |
| Conditional wrap at call site | `gameView.if(store.isEnabled) { $0.videoModeAware() }`. Pushes check to every adoption site. | |
| Two-modifier split | Ship `.videoModeAware()` + `.videoModeAwareLarge()` separately. Doubles SC3 surface. | |

**User's choice:** Hard short-circuit.

### Q2 — SC3 verification approach

| Option | Description | Selected |
|--------|-------------|----------|
| Swift Testing unit test + manual spot-check | Matches P9 SC5 verification pattern from `09-VALIDATION.md`. | ✓ |
| Snapshot test against baseline build | Rigorous but flaky on SwiftUI. P9 didn't adopt them. | |
| Manual-only checkpoint (no automated test) | Regression-prone. | |

**User's choice:** Swift Testing unit test + manual spot-check.

### Q3 — Relationship to P9 D-15 / SC5 off-state contract

| Option | Description | Selected |
|--------|-------------|----------|
| P10 SC3 supersedes P9 SC5 for adopted games | Once a game adopts `.videoModeAware()`, P10 owns the off-restore contract. | ✓ |
| Keep them separate | Both checks survive; future regressions surface at the right phase. | |
| Punt to P11/P12 SC5 per-game off-restore checks | P10 only proves stub; per-game checks live in adoption phases. | |

**User's choice:** P10 SC3 supersedes P9 SC5 for adopted games.

---

## Large-PiP reserved band sizing (SC2)

### Q1 — How is band height determined?

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed percent of screen height | Via `GeometryReader`. Scales to any device. | ✓ |
| Screenshot-derived constant + per-device scale | Measure P8 screenshot, derive ratio constant. | |
| New DesignKit token | Violates CLAUDE.md §2 promotion rule (1 consumer). | |
| `GeometryReader`-driven `safeAreaInset` | Idiomatic, but still needs the points value (sub-decision). | |

**User's choice:** Fixed percent of screen height.

### Q2 — Where does the constant live? And is 33% right?

| Option | Description | Selected |
|--------|-------------|----------|
| Private static on `VideoModeAware` modifier | Single source of truth, easy to grep, tunable. | |
| Measure P8 screenshots first, lock the ratio | Tied to real-world evidence (Phase 8 design corpus). | ✓ |
| Start at 0.33, tune in P11 Hard-Mines validation | Defer measurement to Phase 11. | |

**User's choice:** Measure P8 screenshots first.
**Notes:** Plan task measures band height in `home-classic-pip-large-bottom.png` + `home-classic-pip-large-top.png` against iPhone 17 Pro Max screen height. Constant still lives as a private static on `VideoModeAware` per the standard pattern (D-10).

### Q3 — Does the modifier do anything for the BOARD on Small zones?

| Option | Description | Selected |
|--------|-------------|----------|
| Pure controls-routing — modifier no-op on board | P8 evidence (4-corner Hard Dracula set) proves board fits at normal size on every Small zone. | ✓ |
| Insert corner `safeAreaInset` for small PiP footprint | Defensive; would shrink the board unnecessarily. | |
| Conditional — only on Hard Mines, only when squeeze detected | Speculative; no evidence shows it's needed. | |

**User's choice:** Pure controls-routing.

---

## Compromise order surface

### Q1 — Where does Compromise order logic live?

| Option | Description | Selected |
|--------|-------------|----------|
| Encoded in the primitive — auto-applies based on height | Primitive measures + publishes; heavy primitive but consistent across games. | ✓ |
| Surfaced as `@Environment(\.videoModeCompactness)` enum, game applies | Separation; primitive measures, game reacts. | |
| Hand-applied per game in P11/P12 | Simplest P10 scope but duplication risk. | |
| Defer to Phase 11+ | Tightest scope; P11 Hard-Mines needs it from day one though. | |

**User's choice:** Encoded in the primitive.
**Notes:** Resolution combines elements of options A and B — primitive measures available height and publishes a `VideoModeCompactness` enum via env, game views read and react. Documented in D-12.

### Q2 — Which compactness levels?

| Option | Description | Selected |
|--------|-------------|----------|
| 3 levels: `normal` / `collapsedSettings` / `reducedTime` | Maps plan-doc steps 1–3 / 4 / 5. Step 6 board-shrink handled by Hard-Mines ADR (Phase 11). | ✓ |
| 4 levels: `normal` / `dense` / `compact` / `minimal` | Abstract scale; less testable. | |
| Boolean: `standard` / `compact` | Blunt; can't drop just one chip. | |

**User's choice:** 3 levels.

### Q3 — How does primitive decide which level to publish?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-game height thresholds passed into modifier | `.videoModeAware(minBoardHeight: 480)`. Each game owns its floor. | ✓ |
| Single global threshold table | Same thresholds for every game. Mines Hard ≠ Merge ≠ Nonogram floors. | |
| Each game publishes via env preference | `PreferenceKey` declarative — timing is subtle, risks layout thrash. | |

**User's choice:** Per-game thresholds passed into modifier.

---

## Claude's Discretion

Areas where the user deferred to Claude during the discussion:

- Exact name of the ViewModifier (`videoModeAware` working name)
- Exact name of the slot-router type (`VideoModeSlotRouter` working name)
- Default `minBoardHeight` value when caller omits (proposed 320pt)
- `SlotAnchorMap` shape (named fields vs dict)
- Compactness env key name (`\.videoModeCompactness` proposed)
- Whether the `SlotRouter` shares its anchor table with the P13 banner placement table

## Deferred Ideas

Ideas mentioned during discussion that were noted for future phases:

- DEBUG-only stub game screen in HomeView (revisit only if `#Preview` fails SC5)
- Promote `.videoModeAware()` or `VideoModeSlotRouter` to DesignKit (needs 2+ consumers)
- New DesignKit token `theme.spacing.video.bandHeight` (same §2 promotion rule)
- Vertical / portrait PiP layouts (PROJECT.md v1.2 out of scope)
- Large left / large right PiP positions (same)
- Per-game compactness response variation beyond 3 levels (P11/P12 extend if needed)
- PreferenceKey-based threshold publishing (revisit if direct param ergonomics fail)
- Sharing slot-router data with Phase 13 banner anchor table (refactor at P13)
