# Cold-Start Baseline — Phase 18 (Plan 04)

**Date:** 2026-07-05
**Status:** Structural proof complete · Canonical timing baseline PENDING (Task 2 blocking checkpoint)

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

> **Status: PENDING — blocking human-verification checkpoint (Task 2)**

This section will be filled in after the real-device Instruments App Launch
session (Task 2). The session records the **first canonical cold-start baseline**
for GameDrawer — no prior v1.4 numeric baseline exists anywhere in `.planning/`
(D-10). The result is the new canonical number, not a comparison against a
phantom figure.

Fields to be recorded:

| Field | Value |
|-------|-------|
| Median launch time (ms) | PENDING |
| Device model | PENDING |
| iOS version | PENDING |
| Date of session | PENDING |
| Runs measured | PENDING |
| Subjective quality | PENDING |

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

> **Status: PENDING — will be recorded when Task 2 completes.**

Once the timing half is closed, `15-HUMAN-UAT.md` will be updated to mark
the pending SC5 Instruments item as **retired**, pointing to this document.
