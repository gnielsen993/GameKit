# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `01-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 01-foundation
**Areas discussed:** Shell scope, DesignKit linking, iCloud capability

---

## Shell Scope

### Q1: Which shell screens exist in P1?

| Option | Description | Selected |
|--------|-------------|----------|
| Home only | Just HomeView with the Minesweeper card. Settings + Stats arrive in P5 / P4. | |
| Home + nav targets stubbed | HomeView + minimal SettingsView + StatsView stubs (empty states only) wired into NavigationStack. | ✓ |
| Full skeleton incl. IntroFlow | Home + Settings stub + Stats stub + IntroFlow stub. | |

**User's choice:** Home + nav targets stubbed
**Notes:** Catches token-discipline regressions on more screens earlier without committing to full P5 surface.

---

### Q2: How does Home reach Settings/Stats?

| Option | Description | Selected |
|--------|-------------|----------|
| TabView (Home/Stats/Settings) | Three-tab root. Each tab owns its own NavigationStack. | ✓ |
| NavigationStack + toolbar buttons | Single NavigationStack rooted at Home; Settings/Stats reached via toolbar items. | |
| NavigationStack + Settings as sheet | Game push uses NavigationStack; Settings opens as sheet. | |

**User's choice:** TabView (Home/Stats/Settings)
**Notes:** iOS-canonical for utility apps. Mines game push happens inside Home tab.

---

### Q3: Disabled future-game cards — which games shown?

| Option | Description | Selected |
|--------|-------------|----------|
| All 8 from PROJECT vision | Merge, Word Grid, Solitaire, Sudoku, Nonogram, Flow, Pattern Memory, Chess puzzles. | ✓ |
| Next 2-3 only | Merge + Word Grid + Solitaire. | |
| None — Mines card alone | Disabled placeholders deferred until game 2 lands. | |

**User's choice:** All 8 from PROJECT vision
**Notes:** Signals full long-term suite. Mirrors PROJECT.md exactly.

---

### Q4: What's in the Settings + Stats stubs?

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit empty-state copy | "Settings coming soon" / "No games played yet." | |
| Themed scaffold only | Section headers and DKCard skeletons with no content. | ✓ |
| Empty NavigationStack root | Just nav title + spacer. | |

**User's choice:** Themed scaffold only
**Notes:** Pre-shapes P4/P5 layout, gives more token surface to legibility-test.

---

### Q5: IntroFlow plumbing in P1?

| Option | Description | Selected |
|--------|-------------|----------|
| Defer entirely to P5 | No intro plumbing in P1. SHELL-04 is owned by P5. | ✓ |
| Add hasSeenIntro flag only | SettingsStore persists `hasSeenIntro` from P1 even though no intro renders. | |
| Stub IntroFlowView + wire | Empty IntroFlowView shown on first launch with Skip. | |

**User's choice:** Defer entirely to P5
**Notes:** Cleanest P1 scope.

---

### Q6: Disabled card tap behavior?

| Option | Description | Selected |
|--------|-------------|----------|
| No-op + reduced opacity | Tap does nothing, dimmed card + lock badge. | |
| Tap shows 'coming soon' toast | Tap surfaces brief overlay. | ✓ |
| Card not tappable at all | `.allowsHitTesting(false)`, dimmed styling. | |

**User's choice:** Tap shows 'coming soon' toast
**Notes:** Discoverability over silence.

---

## DesignKit Linking

### Q1: How to link the local DesignKit SPM dep?

| Option | Description | Selected |
|--------|-------------|----------|
| Xcode Add Package → Add Local | Right-click project → Add Package Dependencies → Add Local → ../DesignKit. | ✓ |
| Convert to .xcworkspace | Workspace containing both gamekit.xcodeproj and ../DesignKit/Package.swift. | |
| Top-level Package.swift wrapper | Repo-root Package.swift depending on DesignKit via path. | |

**User's choice:** Xcode Add Package → Add Local
**Notes:** Simplest. Works with the current `.xcodeproj`.

---

### Q2: DesignKit version pinning?

| Option | Description | Selected |
|--------|-------------|----------|
| Local path — no version | Tracks whatever ../DesignKit has on disk. | ✓ |
| Local path + main branch lock | Path dep with CI/script check that ../DesignKit is on main. | |
| Eventually swap to git URL + tag | Future post-v1 plan. | |

**User's choice:** Local path — no version
**Notes:** Edits flow back to siblings per CLAUDE.md §2. Accepted ripple risk.

---

### Q3: Build cache / clean-build risk in P1?

| Option | Description | Selected |
|--------|-------------|----------|
| Document derived-data hygiene | Add Docs/ note. No automation. | ✓ |
| Script: clean DerivedData on switch | Repo-tracked `scripts/clean-build.sh`. | |
| Skip — not P1 concern | Defer until it bites. | |

**User's choice:** Document derived-data hygiene
**Notes:** Lightweight; script can be promoted later if pain shows up.

---

## iCloud Capability

### Q1: When to provision iCloud entitlement + container?

| Option | Description | Selected |
|--------|-------------|----------|
| P1 — entitlement + container ID, sync OFF | Add iCloud capability + container ID in P1. ModelContainer config stays `.none` until P6. | |
| P1 — ID only in PROJECT.md, capability at P6 | Pin ID in docs now; add capability at P6. | ✓ |
| Full defer to P6 | No iCloud touch in P1 at all. | |

**User's choice:** P1 — ID only in PROJECT.md, capability at P6
**Notes:** Avoids provisioning profile churn pre-Mines while still locking the ID per PITFALLS Pitfall 3.

---

### Q2: ModelContainer in P1?

| Option | Description | Selected |
|--------|-------------|----------|
| No ModelContainer in P1 | SwiftData not touched until P4. | ✓ |
| Empty ModelContainer scaffolded | Container with empty schema [] in App/, configured `.none`. | |
| Smoke-test container (no @Models) | Test-target-only container with `.private(…)` config. | |

**User's choice:** No ModelContainer in P1
**Notes:** Keeps P1 a pure shell phase.

---

### Q3: Cold-start (<1s) verification in P1?

| Option | Description | Selected |
|--------|-------------|----------|
| Manual stopwatch + Instruments App Launch | Verify on simulator + iPhone SE-class hardware. | |
| os_signpost in App init | Repeatable measurement via Instruments. | |
| Defer to P5/P7 audit | FOUND-01 verified at P5 polish + P7 release gate. | ✓ |

**User's choice:** Defer to P5/P7 audit
**Notes:** Mitigation = keep P1 surface trivially small.

---

## Claude's Discretion

The user did not lock these — captured in `01-CONTEXT.md` `<decisions>` § "Claude's Discretion":

- Pre-commit hook mechanism (raw shell + `scripts/install-hooks.sh` recommended)
- Localization scaffold (single `Localizable.xcstrings` in `Resources/` recommended)
- Placeholder app icon (flat DesignKit-color asset, baked at design time)
- `ThemeManager` construction site (`@StateObject` in `GameKitApp` per ARCHITECTURE.md)
- Default initial preset (Classic category default member)
- Swift 6 strict concurrency setting (`SWIFT_STRICT_CONCURRENCY = complete`)

## Deferred Ideas

- `hasSeenIntro` flag + IntroFlow → fully P5 (SHELL-04)
- Pre-build smoke-test ModelContainer → P4 mitigation for PITFALLS Pitfall 2
- iCloud entitlement / provisioning profile → P6
- `os_signpost` cold-start instrumentation → P5/P7 audit
- Build cache automation script → only if manual ritual gets painful
- Swap to git URL + tag for DesignKit → post-v1
