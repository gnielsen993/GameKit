# Phase 4: Stats & Persistence — Pattern Map

**Mapped:** 2026-04-25
**Files in scope:** 18 (12 NEW production / test, 6 EDIT existing — see classification table)
**Analogs found:** 8 / 18 strong (file-header convention, themed-shell view, DKCard wrapping, ThemeManager env wiring, `String(localized:)` localization, Swift Testing scaffold, in-memory test fixtures, P3 settings row a11y idiom). 10 NEW PATTERNS — Phase 4 is the **first SwiftData phase** in this codebase: no `@Model` class, no `@Query`, no `ModelContainer`, no `@Observable` UserDefaults wrapper, no JSON envelope, no `fileExporter`/`fileImporter`, no batch-delete transaction, no in-memory `ModelContainer` test helper, no `enum`-namespace static-method service, no `EnvironmentKey` for non-Theme objects.

**Genuine "NEW PATTERN" rows:** 10 — `GameRecord` / `BestTime` (`@Model`), `GameKind` / `Outcome` (raw-string serialization enums), `GameStats` (`final class` with `ModelContext`-state and `os.Logger`), `StatsExporter` + `StatsExportEnvelope` + `StatsExportDocument` + `StatsImportError` (file-I/O sibling group), `SettingsStore` + `EnvironmentKey` (Observable UserDefaults wrapper), `InMemoryStatsContainer` (test fixture), the three Core/-test files (Swift-Testing × `@MainActor` × in-memory `ModelContainer`).

**Critical correction vs. RESEARCH:** RESEARCH §Pattern 5 shows `let sharedContainer: ModelContainer` constructed in `GameKitApp.init`. The repo's existing `GameKitApp.swift` uses `@StateObject themeManager = ThemeManager()` and an `init`-less `App` body shape. The plan must adapt — see `App/GameKitApp.swift` row below.

**Critical correction vs. RESEARCH:** RESEARCH §Code Examples 4 shows the VM accepting `gameStats: GameStats? = nil` directly in `init`. The existing `MinesweeperViewModel.swift` (lines 92–107) already has 4 init params (difficulty, userDefaults, clock, rng); the P4 edit must add the 5th param `gameStats:` consistently with the existing tail-of-init injection-seam pattern. The init-set-after pattern (Open Question 1, Pitfall 8 hoisting) is a planner-discretion item; the established pattern in this repo is **init-injection of seams** (proven in `MinesweeperViewModel.init` for `userDefaults` / `clock` / `rng`).

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `gamekit/gamekit/Core/GameKind.swift` (NEW, ~25 lines) | model (raw-string enum) | value-type (canonical serialization key) | `gamekit/gamekit/Games/Minesweeper/MinesweeperDifficulty.swift` (raw-string enum, P2 D-02 serialization key) | role-match — same "raw-string-as-stable-key" idiom; P4's `case minesweeper` mirrors P2's `case easy/medium/hard` shape |
| `gamekit/gamekit/Core/Outcome.swift` (NEW, ~20 lines) | model (raw-string enum) | value-type | `MinesweeperDifficulty.swift` | role-match — same idiom |
| `gamekit/gamekit/Core/GameRecord.swift` (NEW, ~70 lines) | model (`@Model final class`) | persistence record (CloudKit-compat) | None — first `@Model` in repo | NEW PATTERN |
| `gamekit/gamekit/Core/BestTime.swift` (NEW, ~55 lines) | model (`@Model final class`) | persistence record (CloudKit-compat) | None | NEW PATTERN |
| `gamekit/gamekit/Core/GameStats.swift` (NEW, ~120 lines) | service (write boundary) | request-response (insert/save) + transform (BestTime evaluation) | None — first `final class` service with `ModelContext` state | NEW PATTERN (loosely models on test-helper enum-namespace shape from `gamekitTests/Helpers/MinesweeperVMFixtures.swift` — but that's `enum`, this is `final class` for `modelContext` ivar) |
| `gamekit/gamekit/Core/StatsExportEnvelope.swift` (NEW, ~60 lines) | model (`Codable` envelope) | value-type (serialization mirror) | None — first `Codable` envelope; closest is `Codable` conformance on engine `Board`/`Cell` (P2) | role-match (Codable value type), NEW PATTERN (envelope-with-schemaVersion shape) |
| `gamekit/gamekit/Core/StatsExporter.swift` (NEW, ~140 lines) | service (`enum`-namespace static funcs) | file-I/O (encode/decode + transactional replace) | `gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` `enum` namespace + `static func` shape | role-match (enum-namespace), NEW PATTERN for SwiftData transaction + JSON encode |
| `gamekit/gamekit/Core/StatsExportDocument.swift` (NEW, ~30 lines) — *or inline at bottom of `StatsExporter.swift`* | model (`FileDocument` wrapper) | file-I/O (UTType + Data passthrough) | None | NEW PATTERN |
| `gamekit/gamekit/Core/StatsImportError.swift` (NEW, ~30 lines) — *or inline at bottom of `StatsExporter.swift`* | model (`LocalizedError` enum) | value-type | None | NEW PATTERN |
| `gamekit/gamekit/Core/SettingsStore.swift` (NEW, ~50 lines) | model (`@Observable final class` over UserDefaults) + `EnvironmentKey` | observable read/write (key-value) | `MinesweeperViewModel.swift` (`@Observable @MainActor final class` + UserDefaults persistence at line 192) | role-match (Observable + UserDefaults), but NEW PATTERN for `EnvironmentKey` injection (the only other env-injected object in the repo is `ThemeManager` via `@EnvironmentObject` in `GameKitApp.swift:25`, which is a different injection mechanism) |
| `gamekit/gamekit/App/GameKitApp.swift` (EDIT, ~30-line diff) | app entry | env composition + container construction | self (existing 38-line file) | self-edit — extend `init()`, add `sharedContainer`, add `.modelContainer(...)` and `.environment(\.settingsStore, ...)` |
| `gamekit/gamekit/Screens/StatsView.swift` (REWRITE, ~140 lines) | view (data-driven, owns `@Query`) | request-response (query → derived rows) + empty state | `gamekit/gamekit/Screens/HomeView.swift` (themed-shell + DKCard composition) AND P3 `MinesweeperHeaderBar` `.monospacedDigit()` pairing pattern | role-match for shell + DKCard; NEW PATTERN for `@Query` + `Grid` + `#Predicate` |
| `gamekit/gamekit/Screens/SettingsView.swift` (EDIT, ~120-line diff) | view (modal flows) | event-driven (3 modal flags + `@Environment(\.modelContext)`) | `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` (multiple `.alert` + `@State` flags pattern) | role-match (alert binding pattern); NEW PATTERN for `.fileExporter`/`.fileImporter` + security-scoped URL |
| `gamekit/gamekit/Screens/SettingsView.swift` — file-private `SettingsActionRow` | view (file-private, props-only) | request-response (closure callback) | `gamekit/gamekit/Screens/SettingsComponents.swift` `settingsNavRow` (helper-style row) | role-match (HStack + glyph + label idiom), but adds `.contentShape(Rectangle())` + tap-action closure (no chevron — UI-SPEC contract) |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` (EDIT, ~25-line diff) | view-model (existing) | event-driven (terminal-state → `recordTerminalState()`) | self (existing 279-line file) | self-edit — add 5th init param `gameStats: GameStats?`, add `private func recordTerminalState(outcome:)`, call from terminal transitions in `reveal(at:)` lines 135–144 |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` (EDIT, ~10-line diff) | view (existing top-level scene) | env composition (`@Environment(\.modelContext)` → GameStats → VM) | self (existing 146-line file) | self-edit — wire `@Environment(\.modelContext)` and rebuild `_viewModel` with injected `GameStats` |
| `gamekit/gamekit/Resources/Localizable.xcstrings` (EDIT, +~15 keys) | resource (string catalog) | resource | self (existing seed, 25 P1 keys + ~30 P3 keys) | self-edit (auto-extracted via `SWIFT_EMIT_LOC_STRINGS=YES`) |
| `gamekit/gamekitTests/Helpers/InMemoryStatsContainer.swift` (NEW, ~30 lines) | test helper (factory) | factory (configuration → container) | `gamekit/gamekitTests/Helpers/SeededGenerator.swift` (test-only helper, factory-style) | role-match (test-only helper at same path); NEW PATTERN for `ModelContainer` factory |
| `gamekit/gamekitTests/Core/GameStatsTests.swift` (NEW, ~250 lines, 8 tests) | test (Swift Testing) | request-response (deterministic) | `gamekit/gamekitTests/Engine/BoardGeneratorTests.swift` (Swift Testing scaffold, `@Suite`, `@Test`, `#expect`, deterministic seed pattern) | role-match — same Swift Testing scaffold; NEW PATTERN for `@MainActor` × `try modelContext` × `InMemoryStatsContainer.make()` |
| `gamekit/gamekitTests/Core/StatsExporterTests.swift` (NEW, ~200 lines, 6 tests) | test (Swift Testing) | request-response | `BoardGeneratorTests.swift` | role-match (scaffold); NEW PATTERN for round-trip JSON byte equality + schemaVersion-mismatch path |
| `gamekit/gamekitTests/Core/ModelContainerSmokeTests.swift` (NEW, ~80 lines, 3 tests) | test (Swift Testing, smoke) | request-response | `BoardGeneratorTests.swift` | role-match (scaffold); NEW PATTERN for the dual `.none` / `.private(...)` configuration check |

**Folder note:** `gamekit/gamekit/Core/` is a NEW top-level folder. Synchronized root group (Xcode 16 `objectVersion = 77`) auto-registers per CLAUDE.md §8.8 (validated by P2's NEW `Games/Minesweeper/` and `Games/Minesweeper/Engine/` and by P4's planned `gamekitTests/Core/` mirror). Per `02-PATTERNS.md` line 27: "The planner's first action's success criterion should include 'build green after adding a single empty placeholder file' to confirm auto-registration covers nested-folder creation." Repeat for P4: first-task placeholder check is recommended.

**Critical inheritance from P2/P3:** raw-string `MinesweeperDifficulty.rawValue` (`"easy" | "medium" | "hard"`) is the canonical serialization key for `difficultyRaw` on both `GameRecord` and `BestTime` per CONTEXT D-05. Renaming a case = data break — locked since P2 D-02. The P4 plan must NOT redefine these values; it consumes them via `MinesweeperDifficulty.rawValue` at the VM call site (D-15) and via the literal string `"minesweeper"` for `GameKind`.

---

## Pattern Assignments

### Established pattern: file-header convention (applies to ALL 12 NEW files)

**Analog:** `gamekit/gamekit/App/GameKitApp.swift` lines 1–13; `gamekit/gamekit/Games/Minesweeper/MinesweeperBoard.swift` lines 1–22; `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` lines 1–18; `gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` lines 1–19. Locked by `02-PATTERNS.md`; inherited by `03-PATTERNS.md`.

**What to copy:** purpose blurb (1 paragraph) + phase-decision references in parentheses (e.g. "per D-08", "per D-15") + invariant callouts where load-bearing.

**Excerpt from `MinesweeperViewModel.swift` lines 1–18:**
```swift
//
//  MinesweeperViewModel.swift
//  gamekit
//
//  @Observable @MainActor orchestrator that turns the locked P2 engine API
//  (BoardGenerator + RevealEngine + WinDetector) into a UI-consumable state
//  surface. Owns timer state, scenePhase pause/resume math (D-05/D-06),
//  first-tap board generation (D-07), terminal-state freeze (D-08), and
//  difficulty persistence via UserDefaults `mines.lastDifficulty` (D-11).
//
//  Phase 3 invariants (per ARCHITECTURE Anti-Pattern 1, RESEARCH §Pattern 2):
//    - Foundation-only — no SwiftUI, no Combine, no SwiftData (animation
//      and persistence are view-tier and P4 concerns)
//    - @MainActor — all state mutation is single-threaded; the engines are
//      Sendable so this is safe by construction
//    - First-tap-safety preserved end-to-end (CLAUDE.md §8.11): the .idle
//      branch in reveal(at:) is the ONLY path that calls BoardGenerator.generate
//
```

**Apply to each P4 file:**
- 1-paragraph purpose blurb naming the responsibility (per UI-SPEC §Component Inventory).
- "Phase 4 invariants (per D-XX, D-YY)" block citing CONTEXT decisions.
- Anti-pattern call-outs where load-bearing — e.g. `GameRecord.swift` MUST mention "every property optional or defaulted; no `@Attribute(.unique)`" (RESEARCH Pitfalls 1+2). `GameStats.swift` MUST mention "explicit `try modelContext.save()` — no autosave reliance" (RESEARCH Pitfall 10). `StatsExporter.swift` MUST mention "decode-then-validate-then-transaction order" (RESEARCH Pitfall 6).

---

### Established pattern: themed view shell (applies to `StatsView.swift` rewrite)

**Analog:** `gamekit/gamekit/Screens/StatsView.swift` lines 13–46 (existing P1 stub) + `gamekit/gamekit/Screens/HomeView.swift` lines 19–54.

**What to copy** (existing `StatsView.swift` already implements this — PRESERVE the shell, replace the content):
```swift
import SwiftUI
import DesignKit

struct StatsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    // ... content ...
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Stats"))
        }
    }
}
```

**P4 changes (rewrite content only — keep shell):**
- Add 2 `@Query` declarations at top (between `private var theme` and `body`):
  ```swift
  @Query(
      filter: #Predicate<GameRecord> { $0.gameKindRaw == "minesweeper" },
      sort: \.playedAt,
      order: .reverse
  )
  private var minesRecords: [GameRecord]

  @Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "minesweeper" })
  private var minesBestTimes: [BestTime]
  ```
- Add `import SwiftData` (NEW — not in P1 stub).
- Replace `settingsSectionHeader(theme: theme, "HISTORY")` + `"BEST TIMES"` with single `settingsSectionHeader(theme: theme, String(localized: "MINESWEEPER"))` + DKCard with `Grid` per UI-SPEC §Layout & Sizing.
- Empty-state branch when `minesRecords.isEmpty`: `Text(String(localized: "No games played yet."))` rendered with `theme.typography.body` + `theme.colors.textTertiary` per UI-SPEC §Color row "Text tertiary" + §Typography row "Empty state body".

**Pre-commit hook reminder** (`.githooks/pre-commit` lines 14–34): `Screens/StatsView.swift` is scoped by the hook. `Color(...)` literal, `cornerRadius: <int>`, or `.padding(<int>)` blocks the commit. All token consumption MUST go through `theme.{spacing, colors, radii, typography}`.

---

### Established pattern: DKCard wrapping (applies to `StatsView.swift` rewrite + new SettingsView "DATA" section)

**Analog:** `/Users/gabrielnielsen/Desktop/DesignKit/Sources/DesignKit/Components/DKCard.swift` lines 12–21 (component itself) + `gamekit/gamekit/Screens/HomeView.swift` lines 61–86 (consumption); locked by `03-PATTERNS.md` "Established pattern: DKCard wrapping".

**Excerpt from `DKCard.swift` lines 12–21:**
```swift
public var body: some View {
    content
        .padding(theme.spacing.l)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
}
```

**What to copy:** `DKCard(theme: theme) { content }` is the exclusive container for surface-tinted UI in this app. **Do NOT redeclare** the radius/border/padding — DKCard already supplies them. Per UI-SPEC §Component Inventory: "Do not duplicate this styling locally."

**Apply to:**
- `StatsView.swift` MINESWEEPER card — wraps the `Grid` (or empty-state Text)
- `SettingsView.swift` DATA section card — wraps the 3 SettingsActionRow + 2 inter-row dividers

---

### Established pattern: ThemeManager + colorScheme env wiring (applies to NEW StatsView additions + SettingsView edit)

**Analog:** `gamekit/gamekit/App/GameKitApp.swift` lines 19–27 (creator); `gamekit/gamekit/Screens/RootTabView.swift` lines 14–37 (consumer); `gamekit/gamekit/Screens/StatsView.swift` lines 13–17 (current consumer). Locked by P1, inherited by P3.

**Existing creator excerpt** (`GameKitApp.swift` lines 18–28):
```swift
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
```

**P4 edit shape** (extend, do NOT replace — preserve the `themeManager` injection seam):
```swift
@main
struct GameKitApp: App {
    @StateObject private var themeManager = ThemeManager()
    @State private var settingsStore: SettingsStore
    let sharedContainer: ModelContainer

    init() {
        // SettingsStore must be constructed BEFORE the container so
        // cloudSyncEnabled is available for ModelConfiguration (D-08).
        let store = SettingsStore()
        _settingsStore = State(initialValue: store)

        let schema = Schema([GameRecord.self, BestTime.self])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: store.cloudSyncEnabled
                ? .private("iCloud.com.lauterstar.gamekit")
                : .none
        )
        do {
            sharedContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to construct ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(themeManager)
                .environment(\.settingsStore, settingsStore)
                .preferredColorScheme(preferredScheme)
                .modelContainer(sharedContainer)
        }
    }

    private var preferredScheme: ColorScheme? { /* unchanged */ }
}
```

**Critical (RESEARCH Pattern 5 footnote 2 + RESEARCH Pitfall 11 by inheritance):** the `iCloud.com.lauterstar.gamekit` container ID does NOT need to be provisioned in `Entitlements.plist` for P4's `cloudKitDatabase: .none` default path. The smoke test exercises `.private(...)` only via `isStoredInMemoryOnly: true` — schema constraints validate without an iCloud handshake (RESEARCH Assumption A2, MEDIUM risk).

**Consumers (`StatsView`, `SettingsView`)** keep the existing `@EnvironmentObject themeManager` + `@Environment(\.colorScheme)` + `private var theme` pattern. Add `@Environment(\.modelContext)` + (in SettingsView only) `@Environment(\.settingsStore)` as siblings.

---

### Established pattern: `String(localized:)` localization (applies to all NEW user-visible strings)

**Analog:** `gamekit/gamekit/Screens/HomeView.swift` lines 41, 76, 117–125; `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` lines 70, 80, 91–101. Locked by `03-PATTERNS.md` "Established pattern: localized strings via `String(localized:)`".

**What to copy:**
```swift
.navigationTitle(String(localized: "Stats"))                              // existing StatsView:43
Text(String(localized: "No games played yet."))                            // NEW empty state (D-26 verbatim)
Button(String(localized: "Reset all stats"), role: .destructive) { ... }   // NEW alert button
```

**P4 string surfaces (per UI-SPEC §Copywriting Contract):** approximately 15 new keys land in `Resources/Localizable.xcstrings` via `SWIFT_EMIT_LOC_STRINGS=YES` auto-extraction (FOUND-04, on by default). Notable keys:
- `"MINESWEEPER"` — section header (StatsView)
- `"Games"`, `"Wins"`, `"Win %"`, `"Best"` — column headers
- `"Easy"`, `"Medium"`, `"Hard"` — already-shipped P3 keys (REUSE — don't add duplicates)
- `"No games played yet."` — empty state (SC2 verbatim)
- `"DATA"`, `"Export stats"`, `"Import stats"`, `"Reset stats"` — Settings DATA section
- `"Reset all stats?"`, `"This deletes all your Minesweeper games and best times. This can't be undone."`, `"Reset all stats"`, `"Cancel"` — reset alert
- `"Couldn't import stats"`, `"This file was exported from a newer GameKit. Update the app and try again."`, `"The file couldn't be read. Check that it's a GameKit stats export and try again."`, `"OK"` — import-error alert

**Pre-merge gate** (RESEARCH Pitfall 8 inheritance from P3): open `Localizable.xcstrings` in Xcode → filter "Stale" → delete orphans. xcstrings auto-extracts NEW keys but does NOT auto-delete renamed/removed keys.

---

### Established pattern: Swift Testing scaffold (applies to 3 NEW Core/-test files)

**Analog:** `gamekit/gamekitTests/Engine/BoardGeneratorTests.swift` lines 1–24; `gamekit/gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift` lines 1–43. Locked by `02-PATTERNS.md` "Swift Testing scaffold"; inherited by P3.

**Imports + scaffold excerpt from `BoardGeneratorTests.swift` lines 12–24:**
```swift
import Testing
import Foundation
@testable import gamekit

@Suite("BoardGenerator")
nonisolated struct BoardGeneratorTests {

    static let seeds: [UInt64] = (0..<100).map { i in
        UInt64(i &+ 1) &* 0x9E37_79B9_7F4A_7C15
    }
    // ...
}
```

**`@MainActor` requirement excerpt from `MinesweeperViewModelTests.swift` lines 19–21:**
```swift
@MainActor
@Suite("MinesweeperViewModel")
struct MinesweeperViewModelTests {
```

**Apply to each Core test file:**
- `import Testing`, `import Foundation`, `@testable import gamekit` — same triplet.
- `@MainActor` annotation on the suite (RESEARCH Pattern 6 + Code Examples 5) — `ModelContext` is NOT `Sendable`; `mainContext` MUST be touched on the main actor.
- `@Suite("...")` annotation on the wrapping `struct` for natural namespacing.
- `@Test func ...()` per success criterion. Imports nothing else from production code beyond the public/internal types being tested.
- Use `try` directly (Swift Testing surfaces throws automatically — no need for `XCTAssertNoThrow` wrappers).

**Critical correction vs. P2 convention:** P2's `BoardGeneratorTests` uses `nonisolated struct` (engines are pure value-types — no actor isolation needed). P4's Core tests MUST use `@MainActor struct` (SwiftData `ModelContext` is main-actor-bound per RESEARCH Pattern 6 citation `[CITED: hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency]`).

---

### Established pattern: in-memory test fixture helper (applies to `InMemoryStatsContainer.swift`)

**Analog:** `gamekit/gamekitTests/Helpers/SeededGenerator.swift` (entire file, 40 lines) — same path, same role (test-only, factory-shaped helper).

**Existing excerpt from `SeededGenerator.swift` lines 1–24:**
```swift
//
//  SeededGenerator.swift
//  gamekitTests
//
//  Deterministic SplitMix64 PRNG for engine tests (CONTEXT D-12).
//  ...
//  Critical placement (D-12): TEST TARGET ONLY. If this file ends up in
//  the production app target, engine purity (ROADMAP P2 SC5) is violated
//  ...

import Foundation

/// SplitMix64 (Steele-Lea-Flood, 2014). ...
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    // ...
}
```

**Apply to `InMemoryStatsContainer.swift`** (per RESEARCH Pattern 6 + D-31):
```swift
//
//  InMemoryStatsContainer.swift
//  gamekitTests
//
//  Test-only ModelContainer factory (D-31). Always uses
//  isStoredInMemoryOnly: true so simulator state never leaks between
//  tests. Optionally pairs with a CloudKit configuration so the SC3
//  smoke test can validate schema constraints WITHOUT contacting iCloud
//  (RESEARCH Pattern 6 + Assumption A2).
//
//  Critical placement: TEST TARGET ONLY. If this file ends up in the
//  production app target, the in-memory configuration would break
//  PERSIST-02's force-quit survival guarantee.
//

import SwiftData
@testable import gamekit

@MainActor
enum InMemoryStatsContainer {
    static func make(
        cloudKit: ModelConfiguration.CloudKitDatabase = .none
    ) throws -> ModelContainer {
        let schema = Schema([GameRecord.self, BestTime.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: cloudKit
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

**Critical:** `enum`-namespace (uninhabited type, static method) matches the P2 idiom `BoardGenerator` / `RevealEngine` / `WinDetector` per `02-PATTERNS.md` "NEW PATTERN: pure-Foundation engine struct/enum namespace" — for P4 it's the right shape because the helper carries no state, only a factory function.

---

### Established pattern: alert binding pattern (applies to SettingsView Reset + Import-error alerts)

**Analog:** `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` lines 90–102 (single-binding `.alert`).

**Existing excerpt from `MinesweeperGameView.swift` lines 90–102:**
```swift
.alert(
    String(localized: "Abandon current game?"),
    isPresented: $viewModel.showingAbandonAlert
) {
    Button(String(localized: "Cancel"), role: .cancel) {
        viewModel.cancelDifficultyChange()
    }
    Button(String(localized: "Abandon"), role: .destructive) {
        viewModel.confirmDifficultyChange()
    }
} message: {
    Text(String(localized: "Your in-progress game will be lost."))
}
```

**Apply to `SettingsView.swift`** (TWO alerts on the view — Reset + ImportError):

**Reset alert (D-22, D-23):**
```swift
.alert(
    String(localized: "Reset all stats?"),
    isPresented: $isResetAlertPresented
) {
    Button(String(localized: "Cancel"), role: .cancel) {}
    Button(String(localized: "Reset all stats"), role: .destructive) {
        try? gameStats.resetAll()    // failure logged via os.Logger; UI continues
    }
} message: {
    Text(String(localized: "This deletes all your Minesweeper games and best times. This can't be undone."))
}
```

**Import-error alert (D-21 + UI-SPEC §Copywriting "Generic import error"):**
```swift
.alert(
    String(localized: "Couldn't import stats"),
    isPresented: $isImportErrorAlertPresented,
    presenting: importErrorMessage
) { _ in
    Button(String(localized: "OK"), role: .cancel) {}
} message: { msg in
    Text(msg)
}
```

The `presenting:` overload is needed because the body copy differs by error type (schema-mismatch vs generic). The `@State var importErrorMessage: LocalizedStringKey?` is set by the `.fileImporter` `onCompletion` closure based on the `StatsImportError` case (D-21 schema-mismatch → "This file was exported from a newer GameKit…"; default → "The file couldn't be read…").

**Critical:** alert role on the title (not on individual buttons) — the existing P3 pattern shipped without `role:` on `.alert(_:isPresented:)`; iOS infers destructive styling from `Button(role: .destructive)`. UI-SPEC §Layout & Sizing confirms.

---

### Established pattern: settings row helper (applies to NEW file-private `SettingsActionRow` in `SettingsView.swift`)

**Analog:** `gamekit/gamekit/Screens/SettingsComponents.swift` lines 23–36 (`settingsNavRow` `@ViewBuilder` helper).

**Existing excerpt from `SettingsComponents.swift` lines 23–36:**
```swift
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
```

**Apply to `SettingsActionRow`** (per UI-SPEC §Component Inventory + §Layout & Sizing):
```swift
private struct SettingsActionRow: View {
    let theme: Theme
    let glyph: String
    let label: String
    let glyphTint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.s) {
                Image(systemName: glyph)
                    .foregroundStyle(glyphTint)
                Text(label)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
            }
            .frame(minHeight: 44)             // HIG min target — UI-SPEC §Spacing carve-out
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

**Differences vs. `settingsNavRow`:**
- No trailing chevron (action rows are not nav rows — UI-SPEC §Component Inventory).
- Glyph leading (Export = `square.and.arrow.up`, Import = `square.and.arrow.down`, Reset = `trash`).
- Action closure (button) instead of pure presentation.
- Glyph tint is a parameter — Reset uses `theme.colors.danger`; Export/Import use `theme.colors.textPrimary` per UI-SPEC §Color "Destructive reserved-for list".

**Critical token discipline** (`.githooks/pre-commit` lines 14–34): `.frame(minHeight: 44)` is allowed (the regex `\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)` does NOT match `.frame(minHeight:)` — confirmed in `03-PATTERNS.md` line 552). The `44` is HIG-derived component-intrinsic dimension per UI-SPEC §Spacing exception.

---

### NEW PATTERN: CloudKit-compatible `@Model` schema (applies to `GameRecord.swift`, `BestTime.swift`)

**No analog in repo.** P4 is the first SwiftData phase. Reference: RESEARCH §Pattern 1 + RESEARCH Pitfalls 1+2 + CONTEXT D-01..D-06.

**Imports template:**
```swift
import Foundation
import SwiftData
```

**Type-declaration shape (verbatim from RESEARCH §Pattern 1 + CONTEXT D-02 — quote into PLAN):**
```swift
@Model
final class GameRecord {
    var id: UUID = UUID()
    var gameKindRaw: String = GameKind.minesweeper.rawValue
    var difficultyRaw: String = ""           // "easy" | "medium" | "hard" — locked P2 D-02
    var outcomeRaw: String = ""              // "win" | "loss"
    var durationSeconds: Double = 0
    var playedAt: Date = .now
    var schemaVersion: Int = 1

    // Computed accessors — safe fallbacks per D-02
    var gameKind: GameKind { GameKind(rawValue: gameKindRaw) ?? .minesweeper }
    var outcome: Outcome { Outcome(rawValue: outcomeRaw) ?? .loss }

    init(
        gameKind: GameKind = .minesweeper,
        difficulty: String,
        outcome: Outcome,
        durationSeconds: Double,
        playedAt: Date = .now
    ) {
        self.gameKindRaw = gameKind.rawValue
        self.difficultyRaw = difficulty
        self.outcomeRaw = outcome.rawValue
        self.durationSeconds = durationSeconds
        self.playedAt = playedAt
    }
}
```

**Same shape applies to `BestTime`** with `seconds: Double = 0` + `achievedAt: Date = .now` (no `outcomeRaw` because BestTime is win-only by construction; no `playedAt` because `achievedAt` carries that semantics; no `recordId` per D-03).

**Load-bearing rules (RESEARCH Pitfalls 1+2 — call out in file header):**
- **Every property is optional or defaulted.** No `var x: Type` without `= default` or `?`. Compile-fine, CloudKit-init-throw is the failure mode.
- **No `@Attribute(.unique)`.** Compile-fine, CloudKit-init-throw is the failure mode.
- **No required relationships.** P4 has zero relationships, so this is automatic.
- **`schemaVersion: Int = 1`** is a userland convention (RESEARCH Assumption A1, LOW risk) — it's the field that survives the JSON round-trip (D-17) and acts as a forward-compat gate.

---

### NEW PATTERN: `enum`-namespace static-method service (applies to `StatsExporter.swift`)

**Analog:** `gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` lines 23–25 (`nonisolated enum RevealEngine`); `gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift` lines 25–27 (`nonisolated enum WinDetector`); `gamekit/gamekitTests/Helpers/MinesweeperVMFixtures.swift` lines 16 (`enum MinesweeperVMFixtures`). Engine pattern from `02-PATTERNS.md` "NEW PATTERN: pure-Foundation engine struct/enum namespace".

**Existing excerpt from `RevealEngine.swift` lines 23–25:**
```swift
/// Pure-function namespace for reveal logic. Stateless; uninhabited (`enum`).
/// Foundation-only — ROADMAP P2 SC5.
nonisolated enum RevealEngine {
```

**Apply to `StatsExporter.swift`** (D-16 + RESEARCH §Pattern 3) — note that `StatsExporter` is NOT `nonisolated` because `ModelContext` is main-actor-bound:
```swift
import Foundation
import SwiftData
import os

@MainActor
enum StatsExporter {
    private static let envelopeSchemaVersion = 1
    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "persistence"
    )

    static func export(modelContext: ModelContext) throws -> Data { ... }
    static func importing(_ data: Data, modelContext: ModelContext) throws { ... }
}
```

**Differences from P2 engines:**
- `@MainActor` annotation (P2 used `nonisolated` for Foundation-only purity).
- `import SwiftData` (P2 strictly forbade — P2's engine purity rule does NOT apply to `Core/` services per ARCHITECTURE Component Responsibilities).
- `import os` for `Logger` per RESEARCH §Standard Stack table.

**Critical (RESEARCH Pitfall 6 — quote into PLAN):** the `importing(_:modelContext:)` flow MUST be: decode-first → validate `schemaVersion` → THEN open transaction. Wrong order destroys existing data on schema-mismatch.

---

### NEW PATTERN: `final class` service with `ModelContext` ivar + `os.Logger` (applies to `GameStats.swift`)

**No analog in repo.** RESEARCH §Pattern 2 + CONTEXT D-11..D-15.

**Type-declaration shape (verbatim from RESEARCH §Pattern 2 — quote into PLAN):**
```swift
import Foundation
import SwiftData
import os

@MainActor
final class GameStats {
    private let modelContext: ModelContext
    private let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "persistence"
    )

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func record(
        gameKind: GameKind,
        difficulty: String,
        outcome: Outcome,
        durationSeconds: Double
    ) throws {
        let record = GameRecord(...)
        modelContext.insert(record)
        if outcome == .win {
            do {
                try evaluateBestTime(...)
            } catch {
                logger.error("BestTime evaluation failed: \(error.localizedDescription)")
            }
        }
        try modelContext.save()
    }

    func resetAll() throws {
        try modelContext.transaction {
            try modelContext.delete(model: GameRecord.self)
            try modelContext.delete(model: BestTime.self)
        }
        try modelContext.save()
    }
}
```

**Why `final class` (not `enum`-namespace):** GameStats carries state (`modelContext`, `logger`) and the VM injection point (D-14) needs an instance reference. The `enum` shape works for `StatsExporter` (no state) but not for `GameStats`.

**Why `@MainActor`:** `ModelContext` is not `Sendable` (RESEARCH Pattern 6 citation). Same constraint as `MinesweeperViewModel` (which is also `@MainActor` per `MinesweeperViewModel.swift:37`).

**Load-bearing rules (RESEARCH Pitfalls 3, 9, 10):**
- **Synchronous explicit `try modelContext.save()`** — never autosave (Pitfall 10).
- **Insert `GameRecord` first**, evaluate `BestTime` second (Discretion lock — flaky predicate doesn't block GameRecord persistence).
- **`resetAll()` uses `transaction { }` with `delete(model:)` batch API** — atomic; partial reset is impossible; iOS 17.3+ canonical (RESEARCH §Don't Hand-Roll table line 8).

**Critical correction vs. RESEARCH §Pattern 2 example (lines 407–412):** RESEARCH shows `final class GameStats` without `@MainActor`. Add the annotation explicitly — it matches the existing `@Observable @MainActor final class MinesweeperViewModel` shape in `MinesweeperViewModel.swift:37` and is required by `ModelContext`'s non-Sendable constraint. RESEARCH Pattern 6 cites this; Pattern 2 omits but doesn't forbid.

---

### NEW PATTERN: `@Observable` UserDefaults wrapper + `EnvironmentKey` (applies to `SettingsStore.swift`)

**Analog (partial):** `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` lines 37 (`@Observable @MainActor final class`) + lines 192 (UserDefaults persistence shape: `userDefaults.set(d.rawValue, forKey: Self.lastDifficultyKey)`); `gamekit/gamekit/App/GameKitApp.swift` line 20 (`@StateObject private var themeManager = ThemeManager()` — only existing env-injection precedent, but uses ObservableObject not @Observable).

**Existing UserDefaults pattern excerpt from `MinesweeperViewModel.swift` lines 188–194:**
```swift
func setDifficulty(_ d: MinesweeperDifficulty) {
    difficulty = d
    userDefaults.set(d.rawValue, forKey: Self.lastDifficultyKey)
    restart()
}
// ...
static let lastDifficultyKey = "mines.lastDifficulty"
```

**Apply to `SettingsStore.swift`** (D-28, D-29, RESEARCH §Pattern 5 inheritance):
```swift
import Foundation
import SwiftUI         // for EnvironmentKey only

@Observable
@MainActor
final class SettingsStore {
    private let userDefaults: UserDefaults
    private static let cloudSyncEnabledKey = "gamekit.cloudSyncEnabled"

    var cloudSyncEnabled: Bool {
        didSet {
            userDefaults.set(cloudSyncEnabled, forKey: Self.cloudSyncEnabledKey)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.cloudSyncEnabled = userDefaults.bool(forKey: Self.cloudSyncEnabledKey)
    }
}

// EnvironmentKey for injection from GameKitApp
private struct SettingsStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = SettingsStore()
}

extension EnvironmentValues {
    var settingsStore: SettingsStore {
        get { self[SettingsStoreKey.self] }
        set { self[SettingsStoreKey.self] = newValue }
    }
}
```

**Why `@Observable` (not `ObservableObject`):** matches the existing `MinesweeperViewModel` pattern and is iOS-17-canonical per RESEARCH §State of the Art table. `@StateObject` was rejected in P3 RESEARCH Pitfall 1 and is incompatible with `@Observable`.

**Why `EnvironmentKey` (not `@EnvironmentObject`):** `@EnvironmentObject` requires `ObservableObject` — incompatible with `@Observable`. The custom `EnvironmentKey` is the iOS-17-canonical injection seam for `@Observable` types per RESEARCH §Pattern 5.

**`UserDefaults.standard` durability** (RESEARCH Assumption A8, LOW risk): `synchronize()` is deprecated since iOS 12; UserDefaults writes are durable on next runloop tick.

---

### NEW PATTERN: `@Query` with `#Predicate` + `Grid` layout (applies to `StatsView.swift` rewrite)

**No analog in repo.** Reference: RESEARCH §Pattern 4 + UI-SPEC §Layout & Sizing + CONTEXT D-24..D-27.

**Type-declaration shape (verbatim from RESEARCH §Pattern 4 — quote into PLAN):**
```swift
@Query(
    filter: #Predicate<GameRecord> { $0.gameKindRaw == "minesweeper" },
    sort: \.playedAt,
    order: .reverse
)
private var minesRecords: [GameRecord]

@Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "minesweeper" })
private var minesBestTimes: [BestTime]
```

**Grid shape (verbatim from RESEARCH §Pattern 4 + UI-SPEC §Layout & Sizing — quote into PLAN):**
```swift
Grid(
    alignment: .leading,
    horizontalSpacing: theme.spacing.m,
    verticalSpacing: theme.spacing.s
) {
    GridRow {
        Text("").gridColumnAlignment(.leading)
        Text(String(localized: "Games")).gridColumnAlignment(.trailing)
        Text(String(localized: "Wins")).gridColumnAlignment(.trailing)
        Text(String(localized: "Win %")).gridColumnAlignment(.trailing)
        Text(String(localized: "Best")).gridColumnAlignment(.trailing)
    }
    .font(theme.typography.caption.weight(.semibold))
    .foregroundStyle(theme.colors.textSecondary)

    Rectangle()
        .fill(theme.colors.border)
        .frame(height: 1)
        .gridCellColumns(5)

    ForEach(MinesweeperDifficulty.allCases, id: \.self) { diff in
        let cohort = minesRecords.filter { $0.difficultyRaw == diff.rawValue }
        let wins = cohort.filter { $0.outcomeRaw == Outcome.win.rawValue }.count
        let games = cohort.count
        // ... derived per-difficulty values ...
        GridRow {
            Text(displayName(diff))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            Text("\(games)")
                .font(theme.typography.monoNumber)
                .monospacedDigit()                                  // P3-locked pattern (UI-SPEC)
                .foregroundStyle(theme.colors.textPrimary)
                .gridColumnAlignment(.trailing)
            // ... wins / win% / best columns ...
        }
    }
}
```

**Critical (`monoNumber + .monospacedDigit()` — P3-locked pattern):** UI-SPEC §Typography "Stat numerals" row makes this load-bearing. Inherited from `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` per `03-PATTERNS.md` "NEW PATTERN: `TimelineView(.periodic)` timer chip" — `monoNumber` ALONE is not enough; the `.monospacedDigit()` modifier is the load-bearing rule so digits don't jitter when stats update.

**`#Predicate` constraint** (RESEARCH §Pattern 4 footnote): direct keypath comparison to a literal string (`$0.gameKindRaw == "minesweeper"`) works cleanly. For `evaluateBestTime` in `GameStats`, capture-let pattern is required:
```swift
let kindRaw = gameKind.rawValue
let descriptor = FetchDescriptor<BestTime>(
    predicate: #Predicate { $0.gameKindRaw == kindRaw && $0.difficultyRaw == difficulty }
)
```

**Empty state branch** (UI-SPEC §Copywriting + D-26 verbatim):
```swift
if minesRecords.isEmpty {
    Text(String(localized: "No games played yet."))
        .font(theme.typography.body)
        .foregroundStyle(theme.colors.textTertiary)
        .frame(maxWidth: .infinity)
} else {
    statsGrid
}
```

---

### NEW PATTERN: `fileExporter` + `fileImporter` with security-scoped URL (applies to `SettingsView.swift` edit)

**No analog in repo.** Reference: RESEARCH §Pattern 3 + RESEARCH §Code Examples 6 + RESEARCH Pitfall 5 + UI-SPEC §Interaction Contracts.

**Export wiring (verbatim from RESEARCH §Code Examples 6 — quote into PLAN):**
```swift
@Environment(\.modelContext) private var modelContext
@State private var isExporterPresented = false
@State private var exportDocument: StatsExportDocument?

// SettingsActionRow tap action:
{
    do {
        let data = try StatsExporter.export(modelContext: modelContext)
        exportDocument = StatsExportDocument(data: data)
        isExporterPresented = true
    } catch {
        Logger(subsystem: "com.lauterstar.gamekit", category: "persistence")
            .error("Export pre-picker failed: \(error.localizedDescription)")
    }
}

// Modifier on the surrounding view:
.fileExporter(
    isPresented: $isExporterPresented,
    document: exportDocument,
    contentType: .json,
    defaultFilename: defaultExportFilename()
) { result in
    if case .failure(let error) = result {
        Logger(...).error("Export failed: \(error.localizedDescription)")
    }
}

private func defaultExportFilename() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]    // YYYY-MM-DD locale-independent (RESEARCH A7)
    return "gamekit-stats-\(formatter.string(from: .now)).json"
}
```

**Import wiring with security-scoped URL (verbatim from RESEARCH Pitfall 5 — quote into PLAN; LOAD-BEARING):**
```swift
.fileImporter(
    isPresented: $isImporterPresented,
    allowedContentTypes: [.json]
) { result in
    switch result {
    case .success(let url):
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try StatsExporter.importing(data, modelContext: modelContext)
        } catch let error as StatsImportError {
            switch error {
            case .schemaVersionMismatch:
                importErrorMessage = "This file was exported from a newer GameKit. Update the app and try again."
            case .decodeFailed, .fileReadFailed:
                importErrorMessage = "The file couldn't be read. Check that it's a GameKit stats export and try again."
            }
            isImportErrorAlertPresented = true
        } catch {
            importErrorMessage = "The file couldn't be read. Check that it's a GameKit stats export and try again."
            isImportErrorAlertPresented = true
        }
    case .failure:
        break    // user cancelled — silent
    }
}
```

**LOAD-BEARING (RESEARCH Pitfall 5):** the `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` bookends are NON-OPTIONAL. Without them, import works in simulator (no security scope enforcement) but fails silently in release on device. The `defer` wraps the `stop` call so it fires even if `Data(contentsOf:)` throws.

**`UTType.json`:** requires `import UniformTypeIdentifiers` per RESEARCH §Standard Stack table.

---

### NEW PATTERN: `StatsExportEnvelope` + `FileDocument` wrapper (applies to `StatsExportEnvelope.swift` + `StatsExportDocument.swift`)

**No analog in repo.** RESEARCH §Pattern 3 + CONTEXT D-17..D-19.

**Envelope shape (verbatim from RESEARCH §Pattern 3 — quote into PLAN):**
```swift
struct StatsExportEnvelope: Codable, Sendable {
    let schemaVersion: Int
    let exportedAt: Date
    let gameRecords: [Record]
    let bestTimes: [Best]

    struct Record: Codable, Sendable {
        let id: UUID
        let gameKindRaw: String
        let difficultyRaw: String
        let outcomeRaw: String
        let durationSeconds: Double
        let playedAt: Date
        let schemaVersion: Int
    }

    struct Best: Codable, Sendable {
        let id: UUID
        let gameKindRaw: String
        let difficultyRaw: String
        let seconds: Double
        let achievedAt: Date
        let schemaVersion: Int
    }
}
```

**Encoder configuration (LOAD-BEARING per RESEARCH Pitfall 7 + Pattern 3 — quote into PLAN):**
```swift
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]   // SC4 byte-for-byte determinism
return try encoder.encode(envelope)
```

**`.sortedKeys` is non-negotiable** for SC4's "byte-for-byte" round-trip (RESEARCH Pitfall 7). Adds 0 runtime cost; protects against silent regression.

**`FileDocument` wrapper shape (verbatim from RESEARCH §Pattern 3 — quote into PLAN):**
```swift
struct StatsExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let blob = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = blob
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
```

**`StatsImportError` shape (RESEARCH §Pattern 3):**
```swift
enum StatsImportError: LocalizedError {
    case schemaVersionMismatch(found: Int, expected: Int)
    case decodeFailed
    case fileReadFailed

    var errorDescription: String? {
        switch self {
        case .schemaVersionMismatch:
            return String(localized: "This file was exported from a newer GameKit. Update the app and try again.")
        case .decodeFailed, .fileReadFailed:
            return String(localized: "The file couldn't be read. Check that it's a GameKit stats export and try again.")
        }
    }
}
```

**Critical:** `errorDescription` localizations land in `Localizable.xcstrings` automatically via `String(localized:)` — verify post-implementation that the keys exist (FOUND-04 auto-extraction). The strings ALSO appear in the SettingsView alert body (UI-SPEC §Copywriting), so the planner has two options: (a) define once in `errorDescription` and re-use the value in the alert, or (b) define separately for alert and re-use through localization key collision. Recommend (a) — single source of truth.

---

### NEW PATTERN: VM injection of `GameStats?` seam (applies to `MinesweeperViewModel.swift` edit)

**Analog (self):** `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` lines 92–107 — established 3-seam tail-of-init injection pattern (`userDefaults`, `clock`, `rng`).

**Existing init excerpt (lines 87–107):**
```swift
/// - Parameters:
///   - difficulty: explicit override; if nil, reads from `userDefaults` (D-11) or falls back to .easy.
///   - userDefaults: injection seam — tests pass an isolated suite; production passes `.standard`.
///   - clock: injection seam — tests pin time, production uses `Date.now`.
///   - rng: injection seam — tests pass `SeededGenerator(seed:)` for determinism, production passes `SystemRandomNumberGenerator()`.
init(
    difficulty: MinesweeperDifficulty? = nil,
    userDefaults: UserDefaults = .standard,
    clock: @escaping () -> Date = { Date.now },
    rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
) {
    self.userDefaults = userDefaults
    self.clock = clock
    self.rng = rng
    // ...
}
```

**P4 edit shape (extend, do NOT replace — preserve injection seams):**
```swift
init(
    difficulty: MinesweeperDifficulty? = nil,
    userDefaults: UserDefaults = .standard,
    clock: @escaping () -> Date = { Date.now },
    rng: any RandomNumberGenerator = SystemRandomNumberGenerator(),
    gameStats: GameStats? = nil          // NEW seam (D-14, RESEARCH §Code Examples 4)
) {
    self.userDefaults = userDefaults
    self.clock = clock
    self.rng = rng
    self.gameStats = gameStats
    // ...
}

// NEW ivar (group with other seams):
private let gameStats: GameStats?

// NEW method, called from inside .playing → .won and .playing → .lost transitions
// (D-15 + RESEARCH §Code Examples 4):
private func recordTerminalState(outcome: GameOutcome) {
    try? gameStats?.record(
        gameKind: .minesweeper,
        difficulty: difficulty.rawValue,        // P2 D-02 canonical key (D-05)
        outcome: outcome == .win ? .win : .loss,
        durationSeconds: frozenElapsed
    )
}
```

**Call sites (existing `reveal(at:)` lines 135–144 — INSERT one line each in the two terminal-state branches):**
```swift
if WinDetector.isLost(board) {
    if let mineIdx = board.allIndices().first(where: { board.cell(at: $0).state == .mineHit }) {
        gameState = .lost(mineIdx: mineIdx)
        lossContext = computeLossContext()
    }
    freezeTimer()                            // D-08 freeze BEFORE the record call so frozenElapsed is correct
    recordTerminalState(outcome: .loss)      // NEW (D-15)
} else if WinDetector.isWon(board) {
    gameState = .won
    freezeTimer()
    recordTerminalState(outcome: .win)       // NEW (D-15)
}
```

**LOAD-BEARING ORDERING (RESEARCH Pitfall 3, Pitfall 4):**
1. `gameState = .won/.lost(...)` first.
2. `freezeTimer()` second — must be **before** `recordTerminalState()` so `frozenElapsed` holds the correct elapsed value.
3. `recordTerminalState(outcome:)` last — wraps `try? gameStats?.record(...)`; failure logged via `os_log` inside `GameStats.record`; UI continues to render the terminal state.

**LOAD-BEARING (RESEARCH §Anti-Patterns + ARCHITECTURE Anti-Pattern 1, INHERITED FROM P3):** the VM does NOT `import SwiftData`. Verify after the edit:
```bash
grep -E '^import (SwiftData|SwiftUI|Combine|UIKit|GameplayKit|Observation)' \
  gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift
# Expected: empty (only `import Foundation` should appear)
```
The `GameStats` type is forward-resolved at compile time without importing SwiftData — `GameStats.swift` lives in the same module (`gamekit`) as `MinesweeperViewModel.swift`. RESEARCH §Code Examples 4 line 1131 confirms.

---

### NEW PATTERN: `MinesweeperGameView` env-resolved `GameStats` injection (applies to `MinesweeperGameView.swift` edit)

**Analog (self):** `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` lines 39–41 (existing `init()` rebinding `_viewModel`).

**Existing excerpt (lines 31–41):**
```swift
struct MinesweeperGameView: View {
    @State private var viewModel: MinesweeperViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    init() {
        _viewModel = State(initialValue: MinesweeperViewModel())
    }
```

**P4 edit shape (RESEARCH Open Question 3 + Pitfall 8):**

**Recommended approach (planner discretion, two options):**

**Option A — `.task` lazy injection (matches Pitfall 8 hoisting recommendation):**
```swift
struct MinesweeperGameView: View {
    @State private var viewModel: MinesweeperViewModel
    @Environment(\.modelContext) private var modelContext         // NEW
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var didInjectStats = false                     // NEW (one-shot guard)

    init() {
        _viewModel = State(initialValue: MinesweeperViewModel())
    }

    var body: some View {
        ZStack { ... }
            .task {                                               // NEW
                guard !didInjectStats else { return }
                didInjectStats = true
                let stats = GameStats(modelContext: modelContext)
                viewModel.attachGameStats(stats)                  // VM exposes a one-shot setter
            }
            // ... existing modifiers ...
    }
}
```

**Option B — re-init VM in `init()` accepting `modelContext` from a custom container-aware wrapper (cleanest):** requires creating a sibling factory or refactoring `HomeView.swift:43` `MinesweeperGameView()` call site. NOT recommended — touches an out-of-scope file.

**Option C — `init()` reads `@Environment(\.modelContext)` directly:** does NOT work — `@Environment` values are not available during `View.init()`; only inside `body`/`.task`/`.onAppear`.

**Recommended: Option A.** Adds a one-line setter to `MinesweeperViewModel` (instead of pure init injection per D-14 — relaxed per RESEARCH Open Question 1). The setter is internal:
```swift
// in MinesweeperViewModel:
private(set) var gameStats: GameStats?      // change from `private let` to `private(set) var`
func attachGameStats(_ stats: GameStats) {
    self.gameStats = stats                   // one-shot — second call is benign no-op? planner picks
}
```

**Critical (RESEARCH Pitfall 8):** `let gameStats = GameStats(modelContext: modelContext)` MUST NOT live inside `body` — it would construct a new `GameStats` (and a new `os.Logger`) on every render. The `.task` modifier fires once per view lifecycle, which is correct.

**Critical (CLAUDE.md §8.6):** the existing GameView already uses `.foregroundStyle` not `.foregroundColor` — preserve.

---

## Shared Patterns

### File-size cap (CLAUDE.md §8.1, §8.5)

**Source:** CLAUDE.md ≤500-line hard cap; ≤400-line soft cap for views. Inherited from P2 + P3.

**Apply to:** all 12 NEW production + test files. UI-SPEC §Component Inventory + RESEARCH §Recommended Project Structure lock per-file expected sizes:

| File | Soft cap | Hard cap | Trigger to split |
|------|----------|----------|------------------|
| `Core/GameRecord.swift` | <80 | <200 | n/a — model only |
| `Core/BestTime.swift` | <60 | <200 | n/a |
| `Core/GameKind.swift` | <30 | <100 | n/a |
| `Core/Outcome.swift` | <30 | <100 | n/a |
| `Core/GameStats.swift` | <120 | <200 | If `evaluateBestTime` grows, split into `GameStats+BestTime.swift` extension |
| `Core/StatsExporter.swift` | <140 | <250 | If envelope conversion grows, split `StatsExporter+Envelope.swift` extension |
| `Core/StatsExportEnvelope.swift` | <60 | <100 | n/a |
| `Core/StatsExportDocument.swift` | <30 | <80 | Or inline at bottom of `StatsExporter.swift` (planner picks) |
| `Core/StatsImportError.swift` | <30 | <80 | Or inline at bottom of `StatsExporter.swift` (planner picks) |
| `Core/SettingsStore.swift` | <60 | <150 | When P5 adds `hapticsEnabled`/`sfxEnabled`/`hasSeenIntro`, split per-flag extensions if it crosses 150 |
| `Screens/StatsView.swift` (rewrite) | <300 | <400 | If derived stats logic crosses 100, split `StatsView+Derive.swift` |
| `Screens/SettingsView.swift` (edit) | <250 | <400 | If file-private rows + alerts cross 250, split `SettingsView+Data.swift` |
| `App/GameKitApp.swift` (edit) | <80 | <150 | n/a — currently 38 lines, P4 adds ~30 |
| `gamekitTests/Core/GameStatsTests.swift` | <250 | <500 | n/a |
| `gamekitTests/Core/StatsExporterTests.swift` | <200 | <500 | n/a |
| `gamekitTests/Core/ModelContainerSmokeTests.swift` | <80 | <150 | n/a |
| `gamekitTests/Helpers/InMemoryStatsContainer.swift` | <30 | <80 | n/a — ~25 lines |
| `Games/Minesweeper/MinesweeperViewModel.swift` (edit) | <500 | <500 | Already at 279 lines; P4 adds ~25; well within budget |
| `Games/Minesweeper/MinesweeperGameView.swift` (edit) | <300 | <400 | Already at 146 lines; P4 adds ~10; well within budget |

---

### Token discipline (CLAUDE.md §1, §8.4; FOUND-07 hook)

**Source:** `/Users/gabrielnielsen/Desktop/GameKit/.githooks/pre-commit` lines 12–34. Inherited from P3.

**Hook scope:** `^gamekit/gamekit/(Games|Screens)/.*\.swift$` (line 13). The hook **does NOT scope `Core/`** — meaning new SwiftData/service files in `Core/` are NOT subject to the regex blocks. However, P4 SHOULD still apply token discipline to any UI tokens consumed in `Core/` (none expected — `Core/` is persistence, not UI).

**Hook regexes (excerpt from `.githooks/pre-commit` lines 18–28):**
```bash
# Color literals (Color(red:..) / Color(hex:..) / Color.gray etc.)
grep -E '^\+' | grep -E 'Color\(\s*(red:|hex:|white:)|Color\.(red|blue|green|gray|orange|yellow|pink|purple|black|white)'
# cornerRadius: <int>
grep -E '^\+' | grep -E 'cornerRadius:\s*[0-9]+'
# padding(<int>)
grep -E '^\+' | grep -E '\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)'
```

**Apply to:** `Screens/StatsView.swift` + `Screens/SettingsView.swift` (in-scope). Edits to `Games/Minesweeper/MinesweeperViewModel.swift` and `Games/Minesweeper/MinesweeperGameView.swift` are also in-scope but the P4 diffs touch no tokens (VM is Foundation-only; GameView edits add `@Environment(\.modelContext)` and `.task` only).

**Available tokens** (verified from DesignKit — never invent new ones per CLAUDE.md §8.4):
- **Spacing:** `xs (4) | s (8) | m (12) | l (16) | xl (24) | xxl (32)` — `SpacingTokens.swift`.
- **Radii:** `card (16) | button (14) | chip (12) | sheet (22)` — `RadiusTokens.swift`.
- **Typography:** `titleLarge | title | headline | body | caption | monoNumber` — `TypographyTokens.swift`.
- **Colors:** semantic tokens including `success`, `danger`, `surface`, `surfaceElevated`, `border`, `textPrimary`, `textSecondary`, `textTertiary`, `accentPrimary` — `Tokens.swift`.

**Frame exception** (`.frame(minHeight: 44)` for SettingsActionRow): allowed per UI-SPEC §Spacing carve-out + `03-PATTERNS.md` line 552 (the regex `\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)` does NOT match `.frame(minHeight:)`). HIG-derived component-intrinsic dimension.

**`Rectangle().frame(height: 1)` exception** (Grid divider rule per UI-SPEC §Layout & Sizing): same regex carve-out — `.frame(height: 1)` is not flagged.

---

### Foundation-only ViewModel (ARCHITECTURE Anti-Pattern 1, inherited from P3)

**Source:** ARCHITECTURE.md §Anti-Pattern 1; RESEARCH §Anti-Patterns; `MinesweeperViewModel.swift` lines 11–18 (existing comment).

**Apply to:** `Games/Minesweeper/MinesweeperViewModel.swift` only (one file, but load-bearing).

**Rule:** ViewModel imports `Foundation` only. The P4 edit MUST NOT add `import SwiftData`. The `GameStats` type is forward-resolved at compile time without importing SwiftData (it's the same module). RESEARCH §Code Examples 4 line 1131 explicitly confirms.

**Enforcement (planner suggestion, mirrors `02-PATTERNS.md` "Foundation-only purity"):**
```bash
grep -E '^import (SwiftData|SwiftUI|Combine|UIKit|GameplayKit|Observation)' \
  gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift
# Expected: empty (only `import Foundation` should appear)
```
Add to CI / pre-commit if not already present.

---

### Synchronous explicit save (RESEARCH Pitfall 3 + Pitfall 10)

**Source:** RESEARCH Pitfalls 3 + 10; CONTEXT D-11 + SC1 literal mandate.

**Apply to:** `Core/GameStats.swift` + `Core/StatsExporter.swift`.

**Rule:** every public method that writes to SwiftData MUST end with `try modelContext.save()` BEFORE returning. No `autosave` reliance — the WAL fsync must complete before the user can force-quit. Wrap multi-step writes in `try modelContext.transaction { ... }` for atomicity (D-13 `resetAll()`, D-20 `importing(...)`).

**Concrete checkpoints:**
- `GameStats.record(...)`: ends with `try modelContext.save()` (RESEARCH Pattern 2 line 445).
- `GameStats.resetAll()`: opens `transaction { delete(model:) × 2 }`, then `try modelContext.save()` (RESEARCH Pattern 2 line 479).
- `StatsExporter.importing(...)`: opens `transaction { delete + insert + decode }`, then `try modelContext.save()` (RESEARCH Pattern 3 line 626).

**Order check (RESEARCH Pitfall 6):** decode-then-validate-then-transaction. Validation MUST happen before opening the transaction so a schema-mismatch throw doesn't trigger any delete.

---

### `LocalizedStringKey` for accessibility + ISO8601 UTC for serialization

**Source:** RESEARCH §Standard Stack; UI-SPEC §A11y labels (StatsView); CONTEXT Specifics + Discretion.

**Apply to:** `Screens/StatsView.swift` (a11y labels per UI-SPEC) + `Core/StatsExporter.swift` (envelope `exportedAt`).

**Rules:**
- A11y labels use `LocalizedStringKey` interpolation (auto-extract via `SWIFT_EMIT_LOC_STRINGS=YES`):
  ```swift
  .accessibilityLabel("\(displayName(diff)): \(games) games, \(wins) wins, \(winPctSpoken) percent, best time \(bestTimeSpoken)")
  ```
- `exportedAt` and `playedAt` and `achievedAt` ISO8601 in UTC (`Z` suffix) per Discretion + RESEARCH §Standard Stack table:
  ```swift
  encoder.dateEncodingStrategy = .iso8601    // produces "2026-04-25T19:30:00Z"
  ```
- Filename uses `[.withFullDate]` ISO formatter for `YYYY-MM-DD` locale-independence (RESEARCH Assumption A7, LOW risk).

---

### Localization completeness gate (FOUND-05 + RESEARCH Pitfall 8 inheritance)

**Source:** `03-PATTERNS.md` "Localization completeness gate"; UI-SPEC §Copywriting.

**Apply to:** `Resources/Localizable.xcstrings` after every commit that touches a P4-edited view file.

**Rule:** Open `Localizable.xcstrings` in Xcode catalog editor → filter "Stale" → delete. xcstrings auto-extracts NEW keys but does NOT auto-delete renamed/removed keys.

**Existing seed:** ~55 keys (25 P1 + ~30 P3, per `03-PATTERNS.md`). P4 adds ~15 keys (StatsView column headers + DATA section labels + 2 alerts + empty state). Final count ~70 keys, EN-only.

---

### Test depth: Swift Testing × in-memory `ModelContainer` × `@MainActor` (D-30, D-31)

**Source:** RESEARCH Pattern 6 + CONTEXT D-30 + D-31.

**Apply to:** all 3 NEW Core/ test files.

**Rules:**
- **Per-test fresh container** (RESEARCH Open Question 5): `let container = try InMemoryStatsContainer.make()` inside each `@Test func`. Cheap (~1ms init); avoids parallel-execution contention.
- **`@MainActor`** annotation on the `@Suite struct` per RESEARCH Pattern 6 — `ModelContext` is not `Sendable`.
- **Direct `try`** (no `XCTAssertNoThrow` wrappers) — Swift Testing surfaces throws automatically.
- **Smoke test exercises BOTH configurations** per D-10:
  ```swift
  @Test("constructs with .none cloudKitDatabase")
  func constructLocalOnly() throws {
      _ = try InMemoryStatsContainer.make(cloudKit: .none)
  }

  @Test("constructs with .private(\"iCloud.com.lauterstar.gamekit\") cloudKitDatabase")
  func constructCloudKitCompat() throws {
      _ = try InMemoryStatsContainer.make(
          cloudKit: .private("iCloud.com.lauterstar.gamekit")
      )
  }
  ```
- **Round-trip byte equality** for `StatsExporterTests` — encode → reset → decode + import → encode-again — assert `Data` equality (SC4 + RESEARCH Pitfall 7).
- **Schema-mismatch error path** for `StatsExporterTests` — encode envelope manually with `schemaVersion: 999`, attempt import, assert `StatsImportError.schemaVersionMismatch` is thrown AND existing data is intact (RESEARCH Pitfall 6).

---

## No Analog Found

10 NEW PATTERNS — P4 is the first SwiftData phase. Closest reference for each is a planning doc or RESEARCH section, not a sibling source file:

| File | Reference |
|------|-----------|
| `Core/GameRecord.swift` | RESEARCH §Pattern 1 + §Code Examples 2; CONTEXT D-01..D-06 |
| `Core/BestTime.swift` | RESEARCH §Pattern 1; CONTEXT D-03 |
| `Core/GameStats.swift` | RESEARCH §Pattern 2 + §Code Examples 3; CONTEXT D-11..D-15 |
| `Core/StatsExporter.swift` | RESEARCH §Pattern 3 + §Code Examples 4+5; CONTEXT D-16..D-21 |
| `Core/StatsExportEnvelope.swift` | RESEARCH §Pattern 3 (top of example block); CONTEXT D-17..D-18 |
| `Core/StatsExportDocument.swift` | RESEARCH §Pattern 3 (bottom of example block); RESEARCH Alternatives Considered "FileDocument wrapper" |
| `Core/StatsImportError.swift` | RESEARCH §Pattern 3 (middle of example block); CONTEXT D-21 |
| `Core/SettingsStore.swift` | RESEARCH §Pattern 5 + §Code Examples 1; CONTEXT D-28..D-29 |
| `App/GameKitApp.swift` (edit) | RESEARCH §Pattern 5 + §Code Examples 1; CONTEXT D-07..D-09, D-29 |
| `gamekitTests/Helpers/InMemoryStatsContainer.swift` | RESEARCH §Pattern 6 + §Code Examples 5; CONTEXT D-31 |

**Planner instruction:** When writing PLAN.md actions, treat these references as the canonical specifications — quote the RESEARCH §Pattern 1 `GameRecord` shape (lines 360–388) verbatim into the schema plan; quote the RESEARCH §Pattern 2 `record(...)` flow (lines 414–446) verbatim into the GameStats plan; quote the RESEARCH §Pattern 3 envelope + decode-validate-transaction order (lines 506–626) verbatim into the StatsExporter plan; quote the RESEARCH §Pitfall 5 security-scoped URL bookends (lines 980–998) verbatim into the SettingsView import-flow plan. There is no in-repo file to copy from for these surfaces.

---

## Metadata

**Analog search scope:** `gamekit/gamekit/` (App, Screens, Resources, Games/Minesweeper, Games/Minesweeper/Engine); `gamekit/gamekitTests/` (Engine, Games/Minesweeper, Helpers); `/Users/gabrielnielsen/Desktop/DesignKit/Sources/DesignKit/Components/`; `gamekit/.githooks/`; planning docs (`02-PATTERNS.md`, `03-PATTERNS.md`).

**Files scanned:** 18 (`.swift` + `.xcstrings` + githook + planning docs).

**Files producing usable patterns:** 11 — file-header convention from `GameKitApp.swift` / `MinesweeperBoard.swift` / `MinesweeperViewModel.swift` / `RevealEngine.swift`; themed-shell view shape from `StatsView.swift` (P1) + `HomeView.swift`; DKCard wrapping from `HomeView.cardRow(_:)`; ThemeManager env wiring from `GameKitApp.swift` + `RootTabView.swift`; settings row idiom from `SettingsComponents.swift.settingsNavRow`; alert binding from `MinesweeperGameView.swift` lines 90–102; pre-commit token discipline from `.githooks/pre-commit`; Swift Testing scaffold from `BoardGeneratorTests.swift` (`nonisolated`) + `MinesweeperViewModelTests.swift` (`@MainActor`); enum-namespace static-method shape from `RevealEngine.swift` + `WinDetector.swift`; UserDefaults persistence shape from `MinesweeperViewModel.swift:188-194`; test-only helper placement from `SeededGenerator.swift`.

**Files producing no usable pattern:** 7 — `MinesweeperBoard.swift` / `MinesweeperCell.swift` / `MinesweeperIndex.swift` / `MinesweeperDifficulty.swift` / `MinesweeperGameState.swift` are pure-Foundation engine models (correct per P2 architecture — but they're `struct`/`enum` value types; P4's `@Model` schema is a different shape); `gamekitUITests/*.swift` (XCUITest, wrong layer); `ComingSoonOverlay.swift` (chip styling — relevant to P3 not P4).

**Critical correction noted (P4-specific):**
1. RESEARCH §Pattern 5 example `init` shape needs adapting to the existing `@StateObject themeManager` injection seam in `GameKitApp.swift`.
2. RESEARCH §Code Examples 4 VM init injection needs ordering-aware editing (5th tail-of-init seam, NOT prepended).
3. RESEARCH §Pattern 2 `final class GameStats` should be annotated `@MainActor` (matches `ModelContext` non-Sendable constraint and existing `MinesweeperViewModel` shape).
4. P2's test scaffold pattern (`nonisolated struct`) does NOT carry to P4 — Core tests must be `@MainActor struct` because `mainContext` is main-actor-bound.

**Pattern extraction date:** 2026-04-25.
