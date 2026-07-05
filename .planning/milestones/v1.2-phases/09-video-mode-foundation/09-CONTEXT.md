# Phase 9: Video Mode Foundation - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship the plumbing every later v1.2 phase consumes: a `VideoModeStore` that
persists Off/On + selected location across launches, a Settings UI exposing the
toggle + 6-option picker + "manual selection only" copy, and a shared
`VideoCompactControlRow` component every game screen will adopt in later phases.
**No game layout changes** — system defaults to Off; existing Mines / Merge /
Nonogram layouts stay byte-identical when Video Mode is Off.

In scope: store + Settings UI + shared row component + at least one compiling
stub consumer of the row.
Out of scope: any game layout adaptation (Phase 10), per-game adoption
(Phase 11–12), banner replacement (Phase 13), auto-detection of another app's
PiP (deferred — no public iOS API).

</domain>

<decisions>
## Implementation Decisions

### Store architecture (locked from Phase 4 D-29 pattern)
- **D-05:** `VideoModeStore` mirrors `SettingsStore` shape verbatim —
  `@Observable` + `@MainActor` final class, custom `EnvironmentKey` injection,
  constructed once in `GameKitApp.init()`. Not `ObservableObject` / not
  `@EnvironmentObject` (incompatible with `@Observable` per P4 RESEARCH
  Pitfall 1). Per CLAUDE.md §1 "Lightweight MVVM" + ROADMAP SC1 mirror clause.
- **D-06:** Persistence = `UserDefaults.standard` (key-value, two fields:
  `gamekit.videoModeEnabled: Bool` + `gamekit.videoModeLocation: String`).
  Per CLAUDE.md §1 "UserDefaults acceptable for tiny key-value shapes."
  SwiftData reserved for stats only.
- **D-07:** Six-location vocabulary frozen from VIDEO-02:
  `largeTop | largeBottom | smallTopLeft | smallTopRight | smallBottomLeft | smallBottomRight`.
  Stored as the raw-string of an `enum VideoModeLocation: String, CaseIterable, Sendable`
  so the UserDefaults string round-trip is type-safe and exhaustive switches
  give compile-time coverage in downstream phases.

### Settings entry shape
- **D-01:** Main Settings adds a `VIDEO MODE` card directly after `APPEARANCE`.
  When Off, the card shows ONE row: `Video Mode [Off|On]` toggle.
  When On, the card adds ONE more row below the toggle: `Video location: <current label>`
  as a `NavigationLink` that pushes to a dedicated picker sub-screen.
  Pattern mirrors the `APPEARANCE` theme-picker convention (CLAUDE.md §2):
  inline summary + linked sub-screen for the full picker. Off state stays
  compact; main Settings never bloats with 6 picker rows.
- **D-08:** Picker sub-screen is `VideoLocationPickerView` under
  `Screens/VideoMode/` (new subdirectory). Toggle remains on main Settings
  — sub-screen is picker-only; toggling Off from main Settings makes the
  NavigationLink row disappear cleanly.

### Picker sub-screen UX
- **D-02:** The picker is **visual, not a radio list**. Render an iPhone
  outline (rounded-rect frame using `theme.radii.sheet` for the outer corner;
  inner playable area uses `theme.colors.surface`) with 6 tappable zones
  laid out per the VIDEO-02 vocabulary:
  - `Large top` = full-width band at top
  - `Large bottom` = full-width band at bottom
  - `Small TL / TR / BL / BR` = corner rects in the four quadrants
  The currently-selected zone fills with `theme.colors.accent` (low alpha) and
  shows the label **"Your video will go here"** centered inside it. Tapping a
  zone selects + persists immediately (no Apply button). Phase 13 banner work
  can reuse the iPhone-outline pattern.
- **D-09:** A11Y labels — every tappable zone has an accessibility label
  matching the design vocabulary ("Large top", "Small bottom-left", etc.) so
  VoiceOver users get an equivalent six-option picker without seeing the
  visual diagram. `accessibilityAddTraits: .isButton` + `accessibilityValue`
  reads the selected state.
- **D-10:** Below the iPhone outline: a single short paragraph with the
  VIDEO-14 "manual selection only" copy verbatim:
  > "Pick where your video is on screen — GameDrawer can't detect it
  > automatically. Choose the zone closest to your video to keep the
  > board and controls clear."
  Sourced from `Localizable.xcstrings` (zero hardcoded strings per FOUND-05).

### Defaults & first-toggle behavior
- **D-03:** First time the user flips Video Mode Off → On, the preselected
  location is **`largeBottom`**. Rationale: mirrors iOS native PiP's natural
  dock position and matches the Hard-Mines ADR squeeze case (locked
  `smaller-cells` from Phase 8 05-ADR), so the default exercises the
  worst-case layout path immediately rather than hiding it behind a corner
  PiP. User can pick a different zone on the picker sub-screen anytime.
- **D-11:** First toggle On does NOT auto-navigate to the picker. The
  "Video location: Large bottom" NavigationLink row simply appears below the
  toggle, and the user can tap it when they want to change. Avoids surprising
  navigation on a Settings toggle flip.

### Shared compact row component
- **D-12:** Component named `VideoCompactControlRow` (single SwiftUI view)
  lives at `gamekit/gamekit/Core/VideoCompactControlRow.swift`. Lives in
  `Core/` (not `Screens/`) because it's a cross-game primitive consumed by
  per-game views in Phase 11/12.
- **D-13:** Token usage locked from Phase 8 design corpus
  (`.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md`):
  pill corner = `theme.radii.button` (D-05 Phase 8), height anchor =
  `theme.spacing.xl` (D-06 Phase 8), inter-item gap = `theme.spacing.s`
  (D-07 Phase 8). Slot order = `Back | primary info | picker | secondary info | settings`.
  Zero hardcoded `cornerRadius:` / `padding(` integers — pre-commit hook
  enforces.
- **D-14:** Component API surface — parameterless slots OR small struct of
  views. The exact shape is **research-flagged** (gsd-phase-researcher should
  weigh `ViewBuilder` closures vs typed struct vs environment-injected slot
  binding before P9 plan-phase). Whatever shape is chosen MUST let Phase
  11/12 wrap an existing game view with minimal call-site code (Phase 10
  consumes this verdict for the `.videoModeAware()` shape).

### Stub call site (SC4 satisfaction)
- **D-04:** Stub = a single `#Preview` block at the bottom of
  `VideoCompactControlRow.swift` showing the component in all 3 game slot
  mappings (Mines / Merge / Nonogram per Phase 8 D-08). Compiles in the
  `gamekit` target = SC4 satisfied. No DEBUG-only screen, no HomeView dev
  preview — those leave a trail that Phase 11/12 has to clean up. Real
  per-game adoption happens in 11–12.

### Off-state byte-identical verification (SC5)
- **D-15:** SC5 ("with Video Mode Off, games render byte-identical to
  pre-v1.2") is verified by spawning the existing Mines / Merge / Nonogram
  game views with the Video Mode environment value injected at `.off`
  + selected location ignored. The store's `isOn` getter is the ONLY
  branch any game view consumes in P9. If a game view doesn't read
  `videoModeStore.isOn` at all yet, it's automatically byte-identical.
  Phase 11/12 introduce the actual reads.

### Claude's Discretion
- Localization key naming for the 6 location labels — Claude picks
  consistent `videoMode.location.{largeTop,largeBottom,smallTopLeft,…}`
  keys following the existing `xcstrings` naming pattern (Phase 1
  Localizable.xcstrings convention).
- Exact `iPhone-outline` aspect ratio + corner radius constants — Claude
  picks via `theme.radii.sheet` for the outer frame and an internal aspect
  matching iPhone 17 Pro Max screen ratio (≈19.5:9, the device CONTEXT D-04
  for Phase 8). No new tokens introduced.
- VoiceOver phrasing for the iPhone-outline diagram beyond the locked
  zone labels — Claude picks the surrounding container label
  ("Video location picker, choose where your video will appear").
- Whether the picker sub-screen also displays a tiny "Current: <label>"
  echo above the iPhone outline — Claude picks based on visual balance
  during plan-phase sketching.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner) MUST read these before planning.**

### Phase 9 scope source
- `.planning/ROADMAP.md` §"Phase 9: Video Mode Foundation" — SC1–SC5 verbatim
- `.planning/REQUIREMENTS.md` VIDEO-01, VIDEO-02, VIDEO-03, VIDEO-04, VIDEO-14
- `.planning/PROJECT.md` §"Current Milestone: v1.2 Video Mode" — overall
  milestone framing + out-of-scope list
- `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` — milestone master plan; §"Core rule"
  (Small PiP = control-aware / Large PiP = board-aware) and §"Compromise
  order" feed Phase 10/11 but inform Phase 9's API shape (D-14)

### Locked design from Phase 8 (mandatory)
- `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` — token
  anchors (radii.button / spacing.xl / spacing.s) + per-game slot mapping.
  D-13 is verbatim from this doc.
- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` — 6-zone PiP
  vocabulary; Phase 9 just persists/exposes these, doesn't redefine them
- `.planning/phases/08-video-mode-design/08-CONTEXT.md` D-05..D-08 — origin of
  the token decisions D-13 carries forward
- `.planning/phases/08-video-mode-design/08-DESIGN-LOCK.md` — Phase 8 exit
  artifact; confirms Phase 9 is unblocked

### Locked store pattern from Phase 4 (mandatory)
- `gamekit/gamekit/Core/SettingsStore.swift` — exact `@Observable` +
  custom `EnvironmentKey` shape D-05 mirrors. Lines 35-50 in the file
  header doc-comment spell out the four invariants Phase 9 inherits.
- `.planning/phases/04-stats-persistence/04-CONTEXT.md` §D-29 — the original
  decision that locked the pattern

### Threat / a11y / theming cross-cutting rules
- `CLAUDE.md` §1 (stack constraints — UserDefaults OK for tiny KV),
  §2 (DesignKit tokens, theme picker UX convention),
  §8.4 (verify tokens exist before using),
  §8.12 (game-screen theme audit rule — applies to picker sub-screen)
- `gamekit/gamekit/Screens/SettingsView.swift` — existing card structure
  (APPEARANCE / HAPTICS / DATA / ABOUT). Phase 9 inserts VIDEO MODE between
  APPEARANCE and HAPTICS.
- `gamekit/gamekit/App/GameKitApp.swift` — where `SettingsStore`,
  `AuthStore`, and the new `VideoModeStore` are constructed at startup +
  injected via custom EnvironmentKeys

### Localization
- `gamekit/gamekit/Resources/Localizable.xcstrings` — destination for the
  VIDEO-14 "manual selection only" copy + 6 location labels (D-10)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets
- **`SettingsStore` pattern** (`gamekit/gamekit/Core/SettingsStore.swift`) —
  Phase 9's `VideoModeStore` is structurally identical: `@Observable @MainActor
  final class`, `var x: Bool { didSet { userDefaults.set(...) } }`, custom
  `EnvironmentKey` with a default in `EnvironmentValues`. Copy/adapt directly.
- **`SettingsStoreFlagsTests`** (`gamekit/gamekitTests/Core/`) — proven test
  pattern: in-memory UserDefaults suite for round-trip + default-value
  coverage. `VideoModeStore` tests follow this shape.
- **Localizable.xcstrings catalog** — already exists with Phase 1+ keys; add
  new `videoMode.*` keys here, not in a new catalog.
- **`SettingsView` card structure** — existing Section/Row pattern works for
  the new VIDEO MODE card; no new layout primitives needed in P9.

### Established patterns
- **Store injection** — Custom EnvironmentKey + `.environment(\.fooStore, ...)`
  at App-level. `@EnvironmentObject` is INCOMPATIBLE with `@Observable` types;
  Phase 4 D-29 anti-pattern locked.
- **Theme audit on new Settings rows** — CLAUDE.md §8.12 says verify on
  Classic + one Loud preset. Picker sub-screen iPhone-outline needs the same
  audit (D-02 locks).
- **No hardcoded sizes** — Pre-commit hook rejects literal `cornerRadius:` /
  `padding(N)` in `Games/` + `Screens/`. Picker sub-screen lives in
  `Screens/VideoMode/`, so the hook applies. Component lives in `Core/` —
  hook doesn't apply there, but discipline carries.

### Integration points
- **`GameKitApp.init()`** — adds `let videoModeStore = VideoModeStore()` and
  passes via `.environment(\.videoModeStore, videoModeStore)` on the root
  scene's view tree. Inject ONCE; downstream phases read via
  `@Environment(\.videoModeStore)`.
- **`SettingsView` body** — adds the VIDEO MODE card between APPEARANCE and
  HAPTICS. Uses existing card / section conventions; no new container view.
- **`Screens/VideoMode/VideoLocationPickerView.swift`** (new) — the only
  brand-new screen Phase 9 ships. Wired via `NavigationLink` from
  `SettingsView`.

</code_context>

<specifics>
## Specific Ideas

- **iPhone outline picker** is the design hook for the entire v1.2
  milestone — same outline pattern shows up in Phase 13 banner-placement
  preview if useful. Reusable but not extracted to DesignKit yet (CLAUDE.md
  §2 — promote only when used in 2+ places).
- **"Your video will go here" label** is the discoverability hook — directly
  addresses the VIDEO-14 "manual selection only" UX gap without a separate
  tooltip or info icon.

</specifics>

<deferred>
## Deferred Ideas

- Auto-detection of another app's PiP frame — no public iOS API; permanently
  deferred (PROJECT.md v1.2 Out of Scope).
- Promote iPhone-outline picker pattern to DesignKit — wait for second
  consumer (likely Phase 13 banner-placement preview); CLAUDE.md §2 promotion
  rule.
- Live `ModelConfiguration` reconfiguration for the VideoModeStore key —
  not needed (UserDefaults reads are live, no container rebuild).

</deferred>

---

*Phase: 09-video-mode-foundation*
*Context gathered: 2026-05-12*
