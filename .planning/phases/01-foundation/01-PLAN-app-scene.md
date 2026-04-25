---
phase: 01-foundation
plan: 06
type: execute
wave: 3
depends_on: [1, 5]
files_modified:
  - gamekit/gamekit/App/GameKitApp.swift
  - gamekit/gamekit/Screens/RootTabView.swift
  - gamekit/gamekit/gamekitApp.swift
  - gamekit/gamekit/ContentView.swift
autonomous: true
requirements:
  - FOUND-01
  - FOUND-03
tags:
  - app-scene
  - thememanager
  - swiftui
  - folder-scaffold

must_haves:
  truths:
    - "The app's @main scene is GameKitApp, lives at gamekit/gamekit/App/GameKitApp.swift"
    - "ThemeManager is owned as @StateObject in GameKitApp and injected via .environmentObject"
    - "preferredColorScheme is derived from themeManager.mode (system/light/dark) — no DesignKit wrapper assumed"
    - "App.init does NO async work, NO eager DB construction, NO eager DesignKit work beyond ThemeManager() — keeping cold-start surface trivial per D-12"
    - "ContentView.swift and gamekitApp.swift (the Xcode template files) are deleted from the repo"
    - "Project compiles with Swift 6 strict concurrency, zero warnings"
  artifacts:
    - path: "gamekit/gamekit/App/GameKitApp.swift"
      provides: "@main scene; ThemeManager + RootTabView injection point"
      exports: ["GameKitApp"]
      contains: "@StateObject private var themeManager"
      min_lines: 20
  key_links:
    - from: "gamekit/gamekit/App/GameKitApp.swift"
      to: "DesignKit.ThemeManager"
      via: "import DesignKit + @StateObject"
      pattern: "import DesignKit"
    - from: "GameKitApp.body"
      to: "RootTabView"
      via: "WindowGroup root view"
      pattern: "RootTabView()"
---

<objective>
Replace Xcode's default app scene template with the canonical GameKit scene per ARCHITECTURE.md "Component Responsibilities" + DesignKit README Quickstart: a `@main` `GameKitApp: App` that owns a single `@StateObject ThemeManager`, injects it via `.environmentObject`, applies `.preferredColorScheme` from `themeManager.mode`, and renders `RootTabView()` (which Plan 07 will create as a forward-declaration stub during this plan's task 2 — see action notes below).

Purpose: Satisfies FOUND-03 (ThemeManager injection, every visible pixel reads tokens — enforced downstream) and the static portion of FOUND-01 (no async work / no eager DB / no eager DesignKit work in `App.init` per D-12). Also performs the structural cleanup: file-rename gamekitApp.swift → `App/GameKitApp.swift`, delete `ContentView.swift` (replaced by `RootTabView()` from Plan 07).

The `App/` folder is created by this plan as the location for `GameKitApp.swift`. Other folders (`Core/`, `Games/`, `Resources/`, `Screens/`, `Docs/` already exists, `App/` here) ship empty in P1 because their contents arrive in P2-P5. We create `Screens/` here only because Task 2 stubs `RootTabView` — `HomeView`, `SettingsView`, `StatsView` arrive in Plan 07.

Output: New `App/GameKitApp.swift` (~25 lines); placeholder `Screens/RootTabView.swift` (~10 lines, lands fully populated in Plan 07); `gamekitApp.swift` and `ContentView.swift` deleted; project builds with `BUILD SUCCEEDED` and zero warnings.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/01-foundation/01-CONTEXT.md
@.planning/phases/01-foundation/01-PATTERNS.md
@.planning/research/ARCHITECTURE.md
@./CLAUDE.md
@../DesignKit/README.md
@../DesignKit/Sources/DesignKit/Theme/ThemeManager.swift
@gamekit/gamekit/gamekitApp.swift
@gamekit/gamekit/ContentView.swift

<interfaces>
<!-- DesignKit ThemeManager public API (from ../DesignKit/Sources/DesignKit/Theme/ThemeManager.swift lines 4-65) -->

```swift
@MainActor
public final class ThemeManager: ObservableObject {
    @Published public var mode: ThemeMode { get set }   // .system | .light | .dark
    @Published public var preset: ThemePreset { get set }
    @Published public var overrides: ThemeOverrides? { get set }
    @Published public var customThemes: [CustomTheme] { get set }
    @Published public var activeCustomThemeID: UUID?

    public init(storage: ThemeStorage = UserDefaultsThemeStorage())

    public func resolvedScheme(using systemScheme: ColorScheme) -> ColorScheme
    public func theme(using systemScheme: ColorScheme) -> Theme
}
```

**Key:** DesignKit exposes `theme(using:)`, NOT `theme(for:)`. FitnessTracker has a local `theme(for:)` shim — GameKit MUST NOT replicate that shim (PATTERNS.md "Note A"). Use `theme(using:)` directly.

```swift
// ../DesignKit/Sources/DesignKit/Theme/ThemeMode.swift
public enum ThemeMode: String, CaseIterable, Codable {
    case system
    case light
    case dark
}
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Create App/GameKitApp.swift; create Screens/RootTabView.swift placeholder; delete legacy template files</name>
  <files>
    gamekit/gamekit/App/GameKitApp.swift
    gamekit/gamekit/Screens/RootTabView.swift
    gamekit/gamekit/gamekitApp.swift
    gamekit/gamekit/ContentView.swift
  </files>
  <read_first>
    - gamekit/gamekit/gamekitApp.swift (current content — 18 lines, default Xcode template)
    - gamekit/gamekit/ContentView.swift (current content — 25 lines, default Xcode template)
    - .planning/phases/01-foundation/01-PATTERNS.md §"`App/GameKitApp.swift` (app-scene, request-response)" (the slim-slice excerpt + P1 target shape, lines 40-100)
    - .planning/phases/01-foundation/01-PATTERNS.md §"`Screens/RootTabView.swift`" (full content arrives in Plan 07 — this plan only ships a build-clean stub)
    - .planning/phases/01-foundation/01-CONTEXT.md "D-11", "D-12" (no SwiftData, no signpost, no async work in App.init)
    - .planning/research/ARCHITECTURE.md "Component Responsibilities" table (GameKitApp row)
    - ./CLAUDE.md §3 (folder structure: App/, Core/, Games/, Screens/, Resources/, Docs/), §8.5 (≤500-line hard cap), §8.6 (`.foregroundStyle` not `.foregroundColor` on iOS 17+), §8.8 (Xcode 16 sync-root-group: drop files into folders, no pbxproj edit needed for files)
    - ../DesignKit/Sources/DesignKit/Theme/ThemeMode.swift (verify the `ThemeMode` enum's three cases exactly)
  </read_first>
  <action>
    Per CLAUDE.md §8.8: dropping new `.swift` files into `gamekit/gamekit/App/` and `gamekit/gamekit/Screens/` causes Xcode 16's `PBXFileSystemSynchronizedRootGroup` to auto-register them at next build. Do NOT hand-patch `project.pbxproj` to add these files. Do NOT add target memberships in the pbxproj.

    **Step 1: Create `gamekit/gamekit/App/GameKitApp.swift`** with EXACTLY this content (verbatim — including the comment header):

    ```swift
    //
    //  GameKitApp.swift
    //  gamekit
    //
    //  The single @main scene for GameKit.
    //  Owns ThemeManager (single source of truth for theming).
    //  Injects via .environmentObject so every screen consumes DesignKit tokens.
    //
    //  Phase 1 invariants (per D-11, D-12):
    //    - No SwiftData (ModelContainer arrives in P4)
    //    - No async work in App.init (cold-start <1s — keep surface trivial)
    //    - No eager DesignKit work beyond ThemeManager()
    //

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

    **Step 2: Create `gamekit/gamekit/Screens/RootTabView.swift`** as a build-clean STUB only — Plan 07 expands it to a 3-tab TabView. Stub content (verbatim):

    ```swift
    //
    //  RootTabView.swift
    //  gamekit
    //
    //  Plan 06 ships this as a build-clean stub.
    //  Plan 07 expands it to a 3-tab TabView (Home / Stats / Settings)
    //  with NavigationStack roots per D-02.
    //

    import SwiftUI
    import DesignKit

    struct RootTabView: View {
        @EnvironmentObject private var themeManager: ThemeManager
        @Environment(\.colorScheme) private var colorScheme

        private var theme: Theme { themeManager.theme(using: colorScheme) }

        var body: some View {
            // Plan 07 replaces this body with the 3-tab TabView.
            Color(theme.colors.background)
                .ignoresSafeArea()
        }
    }
    ```

    Note: `Color(theme.colors.background)` is NOT a hardcoded color literal — the parameter is a `theme.colors.X` rebind (PATTERNS.md "Pitfall 8 hard rule" — the hook does NOT need to reject `Color(...)` parameters where the argument is a token). However, to keep the pre-commit hook from flagging this on a future re-edit, prefer the equivalent `theme.colors.background` directly as a `View`-conforming background:

    Use this safer form instead:
    ```swift
    var body: some View {
        // Plan 07 replaces this body with the 3-tab TabView.
        Rectangle()
            .fill(theme.colors.background)
            .ignoresSafeArea()
    }
    ```

    `Rectangle().fill(theme.colors.background)` consumes the token without any `Color(...)` wrapper — the pre-commit hook is happy and the visual result is identical.

    **Step 3: Delete the legacy template files:**
    ```bash
    rm gamekit/gamekit/gamekitApp.swift
    rm gamekit/gamekit/ContentView.swift
    ```
    Per CLAUDE.md §8.8 the synchronized root group will pick up the deletions automatically; no pbxproj edit needed.

    **Step 4: Build the project to verify the rename + folder additions resolve:**
    ```bash
    xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | tail -50
    ```
    Expected: `BUILD SUCCEEDED`. If "two `@main` types" error appears, the deletion of `gamekitApp.swift` did not propagate — re-verify it is gone via `find gamekit/gamekit -name "gamekitApp.swift"`.

    **Step 5 (token-discipline guardrail):** since pre-commit hook is active (Plan 02), any subsequent commit that adds `Color.foo` to `Screens/` fails. Verify by running the hook against the staged diff once these files are added: `git add gamekit/gamekit/App/GameKitApp.swift gamekit/gamekit/Screens/RootTabView.swift && bash .githooks/pre-commit && echo "HOOK PASSED"`. Hook MUST exit 0 — if it complains about anything, fix the offending line before committing.

    Do NOT commit yet — that's the final orchestrator step.
  </action>
  <verify>
    <automated>xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -c "BUILD SUCCEEDED"</automated>
  </verify>
  <acceptance_criteria>
    - File `gamekit/gamekit/App/GameKitApp.swift` exists: `test -f gamekit/gamekit/App/GameKitApp.swift` exits 0
    - File `gamekit/gamekit/Screens/RootTabView.swift` exists: `test -f gamekit/gamekit/Screens/RootTabView.swift` exits 0
    - File `gamekit/gamekit/gamekitApp.swift` is GONE: `test ! -f gamekit/gamekit/gamekitApp.swift` exits 0
    - File `gamekit/gamekit/ContentView.swift` is GONE: `test ! -f gamekit/gamekit/ContentView.swift` exits 0
    - GameKitApp.swift is exactly the @main scene: `grep -c "@main" gamekit/gamekit/App/GameKitApp.swift` returns exactly `1`
    - GameKitApp owns ThemeManager as @StateObject: `grep -c "@StateObject private var themeManager = ThemeManager()" gamekit/gamekit/App/GameKitApp.swift` returns exactly `1`
    - GameKitApp imports DesignKit: `grep -c "^import DesignKit" gamekit/gamekit/App/GameKitApp.swift` returns exactly `1`
    - GameKitApp injects via environmentObject: `grep -c ".environmentObject(themeManager)" gamekit/gamekit/App/GameKitApp.swift` returns exactly `1`
    - GameKitApp applies preferredColorScheme: `grep -c ".preferredColorScheme(preferredScheme)" gamekit/gamekit/App/GameKitApp.swift` returns exactly `1`
    - GameKitApp does NOT touch SwiftData (D-11): `grep -c "ModelContainer\|@Model\|modelContainer" gamekit/gamekit/App/GameKitApp.swift` returns exactly `0`
    - GameKitApp does NOT contain async / Task / signpost / DB init (D-12): `grep -cE "Task\.detached|os_signpost|getCredentialState|Tips.configure" gamekit/gamekit/App/GameKitApp.swift` returns exactly `0`
    - GameKitApp uses theme(using:) NOT theme(for:) (PATTERNS Note A): `grep -c "theme(for:" gamekit/gamekit/App/GameKitApp.swift` returns exactly `0` (RootTabView.swift uses `theme(using:)` — verified separately)
    - RootTabView uses theme(using:): `grep -c "themeManager.theme(using: colorScheme)" gamekit/gamekit/Screens/RootTabView.swift` returns exactly `1`
    - RootTabView consumes ThemeManager via env: `grep -c "@EnvironmentObject private var themeManager: ThemeManager" gamekit/gamekit/Screens/RootTabView.swift` returns exactly `1`
    - File size caps respected: `[ $(wc -l < gamekit/gamekit/App/GameKitApp.swift) -le 50 ] && [ $(wc -l < gamekit/gamekit/Screens/RootTabView.swift) -le 30 ]` exits 0
    - No Finder dupes anywhere: `find gamekit -name "* 2.swift"` returns no results
    - Build succeeds with strict warnings: `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -c "BUILD SUCCEEDED"` returns at least `1`
    - Build emitted zero warnings: `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -cE "warning:"` returns exactly `0`
    - Pre-commit hook accepts the new files: `git add gamekit/gamekit/App/GameKitApp.swift gamekit/gamekit/Screens/RootTabView.swift && bash .githooks/pre-commit` exits 0
  </acceptance_criteria>
  <done>App/GameKitApp.swift + Screens/RootTabView.swift exist; legacy gamekitApp.swift / ContentView.swift gone; build succeeds; pre-commit hook passes; zero warnings under strict concurrency.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none in P1) | App scene only constructs ThemeManager (which reads from UserDefaults via DesignKit's default storage). No network, no auth, no user input. The single boundary is "ThemeManager → UserDefaults" — handled inside DesignKit. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-11 | Tampering | UserDefaults (theme prefs) | accept | Theme preferences are non-security-critical. UserDefaults is not encrypted but a tampering attacker would only force a cosmetic change (preset / mode). No PII, no auth state. |
| T-01-12 | Information Disclosure | UserDefaults (theme prefs) | accept | Theme mode + preset choice are not sensitive data. CONTEXT D-12 explicitly defers cold-start instrumentation, so no `os_signpost` data is logged. |

**N/A categories:** Spoofing, Repudiation, DoS, Elevation of Privilege — App.init is intentionally trivial per D-12 (no async, no DB, no network).
</threat_model>

<verification>
After Task 1:
- `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` exits 0 with `BUILD SUCCEEDED` and zero warnings.
- `find gamekit/gamekit -maxdepth 2 -type f \( -name "*.swift" \)` lists exactly: `gamekit/gamekit/App/GameKitApp.swift`, `gamekit/gamekit/Screens/RootTabView.swift` (no leftover gamekitApp.swift or ContentView.swift).
- All 17 grep-based acceptance criteria pass.
</verification>

<success_criteria>
- App/GameKitApp.swift is the single `@main` scene; ThemeManager is a `@StateObject`; injection + preferredColorScheme wired correctly per ARCHITECTURE Pattern 4.
- Screens/RootTabView.swift is a build-clean stub (Plan 07 expands it).
- Legacy template files removed.
- Build is green under Swift 6 strict concurrency with zero warnings.
- Pre-commit hook passes on the new files.
- No SwiftData, no signpost, no async work in App.init (D-11, D-12 honored).
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-06-SUMMARY.md` per the template.
</output>
