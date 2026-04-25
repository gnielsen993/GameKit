---
phase: 01-foundation
plan: 07
subsystem: ui
tags: [swiftui, tabview, designkit-tokens, home-screen, shell, coming-soon-overlay, theme-legibility]

# Dependency graph
requires:
  - phase: 01-06-app-scene
    provides: ThemeManager @StateObject + RootTabView stub wired into GameKitApp

provides:
  - RootTabView 3-tab shell (Home / Stats / Settings) with .tint(accentPrimary)
  - HomeView with 9 game cards — Minesweeper enabled, 8 future-game placeholders disabled with lock badges
  - ComingSoonOverlay capsule toast (sparkles icon, auto-dismisses after 1.8 s) on disabled-card tap
  - Minesweeper placeholder push destination ("Coming in Phase 3")
  - SettingsView and StatsView themed scaffold stubs with placeholder copy
  - SettingsComponents free @ViewBuilder helpers (settingsSectionHeader, settingsNavRow)

affects: [01-08-localization-catalog, 03-mines-ui, 04-stats-persistence, 05-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - NavigationStack owned by each tab's root view (not by RootTabView) per ARCHITECTURE.md Anti-Pattern 3
    - GameCard struct as local Identifiable+Equatable data model for home card list
    - ComingSoonOverlay driven by optional GameCard state + Task sleep auto-dismiss
    - settingsSectionHeader / settingsNavRow as free @ViewBuilder functions (not promoted to DesignKit — single-game usage)

key-files:
  created:
    - gamekit/gamekit/Screens/SettingsComponents.swift
    - gamekit/gamekit/Screens/ComingSoonOverlay.swift
    - gamekit/gamekit/Screens/SettingsView.swift
    - gamekit/gamekit/Screens/StatsView.swift
    - gamekit/gamekit/Screens/HomeView.swift
  modified:
    - gamekit/gamekit/Screens/RootTabView.swift

key-decisions:
  - "NavigationStack inside each tab root (HomeView/StatsView/SettingsView), NOT in RootTabView — avoids Anti-Pattern 3 from ARCHITECTURE.md"
  - "ComingSoonOverlay uses radii.chip (smallest token) as specified by D-06; 1.8s auto-dismiss via Task.sleep"
  - "GameCard model stays local to HomeView.swift — single-use, no DesignKit promotion"
  - "Disabled cards show 60% opacity + lock SF Symbol; overlay uses sparkles SF Symbol per D-06"
  - "Theme legibility verified on Voltage (Loud) and a Soft preset — no bleedthrough; all tokens correct"

patterns-established:
  - "Theme injection via @EnvironmentObject themeManager + @Environment(colorScheme) + computed theme property in every screen"
  - "Every visible string uses String(localized:) form — localizable string catalog extraction ready for Plan 08"
  - "Placeholder copy in stub screens per CLAUDE.md §8.3 (never blank cards)"
  - "Pre-commit hook passes on all 6 Screens/ files — no Color literals, no numeric radii/padding"

requirements-completed:
  - FOUND-03
  - SHELL-01

# Metrics
duration: 2h (Tasks 1+2 automated; Task 3 manual verification by user)
completed: 2026-04-25
---

# Phase 1 Plan 07: Shell Screens Summary

**3-tab TabView shell (Home / Stats / Settings) with 9 DesignKit-token-pure game cards, ComingSoonOverlay toast on disabled-card tap, and theme legibility verified on Voltage and Soft presets**

## Performance

- **Duration:** ~2 hours
- **Started:** 2026-04-25 (after Plan 06)
- **Completed:** 2026-04-25
- **Tasks:** 3 (2 automated + 1 human-verify checkpoint, user-approved)
- **Files modified:** 6

## Accomplishments

- Created 6 Swift files under `gamekit/gamekit/Screens/` — all under 250 lines, all passing the pre-commit hook
- HomeView renders Minesweeper as the only enabled card (chevron icon, full opacity) + 8 future-game placeholders (lock icon, 60% opacity) in PROJECT.md vision order
- ComingSoonOverlay capsule (sparkles + game title + auto-dismisses after 1.8 s) fires on disabled card tap
- Tapping Minesweeper pushes to a token-styled "Coming in Phase 3" placeholder within the Home tab's own NavigationStack
- SettingsView and StatsView scaffold stubs render section headers + DKCard skeletons with intentional placeholder copy (never blank)
- Theme legibility checkpoint passed: user verified Voltage (Loud) and a Soft preset — no bleedthrough, lock icons readable, overlay readable, all tab content visible

## Task Commits

1. **Task 1: Supporting screens (SettingsComponents, ComingSoonOverlay, SettingsView, StatsView)** - `dd66b7b` (feat)
2. **Task 2: HomeView + RootTabView 3-tab expansion** - `5ccf7f7` (feat)
3. **Task 3: Human verify — theme legibility + UI checks** - Approved by user (no code commit; temporary .onAppear reverted before Task 2 commit)

## Files Created/Modified

- `gamekit/gamekit/Screens/SettingsComponents.swift` — settingsSectionHeader + settingsNavRow free @ViewBuilder helpers
- `gamekit/gamekit/Screens/ComingSoonOverlay.swift` — floating capsule with sparkles SF Symbol, radii.chip, auto-dismiss
- `gamekit/gamekit/Screens/SettingsView.swift` — themed scaffold stub with APPEARANCE + ABOUT sections
- `gamekit/gamekit/Screens/StatsView.swift` — themed scaffold stub with HISTORY + BEST TIMES sections
- `gamekit/gamekit/Screens/HomeView.swift` — 9 game cards, enabled/disabled states, ComingSoonOverlay state, NavigationStack, Minesweeper placeholder destination
- `gamekit/gamekit/Screens/RootTabView.swift` — replaced Plan 06 stub with full 3-tab TabView; .tint(theme.colors.accentPrimary)

## Decisions Made

- NavigationStack lives inside each tab's root view (HomeView / StatsView / SettingsView), not in RootTabView — avoids ARCHITECTURE.md Anti-Pattern 3 (NavigationStack scattered across views)
- ComingSoonOverlay uses `theme.radii.chip` (smallest available token) as D-06 specified for the compact capsule shape
- `GameCard` struct kept local to HomeView.swift — single-use model; DesignKit promotion criterion (used in 2+ games) not met
- Disabled cards use 60% opacity (`0.6` via SwiftUI `opacity()` modifier, not a Color literal) + lock SF Symbol per D-06
- All 9 card IDs follow PROJECT.md long-term vision order: Minesweeper first, then Merge / Word Grid / Solitaire / Sudoku / Nonogram / Flow / Pattern Memory / Chess Puzzles

## Deviations from Plan

None — plan executed exactly as written. The note in Task 1 about `lineWidth: 1` (stroke, not padding or radius) is documented in the plan itself as an accepted numeric literal.

## Issues Encountered

None.

## Known Stubs

The following intentional stubs exist by plan design (deferred to future phases):

| File | Stub | Deferred To |
|------|------|-------------|
| `gamekit/gamekit/Screens/SettingsView.swift` | "Theme controls coming in a future update." placeholder | Phase 5 (SHELL-02) |
| `gamekit/gamekit/Screens/StatsView.swift` | "Your stats will appear here." / "Your best times will appear here." | Phase 4 (SHELL-03) |
| `gamekit/gamekit/Screens/HomeView.swift` | Minesweeper destination is a "Coming in Phase 3" placeholder | Phase 3 (MINES-02–07) |

These stubs are intentional (documented in PLAN.md as D-04) and do not prevent the plan goal (navigable shell with token-pure rendering) from being achieved.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Plan 07 surfaces are purely local UI state (`showingComingSoon`, `navigateToMines`) with no persistence. STRIDE register from the plan (T-01-13 DoS accept, T-01-14 Tampering accept) applies unchanged.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plan 08 (localization catalog) can proceed immediately: all `String(localized:)` call sites are in place across the 6 new screen files. Xcode's "Use Compiler to Extract Swift Strings" setting is already ON from Plan 01.

Phase 2 (Mines Engines) and Phase 3 (Mines UI) depend on this shell being stable — it is. The HomeView Minesweeper card navigates to a placeholder; Phase 3 will replace that destination with the real game board.

---
*Phase: 01-foundation*
*Completed: 2026-04-25*
