# Phase 1: Foundation - Pattern Map

**Mapped:** 2026-04-25
**Files analyzed:** 12 (10 new, 2 modified)
**Analogs found:** 9 / 12 (3 hygiene/config files have no in-repo analog and follow standard shell/JSON conventions)

> Notation
> - "DK = `/Users/gabrielnielsen/Desktop/DesignKit`" (sibling SPM package — read-only reference)
> - "FT = `/Users/gabrielnielsen/Desktop/FitnessTracker/FitnessTracker`" (sibling DesignKit consumer; `theme(for:)` shape differs slightly from this repo's planned `theme(using:)` — see Note A in Shared Patterns)
> - "GK = `/Users/gabrielnielsen/Desktop/GameKit/gamekit/gamekit`" (this repo, current state)

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `gamekit/gamekit/App/GameKitApp.swift` (new — replaces `gamekitApp.swift`) | app-scene | request-response | `FT/FitnessTrackerApp.swift` | role-match (sibling does too much; copy only the `@StateObject ThemeManager` + `.environmentObject` + `.preferredColorScheme` slice) |
| `gamekit/gamekit/Screens/RootTabView.swift` (new) | screen-shell | request-response | `FT/Features/RootTabView.swift` | exact (TabView with theme injection) |
| `gamekit/gamekit/Screens/HomeView.swift` (new) | screen | request-response | `FT/Features/Home/HomeView.swift` | role-match (token-pure card-stack pattern; we drop SwiftData @Query) |
| `gamekit/gamekit/Screens/SettingsView.swift` (new — stub) | screen | request-response | `FT/Settings/SettingsView.swift` | role-match (we use scaffold-only, no Form, no @Query) |
| `gamekit/gamekit/Screens/StatsView.swift` (new — stub) | screen | request-response | `FT/Features/Home/HomeView.swift` (DKCard + section-header layout) | partial (no per-game data yet) |
| `gamekit/gamekit/Screens/ComingSoonOverlay.swift` (new) | component | event-driven | None in-repo. Use `DK/Components/DKCard.swift` token shape | partial (no toast in either app today) |
| `gamekit/gamekit/Screens/SettingsComponents.swift` (new — local helpers) | utility (view-builder) | n/a | `FT/Settings/SettingsComponents.swift` | exact (lift `settingsSectionHeader` + `settingsNavRow` shapes verbatim, port to GameKit naming) |
| `gamekit/gamekit/Resources/Localizable.xcstrings` (new) | config (string catalog) | n/a | None in-repo. Standard Xcode-generated source | n/a (Xcode creates; commit empty/minimal) |
| `gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json` (modified) | config (asset) | n/a | `GK/Assets.xcassets/AppIcon.appiconset/Contents.json` (current default) | exact (extend with `filename` keys for the placeholder PNGs) |
| `scripts/install-hooks.sh` (new) | utility (bootstrap script) | batch | None in-repo. Standard bash bootstrap | n/a (write minimal shell) |
| `.githooks/pre-commit` (new) | utility (git hook) | batch | None in-repo. Custom — codifies CLAUDE.md §1 / §8.7 / §8.8 / Pitfall 8 | n/a (write minimal shell) |
| `gamekit/gamekit.xcodeproj/project.pbxproj` (modified) | config (Xcode project) | n/a | self (in place; surgical edits only) | exact (current values shown in §"Project Build Settings" below) |
| `Docs/derived-data-hygiene.md` (new) | docs | n/a | None in-repo. Free-form short note | n/a |

**Files to delete in this phase (existing):**
- `gamekit/gamekit/gamekitApp.swift` — replaced by `App/GameKitApp.swift`
- `gamekit/gamekit/ContentView.swift` — replaced by `Screens/RootTabView.swift`

---

## Pattern Assignments

### `App/GameKitApp.swift` (app-scene, request-response)

**Analog:** `FT/FitnessTrackerApp.swift` — but copy ONLY the slim slice listed below. FitnessTracker also constructs `ModelContainer`, `AuthService`, `CloudSyncService`, `TipKit`, etc. — **none of those belong in P1** per CONTEXT D-11 (no SwiftData), D-10 (no iCloud capability), D-12 (no signpost/cold-start instrumentation).

**Slim-slice excerpt to copy** (FT/FitnessTrackerApp.swift lines 159-202, stripped):

```swift
@main
struct FitnessTrackerApp: App {
    @StateObject private var themeManager = ThemeManager()
    // ...
    var body: some Scene {
        WindowGroup {
            AppBootstrapView()                          // <- replace with RootTabView()
                .environmentObject(themeManager)
                // ... (drop all other env objects for P1)
                .preferredColorScheme(themeManager.preferredColorScheme)
                // (drop .onAppear cloudSync wiring)
        }
        // (drop .modelContainer for P1 — D-11)
    }
}
```

**P1 target shape** (after slimming):

```swift
import SwiftUI
import DesignKit

@main
struct GameKitApp: App {
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(themeManager)
                .preferredColorScheme(preferredScheme)
        }
    }

    private var preferredScheme: ColorScheme? {
        switch themeManager.mode {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}
```

This is also exactly the shape the DesignKit README Quickstart documents (`DK/README.md` lines 49-69).

**Note:** `themeManager.preferredColorScheme` exists as a convenience on FitnessTracker's local `ThemeManager` wrapper, NOT on DesignKit's public API. DesignKit exposes `mode` (light/dark/system) and `resolvedScheme(using:)` — see `DK/Theme/ThemeManager.swift` lines 47-53. P1 inlines the small switch (as shown above) rather than relying on a wrapper that doesn't exist yet.

**Anti-patterns to avoid (Pitfall 12, ARCHITECTURE Stay-Out §1, CONTEXT D-12):**
- No `init() { ... }` body. No `Task.detached`. No `getCredentialState`. No `try Tips.configure`.
- No `.modelContainer(...)` modifier (deferred to P4).
- No CloudKit container ID literal in code (it lives in `PROJECT.md` only per D-10).

---

### `Screens/RootTabView.swift` (screen-shell, request-response)

**Analog:** `FT/Features/RootTabView.swift` (lines 1-66, 96-98 — `.tint(theme.colors.accentPrimary)`)

**Imports + theme-binding pattern** (FT lines 1-19):

```swift
import SwiftUI
import DesignKit

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: Int = 0

    private var theme: Theme {
        themeManager.theme(for: colorScheme)   // <-- See Note A in Shared Patterns
    }
```

**TabView body** (FT lines 45-66, drop `RestTimerBanner` / `activeWorkoutBar` overlays — P1 has no active session):

```swift
var body: some View {
    TabView(selection: $selectedTab) {
        HomeView()
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)

        StatsView()
            .tabItem { Label("Stats", systemImage: "chart.bar") }
            .tag(1)

        SettingsView()
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(2)
    }
    .tint(theme.colors.accentPrimary)
}
```

**P1 deltas from FT:**
- 3 tabs (Home / Stats / Settings) per CONTEXT D-02, not 5.
- No `@Query` / `@StateObject LiveSessionController` / `Timer.publish` / `.onReceive(NotificationCenter)` — P1 is stateless shell.
- Each tab's destination is its own root `View`. Per ARCHITECTURE Anti-Pattern 3 + ROADMAP, the `NavigationStack` lives **inside** each tab's root view (HomeView, etc.), not here. CONTEXT D-02: "Each tab owns its own `NavigationStack`."
- All tab labels use `String(localized:)` via the `Label("Home", ...)` initializer + the xcstrings catalog auto-extracts (see "Localization" in Shared Patterns).

---

### `Screens/HomeView.swift` (screen, request-response)

**Analog:** `FT/Features/Home/HomeView.swift` lines 1-86 (token-pure stack of cards). Drop everything SwiftData-related.

**Imports + theme-binding** (FT lines 1-20, slimmed):

```swift
import SwiftUI
import DesignKit

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }
```

**ScrollView + card-stack body shape** (FT lines 64-85, slimmed):

```swift
var body: some View {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                // header
                // game cards (1 enabled + 8 disabled — see GameCard data model below)
            }
            .padding(.vertical, theme.spacing.l)
            .padding(.horizontal, theme.spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.colors.background.ignoresSafeArea())
    }
}
```

**Game-card data model** (no analog in repo — derive directly from CONTEXT D-03 + ARCHITECTURE Stay-Out §1 + §3 ["static array, not a registry"]):

```swift
private struct GameCard: Identifiable {
    let id: String           // "minesweeper", "merge", ...
    let title: String        // localized
    let symbol: String       // SF Symbol
    let isEnabled: Bool
}

private let cards: [GameCard] = [
    GameCard(id: "minesweeper",    title: String(localized: "Minesweeper"),     symbol: "square.grid.4x3.fill", isEnabled: true),
    GameCard(id: "merge",          title: String(localized: "Merge"),           symbol: "square.stack.3d.up",   isEnabled: false),
    GameCard(id: "wordGrid",       title: String(localized: "Word Grid"),       symbol: "textformat.abc",       isEnabled: false),
    GameCard(id: "solitaire",      title: String(localized: "Solitaire"),       symbol: "suit.spade",           isEnabled: false),
    GameCard(id: "sudoku",         title: String(localized: "Sudoku"),          symbol: "9.square",             isEnabled: false),
    GameCard(id: "nonogram",       title: String(localized: "Nonogram"),        symbol: "square.grid.3x3",      isEnabled: false),
    GameCard(id: "flow",           title: String(localized: "Flow"),            symbol: "scribble.variable",    isEnabled: false),
    GameCard(id: "patternMemory",  title: String(localized: "Pattern Memory"),  symbol: "rectangle.grid.2x2",   isEnabled: false),
    GameCard(id: "chessPuzzles",   title: String(localized: "Chess Puzzles"),   symbol: "checkmark.shield",     isEnabled: false),
]
```

(Order = PROJECT.md long-term-vision order per CONTEXT line 124.)

**Card visual pattern — uses `DKCard`** (DK/Components/DKCard.swift lines 12-21):

```swift
DKCard(theme: theme) {
    HStack(spacing: theme.spacing.m) {
        Image(systemName: card.symbol)
            .font(.title2)
            .foregroundStyle(card.isEnabled
                ? theme.colors.accentPrimary
                : theme.colors.textTertiary)

        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(card.title)
                .font(theme.typography.headline)
                .foregroundStyle(card.isEnabled
                    ? theme.colors.textPrimary
                    : theme.colors.textTertiary)
            if !card.isEnabled {
                Text(String(localized: "Coming soon"))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textTertiary)
            }
        }
        Spacer()
        if !card.isEnabled {
            Image(systemName: "lock")
                .foregroundStyle(theme.colors.textTertiary)
        } else {
            Image(systemName: "chevron.right")
                .foregroundStyle(theme.colors.textTertiary)
        }
    }
    .opacity(card.isEnabled ? 1.0 : 0.6)   // CONTEXT D-03/D-06 visual cue
}
```

**Tap behavior:**
- Enabled (Minesweeper) — `NavigationLink(value: ...)` push to a placeholder destination view inside this NavigationStack. The actual `MinesweeperView` arrives at P3 (CONTEXT line 111). For P1 the destination is a token-pure "Coming in P3" placeholder.
- Disabled — wrap card in `Button { triggerComingSoonToast(card) }` and toggle a `@State var showingComingSoon: Card?`. Render `ComingSoonOverlay` from `.overlay(alignment: .bottom)` per CONTEXT D-06. Auto-dismiss after ~1.8s.

**P1 deltas from FT/HomeView:**
- No `@Query` / `@Environment(\.modelContext)` / `@StateObject DashboardViewModel` / `Charts` / `TipKit` — P1 is shell-only.
- No `.task` / `.onAppear` data fetch.
- File budget: < 200 lines (CLAUDE.md §8.1 cap is 400; we want headroom for the disabled-card overlay state).

---

### `Screens/SettingsView.swift` (screen, request-response — STUB)

**Analog:** `FT/Settings/SettingsView.swift` lines 1-83, but **only** the outer `NavigationStack > ScrollView > VStack(spacing: theme.spacing.l)` skeleton + section headers + empty `DKCard`s. Drop every Picker/NavigationLink/Toggle.

**Skeletal shape to copy** (FT lines 31-50, gutted):

```swift
struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { themeManager.theme(for: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {

                    settingsSectionHeader(theme: theme, String(localized: "APPEARANCE"))
                    DKCard(theme: theme) {
                        // P1: empty scaffold (CONTEXT D-04). Picker lands at P5.
                        Text(String(localized: "Theme controls coming in a future update."))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textTertiary)
                    }

                    settingsSectionHeader(theme: theme, String(localized: "ABOUT"))
                    DKCard(theme: theme) {
                        Text(String(localized: "GameKit · v1.0"))
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Settings"))
        }
    }
}
```

**P1 sections** (CONTEXT D-04 — "scaffold only"):
- APPEARANCE — empty `DKCard`, no Picker yet (Picker lands at P5 per CONTEXT D-04).
- ABOUT — empty `DKCard` with version string.

**Anti-pattern to avoid (CLAUDE.md §8.3 + UX Pitfall "Stats screen empty state"):** Even a stub must have intentional placeholder copy ("Theme controls coming in a future update.") — never a literal blank `DKCard {}`.

---

### `Screens/StatsView.swift` (screen, request-response — STUB)

**Analog:** Same skeleton as SettingsView.swift above. No SwiftData per CONTEXT D-11.

**P1 sections** (CONTEXT D-04):
- HISTORY — empty `DKCard` placeholder.
- BEST TIMES — empty `DKCard` placeholder.

Real empty-state copy ("No games played yet.") lands at P4 with the data-driven view (CONTEXT D-04, line 27). For P1 use neutral scaffold copy like "Your stats will appear here."

---

### `Screens/ComingSoonOverlay.swift` (component, event-driven)

**Analog:** None in repo. Closest token shape is `DK/Components/DKCard.swift`.

**Pattern: a small floating capsule, surfaced via `.overlay(alignment: .bottom)` from HomeView, auto-dismisses after ~1.8s.**

```swift
import SwiftUI
import DesignKit

struct ComingSoonOverlay: View {
    let title: String        // e.g. "Word Grid coming soon"
    let theme: Theme

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            Image(systemName: "sparkles")
                .foregroundStyle(theme.colors.accentPrimary)
            Text(title)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textPrimary)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
        .background(theme.colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .padding(.bottom, theme.spacing.l)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

**Token discipline checklist (Pitfall 8):**
- Radius = `theme.radii.chip` (smallest existing — DO NOT invent a new token).
- Background = `theme.colors.surfaceElevated`. Border = `theme.colors.border`. Text = primary; icon = accent.
- Spacing only via `theme.spacing.{xs,s,m,l,xl,xxl}` — never integer literals.

---

### `Screens/SettingsComponents.swift` (utility / view-builder)

**Analog:** `FT/Settings/SettingsComponents.swift` lines 58-81 — copy `settingsSectionHeader` and `settingsNavRow` verbatim. Drop `settingsStepperRow` (no use yet).

**Excerpt to copy** (FT/SettingsComponents.swift lines 58-81):

```swift
import SwiftUI
import DesignKit

@ViewBuilder
func settingsNavRow(theme: Theme, title: String) -> some View {
    HStack {
        Text(title)
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textPrimary)
        Spacer()
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(theme.colors.textTertiary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
}

@ViewBuilder
func settingsSectionHeader(theme: Theme, _ title: String) -> some View {
    Text(title)
        .font(theme.typography.caption)
        .fontWeight(.semibold)
        .foregroundStyle(theme.colors.textTertiary)
        .tracking(1.2)
        .padding(.leading, theme.spacing.xs)
}
```

These are free functions (not views) so they live alongside the screens that use them. No promotion to DesignKit per CLAUDE.md §2 ("Promote to DesignKit only when proven — used in 2+ games"); these aren't game-specific anyway.

---

### `Resources/Localizable.xcstrings` (config — string catalog)

**Analog:** None in repo. Use Xcode's standard "File → New → File → String Catalog" generator. No code excerpt needed — Xcode emits the JSON skeleton.

**Contents at end of P1:** All `String(localized:)` keys auto-extracted by the build setting `SWIFT_EMIT_LOC_STRINGS = YES` (already ON in `project.pbxproj` line 418 — see §"Project Build Settings" below). Source language = English. Keep file in `gamekit/gamekit/Resources/`.

**Key set produced by P1 (target):**
- `"Home"`, `"Stats"`, `"Settings"` (tab labels)
- `"Minesweeper"`, `"Merge"`, `"Word Grid"`, `"Solitaire"`, `"Sudoku"`, `"Nonogram"`, `"Flow"`, `"Pattern Memory"`, `"Chess Puzzles"` (game card titles)
- `"Coming soon"`, `"%@ coming soon"` (overlay)
- `"APPEARANCE"`, `"ABOUT"`, `"HISTORY"`, `"BEST TIMES"` (section headers)
- `"Theme controls coming in a future update."`, `"Your stats will appear here."`, `"GameKit · v1.0"` (placeholder copy)

**STACK §7 reminder:** every user-facing string must use `String(localized: ...)` from day 1. `Text("Foo")` is fine because SwiftUI's `LocalizedStringKey` initializer also gets extracted with `SWIFT_EMIT_LOC_STRINGS = YES`. Pluralization (e.g. `"^[\(n) games](inflect: true)"`) deferred to P4 when stats arrive.

---

### `Assets.xcassets/AppIcon.appiconset/Contents.json` + placeholder PNGs (modified)

**Analog:** `GK/Assets.xcassets/AppIcon.appiconset/Contents.json` (current default — read above). Already declares the three iOS 17/26-style `1024x1024` slots: universal, dark, tinted.

**Modification:** add `"filename"` keys pointing to three placeholder PNGs (e.g. `icon-light.png`, `icon-dark.png`, `icon-tinted.png`) generated offline. Per CONTEXT D-06 (Claude's Discretion) the placeholder is a flat DesignKit-color square — colors are baked into the PNGs at design time, not resolved at runtime (icons are static bundle assets, NOT theme-responsive).

**Concrete shape after modification:**

```json
{
  "images" : [
    { "filename" : "icon-light.png",   "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "filename" : "icon-dark.png",    "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],    "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "filename" : "icon-tinted.png",  "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ], "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

**Pitfall 11 reminder:** Real icon ships at P7 — for P1, just an unmistakably-placeholder icon so the launch screen and home screen don't show "?".

---

### `scripts/install-hooks.sh` + `.githooks/pre-commit` (utility — git hook)

**Analogs:** None in repo. Standard bash bootstrap. Two-file pair as discussed in CONTEXT (Claude's Discretion, line 44): "Pure shell + bootstrap is simplest and matches the 'no extra dependency' posture of the project."

**`scripts/install-hooks.sh`** — one-time bootstrap a developer runs after clone:

```bash
#!/usr/bin/env bash
set -euo pipefail
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
echo "GameKit git hooks installed."
```

**`.githooks/pre-commit`** — codifies CLAUDE.md §1, §8.7, Pitfall 8, Pitfall 14:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Reject Finder-dupe files (CLAUDE.md §8.7 / Pitfall 14)
dupes=$(git diff --cached --name-only --diff-filter=A | grep -E ' 2\.swift$' || true)
if [ -n "$dupes" ]; then
  echo "ERROR: Finder-dupe files detected (will break the build via PBXFileSystemSynchronizedRootGroup):"
  echo "$dupes"
  exit 1
fi

# Reject hardcoded colors / radii / padding integers under Games/ and Screens/ (CLAUDE.md §1, Pitfall 8)
staged=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^gamekit/gamekit/(Games|Screens)/.*\.swift$' || true)
if [ -n "$staged" ]; then
  bad=""
  for f in $staged; do
    # Color literals (Color(red:..) / Color(hex:..) / Color.gray etc.)
    if git diff --cached "$f" | grep -E '^\+' | grep -E 'Color\(\s*(red:|hex:|white:)|Color\.(red|blue|green|gray|orange|yellow|pink|purple|black|white)' > /dev/null; then
      bad="${bad}${f}: hardcoded Color literal\n"
    fi
    # cornerRadius: <int>
    if git diff --cached "$f" | grep -E '^\+' | grep -E 'cornerRadius:\s*[0-9]+' > /dev/null; then
      bad="${bad}${f}: numeric cornerRadius literal (use theme.radii.{card,button,chip,sheet})\n"
    fi
    # padding(<int>)
    if git diff --cached "$f" | grep -E '^\+' | grep -E '\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)' > /dev/null; then
      bad="${bad}${f}: numeric padding literal (use theme.spacing.{xs,s,m,l,xl,xxl})\n"
    fi
  done
  if [ -n "$bad" ]; then
    echo -e "ERROR: token-discipline violations under Games/ or Screens/:\n${bad}"
    exit 1
  fi
fi

exit 0
```

**Token vocabulary the hook must protect** — all four exact identifiers from `DK/Layout/RadiusTokens.swift` (lines 4-8) and `DK/Layout/SpacingTokens.swift` (lines 4-9):
- Radii: `card | button | chip | sheet` — NO `medium`, `small`, `large`.
- Spacing: `xs | s | m | l | xl | xxl` — six steps, no others.

**Scope:** hook only runs on `Games/` and `Screens/` per CONTEXT line 44. Don't apply to `App/`, `Core/`, or test files (those import `Color` legitimately).

**Pitfall 8 hard rule:** the hook's grep must reject the literals; it does NOT need to reject `Color(...)` parameters where the argument is a `theme.colors.X` rebind (extremely rare in app code; if it ever appears, whitelist by comment).

---

### `gamekit/gamekit.xcodeproj/project.pbxproj` (modified — surgical)

**Current values that must change, with line numbers from the file:**

| Setting | Current value (line) | Target value | Why |
|---|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | `26.2` (lines 325, 383, 465, 487) | `17.0` | CLAUDE.md §1 / STACK Version Compat — iOS 17 is the floor. 26.2 is a mistype/upper-bound — would fail to install on any non-26 device. |
| `SWIFT_VERSION` | `5.0` (lines 420, 452, 473, 495, 515, 535) | `6.0` | CLAUDE.md §1 / CONTEXT Discretion line 49 — Swift 6 strict concurrency. |
| (new) `SWIFT_STRICT_CONCURRENCY` | absent | `complete` | CONTEXT Discretion line 49 — explicit. |
| `PRODUCT_BUNDLE_IDENTIFIER` (app target) | `lauterstar.gamekit` (lines 413, 445) | `com.lauterstar.gamekit` | CONTEXT D-10 / Pitfall 11 — locked ID. Note: bundle ID changes are normally forbidden (CLAUDE.md §1) but the app has not yet shipped to TestFlight, so this one-time fix is in scope for P1. After P1 commit, the ID is contractually frozen. |
| `PRODUCT_BUNDLE_IDENTIFIER` (test targets) | `lauterstar.gamekitTests`, `lauterstar.gamekitUITests` (lines 467, 489, 509, 529) | `com.lauterstar.gamekit.tests`, `com.lauterstar.gamekit.uitests` | Match new app prefix. |
| (new) Local SPM dep on `../DesignKit` | absent | added via Xcode → Add Package Dependencies → Add Local | CONTEXT D-07. **Use Xcode UI; do NOT hand-patch `XCLocalSwiftPackageReference` blocks** — Xcode 16/26 emits the right structure including the new sync-root-group hooks (CLAUDE.md §8.8). |

**Settings already correct — DO NOT touch:**
- `objectVersion = 77;` (line 6) — Xcode 16's PBXFileSystemSynchronizedRootGroup format. CLAUDE.md §8.8 invariant.
- `LOCALIZATION_PREFERS_STRING_CATALOGS = YES;` (lines 326, 384) — STACK §7 enabler.
- `STRING_CATALOG_GENERATE_SYMBOLS = YES;` (lines 415, 447) — auto-extracts `String(localized:)` keys.
- `SWIFT_EMIT_LOC_STRINGS = YES;` (lines 418, 450) — same.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;` (lines 417, 449) — STACK §1 default.
- `SWIFT_APPROACHABLE_CONCURRENCY = YES;` (lines 416, 448) — leave on.
- `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;` (lines 396, 428) — keep.
- `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;` (line 286 visible at offset; project-wide) — keep.
- `DEVELOPMENT_TEAM = JCWX4BK8GW;` — leave; user-owned.

**No new top-level folder targets needed** for `App/`, `Screens/`, `Resources/` — they auto-register under `gamekit/gamekit/` via the synchronized root group (CLAUDE.md §8.8). Only `pbxproj` edits are the build-settings deltas above and the `.package(path: "../DesignKit")` reference Xcode injects via the Add Local UI.

---

### `Docs/derived-data-hygiene.md` (docs)

**Analog:** None in repo. Free-form short note per CONTEXT D-09: "When DesignKit token signatures change, clean DerivedData if you see ghost-build issues. No automation script in P1 — escalate to a script if it bites repeatedly."

**Target shape (~30 lines):** brief markdown — when to run `xcrun simctl uninstall ...` (Pitfall 14 / CLAUDE.md §8.9), when to wipe `~/Library/Developer/Xcode/DerivedData/gamekit-*` (D-09 trigger), pointer back to CLAUDE.md §8 for canonical rules.

---

## Shared Patterns

### Authentication / Authorization
**Not applicable in P1.** D-10/D-11/D-12 all defer auth & data layers. No middleware, no guards. (Sign in with Apple lands at P6.)

### Theme injection (cross-cutting — applies to every view file P1 ships)

**Source:** `DK/README.md` lines 49-93 + `FT/Features/RootTabView.swift` lines 6-19.

**Apply to:** `RootTabView`, `HomeView`, `SettingsView`, `StatsView`, `ComingSoonOverlay` (the last takes `theme: Theme` directly as a prop because it's a leaf component, not env-coupled).

**Three-line snippet to copy into every screen** (ARCHITECTURE Pattern 4):

```swift
@EnvironmentObject private var themeManager: ThemeManager
@Environment(\.colorScheme) private var colorScheme
private var theme: Theme { themeManager.theme(for: colorScheme) }
```

**Note A — `theme(for:)` vs `theme(using:)`:**
FitnessTracker calls `themeManager.theme(for: colorScheme)`. DesignKit's *public* API on `ThemeManager` is `theme(using systemScheme: ColorScheme) -> Theme` (`DK/Theme/ThemeManager.swift` line 55). FitnessTracker has a local extension/wrapper that exposes `theme(for:)`. **GameKit P1 should use the public DesignKit API directly:**

```swift
private var theme: Theme { themeManager.theme(using: colorScheme) }
```

The DesignKit Quickstart (`DK/README.md` line 80) confirms `theme(using:)` as the canonical call. **Do not introduce a `theme(for:)` shim** — it would be GameKit-specific drift from DesignKit's surface, working around a name that doesn't exist (CLAUDE.md §2: "Extend at the source if a token is missing, never work around").

### Token discipline (Pitfall 8 — applies to every Swift file under `Games/` and `Screens/`)

**Source:** `DK/Layout/RadiusTokens.swift` lines 4-8 + `DK/Layout/SpacingTokens.swift` lines 4-9 + `DK/Theme/Tokens.swift` lines 3-19.

**Vocabulary (the only allowed values inside `Games/` + `Screens/`):**

```swift
// Radii (DK/Layout/RadiusTokens.swift:4-8)
theme.radii.card    // 16
theme.radii.button  // 14
theme.radii.chip    // 12
theme.radii.sheet   // 22

// Spacing (DK/Layout/SpacingTokens.swift:4-9)
theme.spacing.xs    // 4
theme.spacing.s     // 8
theme.spacing.m     // 12
theme.spacing.l     // 16
theme.spacing.xl    // 24
theme.spacing.xxl   // 32

// Colors (DK/Theme/Tokens.swift:3-19)
theme.colors.background / .surface / .surfaceElevated / .border
theme.colors.textPrimary / .textSecondary / .textTertiary
theme.colors.accentPrimary / .accentSecondary / .highlight
theme.colors.success / .warning / .danger
theme.colors.fillPressed / .fillSelected / .fillDisabled
```

**Enforcement:** `.githooks/pre-commit` (above) rejects `Color(...)` literals, `cornerRadius: <int>`, `padding(<int>)` in any added/modified `Games/**.swift` or `Screens/**.swift`.

### Localization (cross-cutting — every user-facing string)

**Source:** STACK §7 + Pitfall 14 + CONTEXT line 107 ("`String(localized:)` everywhere — even hard-coded EN strings in stubs go through the catalog from day 1").

**Apply to:** every string in HomeView, RootTabView, SettingsView, StatsView, ComingSoonOverlay.

**Form:**
```swift
String(localized: "Coming soon", comment: "Disabled-card overlay caption")
String(localized: "Settings", comment: "Tab title")
```

**SwiftUI `Text("Foo")` is acceptable** — it accepts `LocalizedStringKey` and is auto-extracted. Use `String(localized:)` when you need a plain `String` (e.g. struct field, `Label("...", systemImage:)` first arg).

### File size + project hygiene (CLAUDE.md §8.1, §8.5, §8.7, §8.8)
- Hard cap: 500 lines per Swift file. Soft cap: 400 lines for views.
- HomeView is the bulkiest P1 file; expected ~170 lines. SettingsView/StatsView ~70 each. RootTabView ~50.
- Drop `.swift` files into `App/`, `Screens/`, `Resources/` directly — Xcode auto-registers (do NOT hand-patch pbxproj for files).
- Pre-commit hook catches `* 2.swift`. CLAUDE.md §8.7.

### Error handling
**Not applicable in P1.** No fallible paths — no `try`, no `throws`, no `do/catch`. (P4 introduces ModelContainer init which can fail, P6 introduces sign-in.) If any code path needs error handling, it's a smell that P1 is doing too much.

---

## No Analog Found

| File | Role | Data Flow | Reason | Mitigation |
|---|---|---|---|---|
| `Resources/Localizable.xcstrings` | config | n/a | No xcstrings file in either GameKit or FitnessTracker today | Use Xcode's New File generator. JSON is auto-managed by Xcode. |
| `scripts/install-hooks.sh` + `.githooks/pre-commit` | utility | batch | First scripts in this repo | Lift the standard `core.hooksPath` bootstrap pattern (universally documented). Hook content is custom — see PATTERNS body above. |
| `Docs/derived-data-hygiene.md` | docs | n/a | First file in `Docs/` | Free-form ~30-line markdown; no template needed. |

---

## Project Build Settings (Quick Reference for Planner)

Read these directly from `gamekit/gamekit.xcodeproj/project.pbxproj`:

| Line(s) | Setting | Current | After P1 |
|---|---|---|---|
| 6 | `objectVersion` | `77` | `77` (untouched) |
| 325, 383, 465, 487 | `IPHONEOS_DEPLOYMENT_TARGET` | `26.2` | `17.0` |
| 326, 384 | `LOCALIZATION_PREFERS_STRING_CATALOGS` | `YES` | `YES` (untouched) |
| 415, 447 | `STRING_CATALOG_GENERATE_SYMBOLS` | `YES` | `YES` (untouched) |
| 416, 448 | `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | `YES` (untouched) |
| 417, 449 | `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | `MainActor` (untouched) |
| 418, 450 | `SWIFT_EMIT_LOC_STRINGS` | `YES` | `YES` (untouched) |
| 413, 445 | `PRODUCT_BUNDLE_IDENTIFIER` (app) | `lauterstar.gamekit` | `com.lauterstar.gamekit` |
| 467, 489 | `PRODUCT_BUNDLE_IDENTIFIER` (tests) | `lauterstar.gamekitTests` | `com.lauterstar.gamekit.tests` |
| 509, 529 | `PRODUCT_BUNDLE_IDENTIFIER` (UI tests) | `lauterstar.gamekitUITests` | `com.lauterstar.gamekit.uitests` |
| 420, 452, 473, 495, 515, 535 | `SWIFT_VERSION` | `5.0` | `6.0` |
| (new, all configs) | `SWIFT_STRICT_CONCURRENCY` | (absent) | `complete` |
| (new, app target package deps) | local SPM `../DesignKit` | (absent) | added via Xcode UI |

---

## Metadata

**Analog search scope:**
- `/Users/gabrielnielsen/Desktop/GameKit/gamekit/gamekit/**` (current, mostly Xcode template)
- `/Users/gabrielnielsen/Desktop/DesignKit/Sources/DesignKit/**` (component + token surface)
- `/Users/gabrielnielsen/Desktop/DesignKit/README.md` (consumer docs / Quickstart)
- `/Users/gabrielnielsen/Desktop/FitnessTracker/FitnessTracker/**` (sibling consumer — App, RootTabView, HomeView, SettingsView, SettingsComponents)

**Files scanned:**
- DesignKit: 11 source files (Theme, Components, Layout)
- FitnessTracker: 6 source files (FitnessTrackerApp, RootTabView, HomeView, SettingsView, SettingsComponents) — referenced for shape only, not copied wholesale
- GameKit current: 4 files (gamekitApp, ContentView, AppIcon Contents.json, project.pbxproj, gamekitTests)

**Pattern extraction date:** 2026-04-25
