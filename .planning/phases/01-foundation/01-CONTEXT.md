# Phase 1: Foundation - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

P1 delivers the **themed app shell**: DesignKit wired as a local SPM dep, `ThemeManager` injected via `@EnvironmentObject`, bundle ID + Swift 6 strict concurrency + iOS 17 deployment locked, `xcstrings` localization scaffolded, pre-commit hook live (Color literals / hardcoded radii+padding / Finder dupes rejected), and a navigable shell with Home (Minesweeper card + 8 disabled future-game placeholders) plus Settings and Stats stubs.

**Out of scope for P1** (owned by later phases):
- Mines engines (P2)
- Mines gameplay UI / gestures / timer / overlays (P3)
- SwiftData models, ModelContainer, Stats screen content (P4)
- Polish: animation pass, haptics, SFX, full Settings spine, IntroFlow, theme legibility audit, full a11y (P5)
- iCloud capability, Sign in with Apple (P6)

</domain>

<decisions>
## Implementation Decisions

### Shell Scope
- **D-01:** Shell screens in P1 = **Home + Settings stub + Stats stub**, all navigable. Catches token-discipline regressions on more screens early.
- **D-02:** Navigation root is a **TabView** with three tabs — Home / Stats / Settings. Each tab owns its own `NavigationStack`. iOS-canonical for utility-app feel. The Mines game push happens inside the Home tab's stack.
- **D-03:** Home shows **all 8 future games** from PROJECT.md vision as disabled cards: Merge, Word Grid, Solitaire, Sudoku, Nonogram, Flow, Pattern Memory, Chess puzzles. Minesweeper card is the only enabled one. Signals the long-term suite; satisfies SHELL-01's "placeholders visually present but disabled."
- **D-04:** Settings + Stats stubs = **themed scaffold only** — section headers and `DKCard` skeletons with no content text yet. Pre-shapes the P4/P5 layouts and gives more token surface to legibility-test under presets. Real empty-state copy ("No games played yet.") lands in P4 with the data-driven Stats view.
- **D-05:** **No IntroFlow plumbing in P1.** SHELL-04 fully owned by P5 — `hasSeenIntro` flag, IntroFlowView, first-launch logic all arrive together at P5. Keeps P1 scope tight.
- **D-06:** Disabled future-game cards show a **"coming soon" toast/overlay on tap**. Card is tappable but the tap surfaces a brief overlay (DesignKit-token-styled) rather than no-op. Discoverability over silence. Conveyed visually via reduced opacity + a "sparkles" or "lock" SF Symbol badge.

### DesignKit Linking
- **D-07:** Link DesignKit via **Xcode → Add Package Dependencies → Add Local → `../DesignKit`**. Keep the existing `gamekit.xcodeproj`; do not convert to a workspace; do not introduce a top-level `Package.swift`. Simplest setup.
- **D-08:** **No version pinning** — local-path dependency tracks whatever `../DesignKit` has on disk. Per CLAUDE.md §2: edits to DesignKit flow back to the shared kit; siblings benefit. Accepted risk: a breaking DesignKit change ripples to GameKit immediately.
- **D-09:** **Document derived-data hygiene** in `Docs/` (a short note: "When DesignKit token signatures change, clean DerivedData if you see ghost-build issues"). No automation script in P1 — escalate to a script if it bites repeatedly.

### iCloud / Persistence Prep
- **D-10:** **Pin CloudKit container ID `iCloud.com.lauterstar.gamekit` in PROJECT.md** in P1 — but do **NOT** add the iCloud capability or entitlement yet. Capability provisioning happens at P6 alongside Sign in with Apple. Avoids provisioning profile churn pre-Mines while still locking the ID per PITFALLS Pitfall 3 (ID drift = stranded TestFlight data).
- **D-11:** **No `ModelContainer` in P1.** SwiftData is not touched until P4 introduces the first `@Model` (`GameRecord`, `BestTime`). Keeps P1 a pure shell phase. CloudKit-compatible schema rules from PITFALLS Pitfall 2 will be applied in P4 when models are designed.
- **D-12:** **Cold-start (<1s, FOUND-01) verification deferred to P5/P7 audit.** No `os_signpost` instrumentation or stopwatch ritual in P1. Accepted risk: a regression introduced in P1 isn't caught until polish/release. Mitigation: keep P1 surface trivially small (no async work in `App.init`, no eager DB construction, no eager DesignKit work beyond `ThemeManager()`).

### Claude's Discretion
The user did not lock the following — planner has flexibility, but should align with research / CLAUDE.md / AGENTS.md:

- **Pre-commit hook mechanism (FOUND-07)** — choose between a raw `.git/hooks/pre-commit` shell script committed via a `scripts/install-hooks.sh` bootstrap, or `lefthook` / `husky`. Pure shell + bootstrap is simplest and matches the "no extra dependency" posture of the project. Hook must reject `Color(...)` literals, `cornerRadius: <int>` / `padding(<int>)` integers in `Games/` and `Screens/`, and any `*\ 2.swift` Finder-dupe files (per CLAUDE.md §8.7).
- **Localization scaffold (FOUND-05)** — default to a single `Localizable.xcstrings` in `Resources/` with EN as the source language. "Use Compiler to Extract Swift Strings" build setting ON. Per-feature catalogs deferred until they're justified.
- **Placeholder app icon (FOUND-06)** — flat DesignKit-color icon (e.g. `theme.colors.brand` or comparable token resolved at design time, not runtime — icons are baked assets). Manual `Assets.xcassets` `AppIcon` set. Real icon ships at P7.
- **`ThemeManager` construction site** — instantiate as `@StateObject` in `GameKitApp` (per ARCHITECTURE.md "Component Responsibilities" table). Use DesignKit's default `ThemeStorage` (UserDefaults-backed). No `ThemeStore` wrapper unless extra ecosystem-specific persistence is needed.
- **Default initial preset** — Classic category, default member (whatever DesignKit ships as the first Classic preset). User can change via the Settings spine when it lands at P5; P1 stub's Settings tab does not yet expose the picker.
- **Swift 6 strict concurrency setting** — enable in build settings (`SWIFT_STRICT_CONCURRENCY = complete`). Resolve any warnings introduced by adopting DesignKit; do not silence with `@preconcurrency` unless DesignKit itself surfaces the issue.

### Folded Todos
None — STATE.md `Pending Todos` is empty.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project planning
- `.planning/PROJECT.md` — Vision, constraints, key decisions, out-of-scope list
- `.planning/REQUIREMENTS.md` §Foundation, §App Shell — FOUND-01..07, SHELL-01 (the requirements P1 must satisfy)
- `.planning/ROADMAP.md` §"Phase 1: Foundation" — goal, success criteria, dependencies
- `.planning/STATE.md` — current position, accumulated decisions

### Architecture & pitfalls research
- `.planning/research/ARCHITECTURE.md` — Folder layout (App / Core / Games / Screens), `GameKitApp` composition, `ThemeManager` injection pattern, single shared `ModelContainer` rule (deferred to P4 per D-11)
- `.planning/research/PITFALLS.md` — Pitfall 2 (CloudKit-compatible schema rules — applied at P4), Pitfall 3 (CloudKit container ID stability — D-10 pins ID now), Pitfall 9 (theme legibility — full audit at P5)
- `.planning/research/STACK.md` — Stack defaults (Swift 6, SwiftUI, SwiftData, DesignKit)
- `.planning/research/FEATURES.md` — Feature inventory
- `.planning/research/SUMMARY.md` — Research convergence summary

### Working rules
- `CLAUDE.md` §0 (what we're building), §1 (absolute constraints), §2 (DesignKit consumption), §3 (project structure), §8.7–§8.10 (Finder dupes, file auto-registration, simulator hygiene, commit discipline)
- `AGENTS.md` — Mirror of CLAUDE.md for non-Claude tools

### DesignKit (sibling SPM dep)
- `../DesignKit/Sources/DesignKit/Theme/Tokens.swift` — Token surface (radii: card / button / chip / sheet; spacing: xs / s / m / l / xl / xxl)
- `../DesignKit/Sources/DesignKit/Theme/ThemeManager.swift` — `ThemeManager` API surface, mode/preset/overrides
- `../DesignKit/Sources/DesignKit/Storage/` — `ThemeStorage` defaults
- `../DesignKit/Sources/DesignKit/Components/` — `DKCard`, `DKButton`, `DKThemePicker`, etc.
- `../DesignKit/README.md` — DesignKit consumer docs

### Repo-level project doc
- `README.md` — Project overview

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`gamekit.xcodeproj`** (Xcode 16, `objectVersion = 77`, `PBXFileSystemSynchronizedRootGroup`) — already exists. Drop new `.swift` files into folders under `gamekit/gamekit/` and they auto-register. No `pbxproj` hand-patching for new files (CLAUDE.md §8.8). Bundle ID currently set by Xcode default — needs lock to `com.lauterstar.gamekit` (FOUND-04).
- **`gamekit/gamekit/gamekitApp.swift`** — Default Xcode template `@main`. Will be rewritten as the `GameKitApp` per ARCHITECTURE.md (renaming the type from lowercase `gamekitApp` to `GameKitApp` is intended; keep filename to avoid Finder churn or rename file too — planner choice).
- **`gamekit/gamekit/ContentView.swift`** — Default "Hello, world" template. Will be deleted; root scene becomes the TabView shell.
- **`gamekit/gamekitTests/gamekitTests.swift`** — Default Swift Testing test target exists. P1 may not add tests (pure scaffolding) — but the target is ready for P2 engine tests.
- **`gamekit/gamekit/Assets.xcassets`** — Default asset catalog with placeholder `AppIcon` and `AccentColor`. P1 replaces `AppIcon` with the DesignKit-color placeholder per FOUND-06.
- **`../DesignKit/Sources/DesignKit/`** — Charts, Components, Layout, Motion, Storage, Theme, Typography, Utilities. Confirmed at sibling path; `Theme/Tokens.swift` and `Theme/ThemeManager.swift` present.

### Established Patterns
- **DesignKit token discipline (CLAUDE.md §1, §2, §8.4)** — All radii via `theme.radii.{card, button, chip, sheet}`. All spacing via `theme.spacing.{xs, s, m, l, xl, xxl}`. No invented tokens. Verify before using by reading `../DesignKit/Sources/DesignKit/Layout/*.swift` and `Theme/Tokens.swift`.
- **File size cap** — ≤400-line views, ≤500-line Swift files (CLAUDE.md §8.1, §8.5).
- **Synchronized root group** — Xcode 16 picks up new files in folders automatically; only edit `pbxproj` for new top-level folders or target-membership changes (CLAUDE.md §8.8).
- **No Finder dupes** — `* 2.swift` files block builds; pre-commit hook from FOUND-07 catches them (CLAUDE.md §8.7).
- **`String(localized:)` everywhere** — even hard-coded EN strings in stubs go through the catalog from day 1.

### Integration Points
- **`@main` scene** (`GameKitApp.swift`) — Owns `@StateObject var themeManager = ThemeManager()`. Injects via `.environmentObject(themeManager)` and applies `.preferredColorScheme(themeManager.resolvedColorScheme)` at the WindowGroup root (per ARCHITECTURE.md).
- **Root view** — TabView with three tabs (Home, Stats, Settings); each tab is a `NavigationStack` rooted at its respective view.
- **`HomeView`** (`Screens/HomeView.swift`) — Renders enabled Minesweeper card + 8 disabled future-game cards. Tap on disabled card surfaces "coming soon" overlay. NavigationLink (or push) to a Mines placeholder destination — actual `MinesweeperView` arrives at P3.
- **`SettingsView` / `StatsView`** (`Screens/`) — themed scaffold stubs (section headers + `DKCard` skeletons). No state, no @Query.
- **DesignKit consumption** — Import `DesignKit` in any view that uses tokens. `theme` accessed via the env-injected `ThemeManager` (or `@Environment` reader, depending on DesignKit's published API).

### Cross-Cutting Invariants Activated in P1
Per ROADMAP.md "Cross-Cutting Invariants": DesignKit token discipline, bundle ID stability, string localization, project hygiene (pre-commit hook + no Finder dupes) all begin enforcement at P1 and run through P7. CloudKit-compatible schema rules begin at P4 (no SwiftData in P1 per D-11).

</code_context>

<specifics>
## Specific Ideas

- **TabView, three tabs.** User explicitly chose this over a single NavigationStack with toolbar buttons or sheet-based Settings. Implication: Mines push happens inside Home tab's stack only.
- **All 8 disabled cards visible.** Mirrors PROJECT.md long-term vision exactly: Merge, Word Grid, Solitaire, Sudoku, Nonogram, Flow, Pattern Memory, Chess puzzles. Order matches PROJECT.md mention order unless there's a UX reason to re-order.
- **"Coming soon" toast on tap of disabled cards.** Discoverability matters more than silence. Toast styled with DesignKit tokens (no hardcoded colors).
- **Themed scaffold stubs, not empty-state copy.** Settings and Stats tabs render section headers + DKCard skeletons with no real content. Real empty states ("No games played yet.") arrive at P4 alongside data.
- **No iCloud capability in P1, but container ID locked in PROJECT.md.** ID `iCloud.com.lauterstar.gamekit` is contractual now; capability provisioning happens at P6.

</specifics>

<deferred>
## Deferred Ideas

### Surfaced during discussion but pushed to other phases
- **`hasSeenIntro` flag + IntroFlow** — D-05 defers entirely to P5 (SHELL-04). Surfaced as an option in P1 ("add the flag now to avoid retrofit") but the user chose to fully defer.
- **Pre-build smoke-test ModelContainer** — D-11 rules out P1 SwiftData touch. CloudKit-compat smoke test introduced at P4 instead (per PITFALLS Pitfall 2 mitigation).
- **iCloud entitlement / provisioning profile work** — D-10 defers capability to P6. Container ID is pinned now to prevent drift.
- **`os_signpost` cold-start instrumentation** — D-12 defers to P5/P7 audit. Re-introduce only if regression is suspected.
- **Build cache automation script** — D-09 keeps it as docs-only for now. Promote to `scripts/clean-build.sh` only if the manual ritual gets painful.
- **Swap to git URL + tag for DesignKit** — D-08 keeps local path through v1. Revisit post-v1 once DesignKit surface stabilizes.

### Reviewed Todos (not folded)
None — STATE.md `Pending Todos` was empty.

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-04-25*
