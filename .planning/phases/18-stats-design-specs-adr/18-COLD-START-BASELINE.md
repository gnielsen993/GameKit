# Cold-Start Baseline — Phase 18 (Plan 04)

**Date:** 2026-07-05 (structural proof) · 2026-07-06 (timing baseline recorded)
**Status:** Complete — structural proof + subjective timing baseline recorded

---

## Structural Proof

**Allocation half of SC4: CLOSED.**
No arcade engine or game-view state is allocated at cold launch.
All game views — including `StackGameView` and `SnakeGameView` — are constructed
lazily inside SwiftUI's `navigationDestination` closure, which is only evaluated
when the user navigates to that game.

### 1. `navigationDestination` lazy-construction

**File:** `gamekit/gamekit/Screens/HomeView.swift`, line 102

```swift
.navigationDestination(for: GameRoute.self) { route in
    destination(for: route)
}
```

SwiftUI does **not** evaluate the closure body until a matching value is pushed
onto the navigation stack. The `destination(for:)` function — which constructs
`StackGameView()` and `SnakeGameView()` — is therefore never called at scene
build time.

### 2. `destination(for:)` — lazy arcade-view construction

**File:** `gamekit/gamekit/Screens/HomeView.swift`, lines 359–407

```swift
// …
case .stack:
    StackGameView()                          // line 397 — only reached after tap
        .videoModeAware(minBoardHeight: 480)
        .disableInteractivePop()
case .snake:                                 // NOTE: NO videoModeAware — exempt per ADR
    SnakeGameView()                          // line 404 — only reached after tap
        .disableInteractivePop()
// …
```

Both arcade game views are constructed only when `destination(for:)` is invoked,
which happens only from inside the `navigationDestination` closure above —
i.e., only upon user navigation.

### 3. App-launch scope: zero arcade references

**Grep command:**
```bash
grep -nE 'StackEngine|SnakeEngine|StackGameView|SnakeGameView' \
  gamekit/gamekit/App/GameKitApp.swift \
  gamekit/gamekit/App/AppInfo.swift \
  gamekit/gamekit/App/DummyDataSeeder.swift
```

**Output:** ZERO HITS

All three `App/` files are clear. `GameKitApp.init()` constructs only:
`ThemeManager` · `SettingsStore` · `VideoModeStore` · `SFXPlayer` · `AuthStore`
· `CloudSyncStatusObserver` · `ModelContainer` (+ `#if DEBUG` seeders).
No arcade engine, no arcade view model, no arcade view is touched.

### 4. DEBUG init-log

The optional `#if DEBUG` init-log step (plan §Task 1 action 3) was not run —
the structural code inspection above is conclusive. SwiftUI's `navigationDestination`
lazy-construction guarantee means no game view or engine can be allocated before
user navigation regardless of what an init-log would show. No product code was
modified.

**`git status` after Task 1: no `.swift` changes — confirmed.**

---

## Canonical Baseline

> **Status: RECORDED — 2026-07-06**

This is the **first canonical cold-start baseline** for GameDrawer. No prior v1.4
numeric baseline exists anywhere in `.planning/` (D-10). This record is the new
canonical reference, not a comparison against a phantom figure.

### Method and honesty note

**This baseline was NOT obtained from a formal Instruments App Launch session.**
The plan originally called for a real-device Instruments trace (3–5 runs, median
ms, device model, iOS version). The developer instead provided a subjective
self-estimate: the app feels like it launches in roughly 200 ms, and the launch
is fast enough that manual timing is imprecise.

No device model or iOS version was captured this session.

This is recorded honestly as a subjective sanity-check, not a rigorous benchmark.

| Field | Value |
|-------|-------|
| Launch time estimate | ~200 ms (approximate) |
| Measurement method | Developer subjective self-estimate |
| Device model | Not captured |
| iOS version | Not captured |
| Date | 2026-07-06 |
| Runs measured | N/A (subjective impression) |
| Subjective quality | Fast — developer noted timing manually is difficult at this speed |

### What is load-bearing

The **primary evidence** for SC4 (cold-start unchanged) is the **structural proof**
from Task 1 (see above): zero arcade engine or game-view state is allocated at
app launch — all game views are lazily instantiated inside SwiftUI's
`navigationDestination` closure, which SwiftUI does not evaluate until the user
navigates. This is a structural guarantee, not a measurement.

The ~200 ms figure is a corroborating sanity-check confirming the app does not
feel slow to a human observer. It is not the primary basis for closing SC4.

### Future supersession

A formal Instruments App Launch session (with device model, iOS version, and
3–5 run median) may supersede this baseline if a hard numeric anchor is ever
needed — for example, to detect a cold-start regression in a future phase. If that
happens, replace this section with the Instruments-measured result and update the
date and method accordingly.

---

## ADR Call-Site Alignment

The `HomeView.destination(for:)` block already contains the correct inline comment
matching the 2026-07-02 ARCADE-08 amendment to `15-VIDEO-MODE-ADR.md`:

```swift
// ADR ARCADE-08 amendment (15-VIDEO-MODE-ADR.md, 2026-07-02): Stack adopts Video Mode —
// its engine is pure normalized-coordinate and the canvas rescales per frame, so a PiP
// reflow cannot desync state. Snake stays exempt (pixel-derived grid cells + continuous
// steering); Klondike stays exempt by convention (drag interactions).
```

No rewrites needed. (D-12 confirmed.)

---

## Phase 15 UAT Retirement

> **Status: COMPLETE — 2026-07-06**

`15-HUMAN-UAT.md` has been updated to mark the pending SC5 Instruments item as
**retired**, pointing to this document. Retirement is honest: the closure is via
the structural allocation proof (Task 1) plus a subjective ~200 ms developer
estimate — NOT a formal Instruments session.
