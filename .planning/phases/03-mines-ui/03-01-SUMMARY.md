---
phase: 03-mines-ui
plan: 01
subsystem: designkit-theme
status: complete
completed: 2026-04-26
duration_minutes: 8
tags:
  - swift
  - designkit
  - theme-tokens
  - color-blind-safety
  - xctest
  - wong-palette
requirements:
  - THEME-02
  - A11Y-04
dependency_graph:
  requires:
    - DesignKit Theme module (Tokens / PresetTheme / ColorDerivation / ThemeResolver)
    - DesignKit XCTest target (DesignKitTests.swift scaffold)
  provides:
    - "Theme.gameNumber(_:) extension on Theme — clamped 1...8 → Color"
    - "ThemeColors.gameNumberPalette: [Color] — length-8 per preset"
    - "ThemeColors.gameNumberPaletteWongSafe: [Color]? — D-15 override surface"
    - "PresetAnchors.gameNumberPalette + gameNumberPaletteWongSafe (resolver-fed)"
    - "ColorVisionSimulator helper — Brettel/Machado CVD + ΔE2000 (test-target)"
  affects:
    - "Plan 03-03 / 03-04 (Mines UI cell rendering) — consumes theme.gameNumber(n)"
tech_stack:
  added:
    - "Brettel/Vienot/Mollon (1997) severe-CVD matrix transforms"
    - "CIE ΔE2000 (Sharma 2005 reference implementation)"
    - "sRGB ↔ linear-RGB ↔ CIELab color-space pipeline"
  patterns:
    - "Additive token surface (defaults preserve source compat for all existing call sites)"
    - "Resolver-applied palette via PresetAnchors → ColorDerivation → ThemeColors"
    - "Wong-safe override pattern (loud preset opts in to a CVD-friendly fallback)"
key_files:
  created:
    - "../DesignKit/Sources/DesignKit/Theme/PresetTheme+GameNumberPalettes.swift (90 lines)"
    - "../DesignKit/Tests/DesignKitTests/Helpers/ColorVisionSimulator.swift (240 lines)"
    - "../DesignKit/Tests/DesignKitTests/ThemeGameNumberTests.swift (174 lines)"
    - "../DesignKit/Tests/DesignKitTests/GameNumberPaletteWongTests.swift (156 lines)"
  modified:
    - "../DesignKit/Sources/DesignKit/Theme/Tokens.swift (+19 lines — 2 new fields + init params)"
    - "../DesignKit/Sources/DesignKit/Theme/Theme.swift (+15 lines — gameNumber(_:) extension)"
    - "../DesignKit/Sources/DesignKit/Theme/PresetTheme.swift (+~50 lines — palette params on 6 audit-set anchors)"
    - "../DesignKit/Sources/DesignKit/Theme/ColorDerivation.swift (+18 lines — fallback palette + anchor forwarding)"
    - "../DesignKit/Sources/DesignKit/Theme/ThemeOverrides.swift (+2 lines — palette preservation)"
decisions:
  - "D-13 implemented: Theme.gameNumber(_:) clamps n to 1...8 and reads gameNumberPaletteWongSafe ?? gameNumberPalette"
  - "D-14 implemented: 6 audit-set presets ship distinct length-8 palettes; resolver fallback supplies Classic to undeclared presets"
  - "D-15 implemented: Wong audit enforced via XCTest at ΔE2000 ≥ 10 threshold under all three CVD simulations"
  - "D-16 implemented: token added to DesignKit; no DKNumberedCell component promoted (component stays in Games/Minesweeper/)"
  - "Classic palette entry 5 retuned from purple (#7B1FA2) → deep orange (#E65100) to satisfy Wong audit under protanopia"
  - "Classic palette entry 7 retuned from amber (#FFC107) → bright amber (#F9A825) to keep distinguishable from new orange under deuteranopia"
metrics:
  duration: "8 minutes"
  tasks: 2
  files_created: 4
  files_modified: 5
  test_cases_added: 11
  test_cases_total_pass: 30
---

# Phase 3 Plan 01: DesignKit `theme.gameNumber(_:)` Token + Wong Audit Summary

DesignKit gains a `theme.gameNumber(_ n: Int) -> Color` token clamped to 1...8 with per-preset 8-color palettes and an A11Y-04 Wong-palette XCTest contract (Brettel/Machado CVD simulation + CIE ΔE2000) — Classic passes unconditionally under all three CVDs; loud presets ship aesthetic defaults plus a `gameNumberPaletteWongSafe: [Color]?` override that falls back to Classic.

## Context

Wave 1 of Phase 3 lands the **token** that Plan 03 will consume — every Minesweeper adjacency-number cell reads `theme.gameNumber(cell.adjacentMineCount)` instead of a hand-coded palette, satisfying SC5 (zero `Color(...)` literals in `Games/Minesweeper/`). The contract is enforced by XCTest before the consumer ships, per PATTERNS §"Established pattern: Wong-audit XCTest" — note the target convention is XCTest (NOT Swift Testing — that critical correction was preserved through implementation).

## Files Created / Edited

### DesignKit (sibling repo at `../DesignKit/`)

| File | Lines | Disposition |
|------|-------|-------------|
| `Sources/DesignKit/Theme/Tokens.swift` | +19 / 102 total | EDIT — 2 new fields (`gameNumberPalette`, `gameNumberPaletteWongSafe`) + init params with defaults for source compat |
| `Sources/DesignKit/Theme/Theme.swift` | +15 / 53 total | EDIT — `func gameNumber(_:)` extension; clamps n to 1...8; defensive empty-palette fallback to `textPrimary` |
| `Sources/DesignKit/Theme/PresetTheme.swift` | +~50 / 843 total | EDIT — `PresetAnchors` gains optional palette + override fields; 6 audit-set presets forward palettes to anchors |
| `Sources/DesignKit/Theme/PresetTheme+GameNumberPalettes.swift` | 90 (NEW) | NEW — sibling extension hosting palette constants (split for readability; PresetTheme.swift was already 791 lines pre-edit, an out-of-scope baseline) |
| `Sources/DesignKit/Theme/ColorDerivation.swift` | +18 / 152 total | EDIT — `fallbackGameNumberPalette` constant + forwarding from `PresetAnchors` to `ThemeColors` so every resolved theme always emits length-8 |
| `Sources/DesignKit/Theme/ThemeOverrides.swift` | +2 / 148 total | EDIT — `applying(to:)` preserves palette through user-overrides |
| `Tests/DesignKitTests/Helpers/ColorVisionSimulator.swift` | 240 (NEW) | NEW — Brettel/Machado CVD matrices + CIE ΔE2000 + sRGB ↔ Lab pipeline + `Color` component extraction |
| `Tests/DesignKitTests/ThemeGameNumberTests.swift` | 174 (NEW) | NEW — 7 XCTest cases: clamp 1...8, length-8 palette via resolver (audit + fallback), override precedence, defensive empty fallback |
| `Tests/DesignKitTests/GameNumberPaletteWongTests.swift` | 156 (NEW) | NEW — 4 XCTest cases: Forest passes unconditionally (light + dark), every audit preset Wong-safe via resolver path, sRGB sanity gate |

All files <500 lines. ColorVisionSimulator.swift came in at 240 lines (the planned "<120" sketch was for a simpler ΔE76 variant; the full ΔE2000 reference impl alone is ~50 lines).

## Decision IDs implemented

- **D-13** — Token shape: `func gameNumber(_ n: Int) -> Color` clamping n to 1...8, reading `gameNumberPaletteWongSafe ?? gameNumberPalette`.
- **D-14** — Per-preset 8-color palette: Forest (Classic) ships the Wong-safe Minesweeper palette; bubblegum / barbie / cream / dracula / voltage ship aesthetic defaults tuned to the preset accent. All non-declared presets fall back to Classic via `ColorDerivation.fallbackGameNumberPalette`.
- **D-15** — Wong audit enforced unconditionally on Classic via `GameNumberPaletteWongTests.testForestPalettePassesAllThreeCVDsUnconditionally` (and under dark scheme via the parallel test). Loud presets ship `gameNumberPaletteWongSafe: classicGameNumberPalette` as override.
- **D-16** — Token added to DesignKit (per CLAUDE.md §2 "tokens go in DesignKit"); no `DKNumberedCell` component promoted (per "component used in 2+ games" rule).

## Requirement IDs satisfied

- **THEME-02** (partial) — Token landed and contract-tested. Plan 03-04 will verify Mines view consumes it (SC5 grep gate).
- **A11Y-04** (full) — Wong audit XCTest enforces ΔE2000 ≥ 10 across all 7 adjacent pairs under all 3 CVDs for every audit-set preset, via the production resolver path.

## Hex palettes shipped per preset

| Preset | Default palette (1–8) | Wong-safe override |
|--------|----------------------|--------------------|
| **forest (Classic)** | `#1976D2 #2E7D32 #D32F2F #212121 #E65100 #0097A7 #F9A825 #616161` | none — default IS the Wong-safe palette |
| **cream** | (reuses Classic) | none — Classic is Wong-safe |
| **bubblegum** | `#1565C0 #2E7D32 #C2185B #311B92 #6A1B9A #00838F #F57F17 #424242` | Classic |
| **barbie** | `#0D47A1 #1B5E20 #831843 #1A237E #4A148C #006064 #E65100 #3D0E28` | Classic |
| **dracula** | `#8BE9FD #50FA7B #FF5555 #BD93F9 #FF79C6 #F1FA8C #FFB86C #F8F8F2` | Classic |
| **voltage** | `#60A5FA #4ADE80 #FB7185 #A78BFA #F472B6 #22D3EE #FACC15 #F1F5F9` | Classic |

All other presets (28 outside the audit set) inherit Classic via the resolver fallback (`ColorDerivation.fallbackGameNumberPalette`).

## Wong-audit iteration outcomes

The XCTest forcing function surfaced a real failure in the original Classic palette and was used as designed (per plan: "the test is the forcing function"):

| Iteration | Failing pair | CVD | ΔE | Resolution |
|-----------|--------------|-----|-----|------------|
| 1 (initial) | (5, 6) = `#7B1FA2` purple ↔ `#0097A7` cyan | protanopia | 4.33 | Retuned entry 5 to deep orange `#E65100` (Wong-aligned vermillion-class hue). Entry 7 simultaneously bumped from `#FFC107` to `#F9A825` to keep amber distinguishable from new orange under deuteranopia. |
| 2 (final) | none | all three | all ≥ 10 | Forest passes unconditionally; loud presets pass via override → Classic. |

**Per CLAUDE.md §4 + plan instruction:** the threshold was NOT lowered. The palette was retuned to satisfy the requirement.

## Presets needing `gameNumberPaletteWongSafe` override

All four loud / bright presets (bubblegum, barbie, dracula, voltage) ship the Classic palette as `gameNumberPaletteWongSafe`. Their aesthetic defaults are *intended* to look on-brand under each preset's accent but their CVD-collapse risk wasn't worth verifying empirically per-preset for v1 — the override always passes, so SC5/A11Y-04 is satisfied via the resolver path regardless of the default palette's per-pair ΔE under CVD. If a future user-research pass reveals one of these defaults is actually Wong-safe in its native scheme, the override can be dropped.

## Wave 0 status (per `03-VALIDATION.md`)

**3 / 3 DesignKit Wave-0 files complete:**

- ✅ `Helpers/ColorVisionSimulator.swift` — Brettel/Machado matrices + ΔE2000 + sRGB extraction
- ✅ `ThemeGameNumberTests.swift` — clamp + length contract (7 cases, all pass)
- ✅ `GameNumberPaletteWongTests.swift` — A11Y-04 audit (4 cases, all pass; production resolver is the unit under test, not raw `PresetTheme` declarations — RESEARCH Pitfall 6)

**DesignKit test totals:** 30 cases, 0 failures. (19 pre-existing untouched + 11 added.)

## Verification

- `swift build` in `../DesignKit` → `Build complete!` (1.7s)
- `swift test` in `../DesignKit` → `Executed 30 tests, with 0 failures (0 unexpected) in 0.044 seconds`
- `Theme.resolve(preset: .forest, scheme: .light).gameNumber(1)` resolves to `#1976D2` (sanity-checked via `testGameNumberReturnsBlueForClassicOne`)
- `theme.colors.gameNumberPalette.count == 8` for every audit-set preset (verified by `testEveryAuditPresetEmitsLength8Palette`)
- Every `ThemePreset.allCases` member emits length-8 via fallback (verified by `testEveryPresetEmitsLength8PaletteViaResolverFallback`)
- Forest Wong audit unconditionally green under all three CVDs in both light and dark schemes
- Existing `testThemeResolverMatchesPaletteWithoutOverrides` (the 16-field round-trip suite) still passes — additive fields don't touch its assertion surface

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Missing critical functionality] `ThemeOverrides.applying(to:)` palette preservation**
- **Found during:** Task 1 build verification
- **Issue:** Original `applying(to:)` reconstructed `ThemeColors` via the public init. With the new fields added, the init defaults (`[]` and `nil`) would silently drop the base palette through any user-override path, breaking `Theme.gameNumber(_:)` for users with a custom theme.
- **Fix:** `applying(to:)` now explicitly forwards `base.gameNumberPalette` and `base.gameNumberPaletteWongSafe` so user-overrides preserve the per-preset palette.
- **Files modified:** `Sources/DesignKit/Theme/ThemeOverrides.swift`
- **Commit:** `82ffd5e` (Task 1)

**2. [Rule 3 — Blocking issue] `PresetTheme.swift` would have crossed 920 lines**
- **Found during:** Task 1 file-size sanity check
- **Issue:** Adding palette references to 6 preset declarations brought `PresetTheme.swift` from 791 → 919 lines. Pre-existing baseline already over 500-line cap, but adding ~130 lines worsens the violation.
- **Fix:** Extracted palette constants (`classicGameNumberPalette`, etc.) to a sibling extension file `PresetTheme+GameNumberPalettes.swift`. Final state: PresetTheme.swift at 843 lines (essentially baseline + minimal preset-anchor wiring), palettes isolated in a 90-line sibling file.
- **Files modified:** `Sources/DesignKit/Theme/PresetTheme.swift`, `Sources/DesignKit/Theme/PresetTheme+GameNumberPalettes.swift` (NEW)
- **Commit:** `82ffd5e` (Task 1)
- **Note:** PresetTheme.swift's 791-line pre-existing baseline is out of scope for this plan (executor scope-boundary rule). Splitting it further is a future refactor.

**3. [Rule 1 — Bug surfaced by Wong test] Classic palette entry 5 (purple) collapsed with cyan under protanopia**
- **Found during:** Task 2 first test run
- **Issue:** Forest palette pair (5, 6) = `#7B1FA2` (purple) / `#0097A7` (cyan) yielded ΔE2000 = 4.33 under protanopia simulation — well below the 10 threshold. Forest is the default first-launch preset; per D-15 it MUST pass unconditionally.
- **Fix:** Retuned entry 5 from `#7B1FA2` (purple) to `#E65100` (deep orange — Wong-aligned vermillion-class hue) and bumped entry 7 from `#FFC107` to `#F9A825` to keep amber distinguishable from the new orange under deuteranopia. Updated `ColorDerivation.fallbackGameNumberPalette` in lockstep so the resolver fallback stays consistent with `classicGameNumberPalette`.
- **Files modified:** `Sources/DesignKit/Theme/PresetTheme+GameNumberPalettes.swift`, `Sources/DesignKit/Theme/ColorDerivation.swift`
- **Commit:** `de1ccec` (Task 2)
- **Per plan:** "the executor's response: add a `gameNumberPaletteWongSafe`... or hand-tuned variant. This is the design-of-D-15 in action — the test is the forcing function." For Classic specifically, an override isn't an option (Classic IS the canonical safe palette), so the entries themselves were tuned. Threshold was NOT lowered.

### Authentication gates

None — pure DesignKit code edit + XCTest run, no external services.

## Commits (DesignKit repo)

- `82ffd5e` — `feat(03-01): add theme.gameNumber(_:) token + per-preset palettes` (Task 1; 6 files, +198/-16)
- `de1ccec` — `test(03-01): add gameNumber clamp + Wong-palette XCTest contracts` (Task 2; 5 files, +580/-5)

The GameKit repo carries only the SUMMARY/STATE/ROADMAP/REQUIREMENTS metadata commit (this plan modifies no GameKit source — DesignKit is a sibling repo per CLAUDE.md §2 "Sister projects in the same ecosystem").

## Self-Check: PASSED

- ✅ `Sources/DesignKit/Theme/Tokens.swift` exists (modified)
- ✅ `Sources/DesignKit/Theme/Theme.swift` exists (modified)
- ✅ `Sources/DesignKit/Theme/PresetTheme.swift` exists (modified)
- ✅ `Sources/DesignKit/Theme/PresetTheme+GameNumberPalettes.swift` exists (NEW)
- ✅ `Sources/DesignKit/Theme/ColorDerivation.swift` exists (modified)
- ✅ `Sources/DesignKit/Theme/ThemeOverrides.swift` exists (modified)
- ✅ `Tests/DesignKitTests/Helpers/ColorVisionSimulator.swift` exists (NEW)
- ✅ `Tests/DesignKitTests/ThemeGameNumberTests.swift` exists (NEW)
- ✅ `Tests/DesignKitTests/GameNumberPaletteWongTests.swift` exists (NEW)
- ✅ Commit `82ffd5e` exists in DesignKit repo
- ✅ Commit `de1ccec` exists in DesignKit repo
- ✅ `swift test` reports 30 / 30 passing
