# Pitfalls Research

**Domain:** iOS Minesweeper-first suite, Swift 6 / SwiftUI / SwiftData (+ optional CloudKit) / Sign in with Apple, DesignKit consumer
**Researched:** 2026-04-24
**Confidence:** HIGH for SwiftData/CloudKit constraints, App Store 4.8, Sign in with Apple revocation flow, gesture/grid trade-offs (verified against Apple docs + multiple credible sources). MEDIUM for animation budget specifics, theme legibility breakage thresholds, and project-hygiene rules (drawn from CLAUDE.md session-derived rules + general SwiftUI lore — should be treated as the team's own remembered pain).

> Phase legend used throughout
> **P1** Foundation (DesignKit wiring, app shell, ThemeManager, bundle ID, capabilities, String catalog scaffolding)
> **P2** Mines core (engine: board gen, reveal, flood-fill, win/loss; minimum playable UI)
> **P3** Polish (animation pass, haptics, SFX, full theme legibility audit, accessibility)
> **P4** Persistence / cloud (SwiftData stats, Export/Import, Sign in with Apple + CloudKit, sync UX)
> **P5** Release (TestFlight, App Review, privacy nutrition label, screenshots, submission)

---

## Critical Pitfalls

### Pitfall 1: First-tap loss on small boards / corner taps because the safe-zone exclusion is "first cell only" instead of "first cell + 8 neighbors"

**What goes wrong:**
A naive implementation places mines anywhere except the tapped cell, then runs the reveal. On Easy (9x9, 10 mines) a corner tap with surrounding mines will *not* lose, but it will surface a "1" or "2" with no flood-fill, defeating the canonical "first tap reveals an empty area" expectation. Worse, if the dev later "fixes" by re-rolling boards until tap-cell is a 0, on dense boards (Hard 16x30, 99 mines) the loop can become extremely long or never terminate. The classic Windows behavior is: tapped cell *and its 8 neighbors* are excluded from mine placement so the first reveal cascades.

**Why it happens:**
- Spec is read as "first tap is safe" rather than "first tap is empty" (these are different).
- Corner case: corner cells only have 3 neighbors, edge cells have 5. If exclusion logic uses "8 neighbors" without bounds-checking, off-board indices throw or get silently skipped, leaving a corner with fewer-than-expected exclusions.
- On Hard, 99 mines / 480 cells means ~21% mine density. Trying to brute-force re-generate until tap is a "0" can take hundreds of attempts and feel like a hang.

**How to avoid:**
- Single rule: `mines = sample(without_replacement, from: allCells - {tapped} - tapped.neighbors8, count: difficulty.mineCount)` — bounds-clamp neighbors so corner/edge taps exclude only valid in-board neighbors (3 or 5 neighbors clamped, not 8 plus garbage).
- Engine is pure (per `CLAUDE.md` §1 / `AGENTS.md` §4) — write three deterministic unit tests in P2:
  1. Easy corner tap (0,0): assert (0,0), (0,1), (1,0), (1,1) all mine-free.
  2. Hard center tap (8,15): assert all 9 cells mine-free.
  3. Hard with 99 mines + corner tap: assert exactly 99 mines placed and none in the safe set.
- Do not loop "until tap is a zero" — exclude the neighborhood from placement directly, then place mines once.

**Warning signs:**
- A first tap that reveals just a single number on Easy.
- Any test that uses `while board.cellAt(tap).adjacentCount != 0 { regenerate() }`.
- Crashes / array-out-of-bounds on tapping (0,0) or (rows-1, cols-1).

**Phase to address:** **P2** (Mines core). Treat any first-tap loss as P0 — already codified in `CLAUDE.md` §8.11.

---

### Pitfall 2: SwiftData model designed for local-first ships unique attributes / required relationships, then breaks the day CloudKit is enabled

**What goes wrong:**
The CloudKit-mirrored SwiftData store has *strict* constraints that the local-only store doesn't. If P1/P2 ships a `GameStats` model with `@Attribute(.unique) var id: UUID`, a non-optional `var difficulty: Difficulty`, or a required to-many relationship `var bestTimes: [BestTime]`, then in P4 when `cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit")` is added, `ModelContainer` initialization fails silently or throws, and the app refuses to launch.

**Why it happens:**
CloudKit's distributed model requires:
- **No `@Attribute(.unique)`** — uniqueness can't be enforced across devices syncing through eventual consistency.
- **All non-relationship properties optional or default-valued** — late-arriving records may not have every field.
- **All relationships optional** (even to-many; default `[]` is fine but the property itself must allow nil semantically).
- **No `.deleteRule` cascade on required relationships** — requires the inverse to be optional.

Devs designing offline-first models reach for `.unique` and non-optional fields out of habit; the constraints aren't enforced at compile time and only surface when you flip the CloudKit switch.

**How to avoid:**
- In **P1**, write the `Persistable` model rules into the project before any model is created. Even though P2 ships local-only, design models *as if* CloudKit is on:
  - No `@Attribute(.unique)`. Use UUID primary keys without the modifier and de-dupe in code.
  - Every property either optional (`var bestTime: TimeInterval?`) or has a default (`var gamesPlayed: Int = 0`).
  - All relationships optional.
- Add a single test in P2: `XCTAssertNoThrow(try ModelContainer(for: GameStats.self, configurations: .init(cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit"))))` even before CloudKit ships — it'll catch model violations the moment they're introduced.

**Warning signs:**
- Model uses `@Attribute(.unique)`.
- Model has `var difficulty: Difficulty` (non-optional, no default).
- Relationships marked non-optional.
- "Works locally, crashes when iCloud is on" reports.

**Phase to address:** **P1** (model design discipline) **/ P4** (verify on CloudKit enable).

---

### Pitfall 3: Silent CloudKit sync failures with no UI affordance — user thinks data is synced, isn't

**What goes wrong:**
CloudKit fails for a dozen reasons that don't bubble up to the user: schema not deployed to production, account temporarily unavailable, quota exceeded, network throttled, container ID typo. By default `NSPersistentCloudKitContainer` logs to console and keeps running with the local-only store. User wins a Hard game on their iPhone, opens the iPad, sees nothing, concludes "this app is broken" and writes a one-star review.

**Why it happens:**
- No status surface in UI for "is sync currently working?"
- Schema must be manually promoted from Development to Production in CloudKit Dashboard before TestFlight; dev environment != Production environment.
- Container ID drift (container renamed mid-development) means existing TestFlight users keep pointing at an old container with no records.
- The system gives no error toast; failures are silent by design.

**How to avoid:**
- Subscribe to `NSPersistentCloudKitContainer.eventChangedNotification` (or SwiftData equivalent) and surface a one-line status in Settings: "Synced just now" / "Syncing…" / "Not signed in" / "iCloud unavailable — last synced [date]". This is a 30-line view, not a feature.
- Pin the CloudKit container ID in `PROJECT.md` and `Info.plist` early (P1). Never rename it once a TestFlight build is out.
- Promote schema to Production in CloudKit Dashboard *before* the first TestFlight build that has CloudKit enabled, and re-promote after every additive schema change. Document this step in a P5 release checklist.
- After enabling CloudKit, run `try await container.initializeCloudKitSchema()` once in dev to materialize record types.

**Warning signs:**
- Settings has no sync-status row.
- Two devices show different stats and no UI explains why.
- `git log` shows the CloudKit container identifier changing.
- TestFlight users report "iCloud doesn't work" and you can't reproduce locally (you're on dev environment, they're on production).

**Phase to address:** **P4** (sync UI affordance) **/ P5** (Production schema deploy + container ID lockdown).

---

### Pitfall 4: Anonymous-to-signed-in promotion loses local stats

**What goes wrong:**
PERSIST-06 says "anonymous local profile created on first launch; signing in promotes local data to cloud (no data loss on sign-in)." The natural-but-wrong implementation is to swap the `ModelContainer` from local-only to CloudKit-backed when the user signs in. SwiftData treats this as a different store; the local records are orphaned in the old SQLite file and the cloud store starts empty. User had a 0:42 Easy best time, signs in to back it up, and the stats screen now reads "—".

**Why it happens:**
- `ModelContainer(for: GameStats.self, configurations: .init(cloudKitDatabase: .private(...)))` creates a *new* store at a *different* path than `ModelContainer(for: GameStats.self)`.
- Devs assume "same model, same data," but SwiftData stores are URL-keyed.
- Test environment usually has empty stats, so the bug never surfaces in dev.

**How to avoid:**
- Use the **same** ModelContainer configuration from day 1, with CloudKit declared but only *active* when signed in. Apple's pattern: configure with `.private(containerID)` always; CloudKit mirroring is a no-op when there's no iCloud account, and turns on when the user signs in. Records already in the store get pushed up.
- If you must swap stores, write an explicit migration: fetch all records from the old container, insert into the new one, verify counts match, then delete the old store file. Cover with a test that seeds local data, signs in, asserts cloud store has same records.
- Add a "Stats count before sign-in / after sign-in" assertion in a manual QA script for P4.

**Warning signs:**
- Two `ModelContainer` constructions in the codebase at different code paths.
- Sign-in flow includes `try? FileManager.default.removeItem(at: oldStoreURL)` — instant smell.
- Tests pass with empty-stats fixtures; manual test with 50 games crushes them.

**Phase to address:** **P4** (sign-in promotion flow). Cover with an explicit "seed → sign in → verify count" test in the same commit.

---

### Pitfall 5: Sign in with Apple credential revocation not handled — re-auth breaks silently after user revokes via Settings or reinstalls app

**What goes wrong:**
User signs in, plays for weeks, eventually goes to **Settings → Apple ID → Password & Security → Sign in with Apple → [App] → Stop using Apple ID** (or reinstalls the app, wiping Keychain). On next launch, the stored Apple ID token is invalid. App acts like the user is still signed in, makes CloudKit calls that fail silently (see Pitfall 3), or worse, sees "no user" and strands their stats. Apple's guidance also requires you to react to `ASAuthorizationAppleIDProvider.credentialRevokedNotification` and treat the user as signed out — failing this can also trigger App Review issues and breaks the cross-device flow.

**Why it happens:**
- Devs implement the happy-path sign-in (Authorization Services button → store user ID in Keychain → done) and skip the lifecycle.
- App reinstall wipes Keychain (unless explicitly using a Keychain access group with proper config) — the user ID is gone but the app doesn't realize until a CloudKit op fails.
- Credential revocation is a separate notification that's easy to forget.
- Apple's January 2026 update tightens account-notifications expectations for Sign in with Apple — silent revocation handling becomes more visible.

**How to avoid:**
- On `applicationDidBecomeActive` (or scene equivalent), call `ASAuthorizationAppleIDProvider().getCredentialState(forUserID: storedUserID)` and handle `.revoked` and `.notFound` by clearing the local sign-in state and showing the optional sign-in card again (without nagging — per `PROJECT.md` PERSIST-05).
- Subscribe to `ASAuthorizationAppleIDProvider.credentialRevokedNotification` for the in-session case.
- Store the Apple user ID in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — survives backgrounds, doesn't sync across devices (which is correct; each device authenticates independently).
- Treat sign-out and revocation identically: local data persists (anonymous mode is feature-parity); cloud sync stops.
- Test matrix in P4: (a) sign in, force-quit, relaunch — still signed in. (b) sign in, revoke via system Settings, relaunch — gracefully signed out, stats intact. (c) sign in, delete app, reinstall — re-prompted to sign in, no crash.

**Warning signs:**
- Sign-in code path stores user ID once and never re-validates.
- No `credentialRevokedNotification` observer in the codebase.
- App "remembers" sign-in after reinstall (Keychain misconfigured to persist).

**Phase to address:** **P4** (sign-in lifecycle).

---

### Pitfall 6: The Minesweeper grid re-renders all 480 cells on every state change, making Hard mode feel sluggish

**What goes wrong:**
Hard is 16x30 = 480 cells. A naive `@Published var board: Board` with `LazyVGrid { ForEach(board.cells) { CellView(cell: $0) } }` causes SwiftUI to invalidate every cell on any state change (revealing one cell, ticking the timer once per second, even a theme switch). On older devices the reveal cascade animation drops frames; the timer ticking causes a perceptible re-layout once a second; long-press to flag feels delayed.

**Why it happens:**
- `LazyVGrid` was designed for scrollable content; for a non-scrolling fixed board it still defers some work but fights the layout system.
- Each `CellView` taking the whole `Board` (or even a closure that captures `self`) triggers re-evaluation when the parent changes.
- Timer state lives in the same view-model as board state; tick → publishes → entire view re-renders.
- Equatable conformance missing on `Cell` means SwiftUI can't short-circuit re-renders.

**How to avoid:**
- For Easy (9x9 = 81 cells) and Medium (16x16 = 256 cells), `Grid` (eager) is fine and gives better layout for fixed boards. For Hard (16x30 = 480 cells), measure both — `Grid` is often still faster than `LazyVGrid` here because there's no scrolling and `LazyVGrid`'s laziness has overhead on a non-scrolling layout.
- Make `Cell` `Equatable` (or `Hashable`) so SwiftUI's diffing can skip unchanged cells. `CellView` takes `cell: Cell` by value — small struct, cheap to compare.
- Split the timer into its own `TimelineView(.periodic(...))` or a separate `@Observable` so it doesn't re-render the board.
- Theme propagation: read `theme` once at the screen level; don't push it as a parameter into 480 child views — use `.environment(\.dkTheme, theme)` and let only views that *use* a token re-evaluate.
- Profile with Instruments → SwiftUI template before optimizing further. Don't pre-optimize what's not slow.

**Warning signs:**
- Frame drops during reveal cascade on iPhone 11 / iPhone 12 mini in Instruments.
- Timer tick visibly causes the board to "twitch."
- Switching theme mid-game causes a 100-300ms hitch.
- `CellView` body recompilation count is in the thousands per second in Instruments.

**Phase to address:** **P3** (polish — measure and tune). Don't pre-optimize in P2; ship the simplest grid that works, then verify in P3.

---

### Pitfall 7: Tap (reveal) and long-press (flag) gestures conflict — taps register as long-presses or long-press cancels the tap

**What goes wrong:**
Naive composition: each cell uses `.onTapGesture { reveal() }.onLongPressGesture { flag() }`. SwiftUI's gesture arbitration causes one of three failures:
1. A normal tap occasionally registers as a long-press if the user holds slightly too long (>0.5s default).
2. A flag long-press fails to commit because the tap fires first on touch-down.
3. On scrollable contexts (we don't have one for the board, but Settings will), long-press cancels parent ScrollView gestures.

Additionally, flag-on-revealed-cell needs to be a no-op — a long press on a revealed "3" should not toggle a flag on it.

**Why it happens:**
- Default tap and long-press in SwiftUI are not composed correctly without `.simultaneously(with:)` or `.exclusively(before:)`.
- Devs often discover the conflict mid-polish, after building both gestures separately.
- The "long-press came too late" feel on iPhone 16 Pro is different from iPhone 11; testing on one device hides it.

**How to avoid:**
- Use a single, explicit composed gesture: `LongPressGesture(minimumDuration: 0.25)` `.exclusively(before: TapGesture())`, attached via `.gesture(...)`. Long-press wins if the user holds; tap fires only on quick release.
- 0.25s minimum (not the default 0.5s) — Minesweeper veterans expect snappy flagging.
- In the cell's tap handler, early-return if `cell.isRevealed`. In the long-press handler, early-return if `cell.isRevealed`. Both cases are no-ops, but explicitly so.
- Add haptic feedback (DesignKit haptics) on long-press *commit* (after the 0.25s threshold) — gives the user tactile confirmation before they release.
- Test on at least one older device (iPhone 11 / SE 3rd gen) where touch latency feels different.

**Warning signs:**
- TestFlight reports of "tapped a cell and it flagged instead."
- Reveal feels "delayed" because tap is waiting to see if it becomes a long-press.
- Flagging a revealed cell unintentionally clears the reveal (state corruption).

**Phase to address:** **P2** (gesture wiring) **/ P3** (haptic + threshold tuning).

---

### Pitfall 8: DesignKit consumer mistakes — hardcoded colors / invented radii "just for the game grid"

**What goes wrong:**
Every game-screen polish pass tempts: "the unrevealed cell needs to be a slightly darker grey than `theme.colors.surface` — let me hardcode `Color(white: 0.85)` just here." Two weeks later the Dracula preset (very dark backgrounds) makes that hardcoded grey nearly invisible, and the Voltage preset (saturated yellows / blacks) makes it look like a bug. Same with radii: dev decides cells should have a 4pt radius, doesn't see one in DesignKit (`{card, button, chip, sheet}`), and types `RoundedRectangle(cornerRadius: 4)`. Now switching themes never adjusts cell radius, and the DesignKit ecosystem invariant (sister apps consume the same tokens) is broken.

**Why it happens:**
- "I'll fix the token later" never gets fixed.
- DesignKit's token vocabulary doesn't always have a perfect match for game UI (cells aren't cards, aren't buttons, aren't chips).
- Dev forgets the "personality from preset, not from invented styling" rule (`CLAUDE.md` §1).
- Theme legibility audit happens late (P3) — by then there are dozens of small token violations to fix.

**How to avoid:**
- Codify in P1: any `Color(...)` literal, any numeric corner radius, any numeric spacing in a `.swift` file under `Games/` or `Screens/` is a lint failure. Add a simple `swiftlint` custom rule or grep-based pre-commit: `grep -r "Color(hex:" Games/ Screens/` and `grep -rE "cornerRadius:\s*[0-9]+" Games/ Screens/` should both return nothing.
- For game-grid needs DesignKit doesn't cover, add the token *to DesignKit* (per `AGENTS.md` §2). Likely additions for Mines: `theme.colors.surfaceElevated` for unrevealed cell, `theme.colors.surface` for revealed cell, accent for flag, danger for mine, success for win overlay, semantic per-number colors (1-8) — but verify against existing tokens first; many already exist.
- Establish the cell-token map *before* writing `MinesweeperCellView`. One commit: "Add token map for Mines cell states" with a comment in the view referencing that decision.
- For radii: cells use `theme.radii.chip` (the smallest existing radius). Don't invent new ones unless they're added to DesignKit and used by a sister app too.

**Warning signs:**
- Any `Color(...)`, `Color.gray`, `RoundedRectangle(cornerRadius: <literal>)`, `padding(<literal>)` in `Games/Minesweeper/`.
- A theme switch on the game screen produces a visible regression on any preset.
- A new "helper" file like `MinesColors.swift` with hand-picked greys.

**Phase to address:** **P1** (token-discipline lint) **/ P3** (legibility audit gate).

---

### Pitfall 9: Theme presets that wreck Mines UX — adjacency numbers indistinguishable, accent collides with flag color

**What goes wrong:**
`PROJECT.md` THEME-01 says "Minesweeper UI verified legible on at least one preset from each DesignKit category." In practice:
- Soft presets (Cream, Paper, Sand) have low-contrast palettes — the "1" and "2" adjacency numbers may both render in a desaturated blue/green that visually merges. Players can't tell a 1 from a 2.
- Loud presets (Voltage, Vaporwave) have saturated backgrounds — revealed-vs-unrevealed contrast can collapse if both cell states use semi-transparent fills over the same vivid background.
- `theme.colors.accentPrimary` is reused for both the flag icon and many UI affordances. If the dev maps "flag" to accent, on a preset where accent is bright red, the flag merges with mines (which are also typically red/danger-colored).
- Minesweeper's traditional 8 number colors (1=blue, 2=green, 3=red, 4=dark-blue, 5=brown, 6=cyan, 7=black, 8=grey) are an *informational* color system — they need to remain distinguishable across all presets, not just "look pretty."

**Why it happens:**
- Devs verify on Classic + one Moody preset and call it done.
- Preset variety wasn't on the radar when number colors were assigned to tokens.
- Accent collision is overlooked because in dev (Forest preset) accent is green, flag stands out fine.
- DesignKit's tokens are *semantic* (success / danger / accent), not *informational* (1 / 2 / 3 / ...). Mines needs an informational palette inside the semantic system.

**How to avoid:**
- Define a Mines-specific number palette inside DesignKit: `theme.colors.minesweeperNumber(1)` ... `(8)` — derived per-preset to maintain WCAG AA contrast against `theme.colors.surface`. This is a token addition (push it into DesignKit, per the constitution) so sister-app games can reuse it (Sudoku will need 1–9 numbers; Nonogram numbers; etc.). Even if only Mines uses it now, naming it generically (`theme.colors.gameNumber(_:)`) reserves it.
- **Hard ship gate** — a smoke test that loads every one of the 34 presets, generates a sample Hard board, and asserts pairwise contrast ratio ≥ 3:1 between adjacent number values (1 vs 2, 2 vs 3, etc.) and ≥ 4.5:1 between revealed and unrevealed cell. Fails the build if any preset breaks. (This sounds heavy but is a one-time test using `Color`'s luminance.)
- Flag uses a token *distinct* from `accentPrimary` if accent is in the warm/red family in a preset. Map flag to `theme.colors.warning` or a derived "flagColor" token; verify it never matches the mine indicator.
- `PROJECT.md` THEME-01 already requires one-per-category — strengthen to "all 34 presets" for the contrast smoke test, manual visual check on representative presets per category.

**Warning signs:**
- Player feedback "I can't tell which number is which on Cream theme."
- Switching preset mid-game makes the board look worse.
- Flag and mine indicator blend on Voltage / Ember presets.

**Phase to address:** **P3** (theme legibility audit, contrast smoke test). Token additions land in DesignKit before the audit runs.

---

### Pitfall 10: Stats lost on force-quit during a game / timer drift across backgrounding

**What goes wrong:**
PERSIST-02 requires "stats survive app force-quit, crash, and device reboot." Two distinct bugs:
1. **Game-result not committed before crash:** dev increments stats only on the win/loss screen's `onAppear`, after a 1-second win-sweep animation. User wins, animation starts, user force-quits. Result: win never counted.
2. **Timer drift across backgrounding:** elapsed time is implemented as `Timer.scheduledTimer` accumulating into a `@State` var. App backgrounds → timer suspends → returns 30s later → timer continues from where it was, undercounting. Or: timer is wall-clock based but doesn't pause on background, so a user who answers a phone call has a 4-minute Easy time.

**Why it happens:**
- Dev places `saveStats()` at the *end* of the game-over flow (after animation), not at the *moment* of game-over.
- Timer logic naively uses `Timer.publish` which suspends in background.
- Force-quit is rare in dev; only TestFlight users hit it.

**How to avoid:**
- Game-over must persist *immediately and synchronously* on result detection, before any animation or overlay. Pattern:
  1. Engine returns `.won(elapsed)` or `.lost`.
  2. ViewModel calls `statsStore.recordResult(...)` (writes to SwiftData).
  3. `try modelContext.save()` is called explicitly (not relying on autosave) — autosave delay can drop a record on force-quit.
  4. *Then* trigger animation.
- Timer is wall-clock based: store `gameStartedAt: Date` and an array of `pauseIntervals: [(start, end)]`. Elapsed = `Date.now - gameStartedAt - sum(pauseIntervals)`. On `scenePhase == .background`, append `(Date.now, nil)`; on `.active`, close the interval. This survives backgrounding and gives a stable elapsed even after a 4-minute interruption.
- For mid-game state survival on force-quit (defer to "later" if scope is tight, but bake the model in): persist current board state to SwiftData on every move OR via `.onChange(of: scenePhase)` → background → save snapshot. Restore on launch with a "Resume game?" prompt. MVP: at minimum, persist on background, restore on launch. Force-quit during a game = lost game (acceptable for MVP); force-quit between games = stats intact (mandatory).

**Warning signs:**
- "I won but my stats didn't update" reports.
- Timer reads weird durations after a backgrounded session.
- `try modelContext.save()` is not called explicitly anywhere in the codebase.

**Phase to address:** **P4** (stats persistence robustness, scene-phase handling). Timer logic in P2 should already use wall-clock + scene-phase pauses; don't ship a `Timer.publish` accumulator.

---

### Pitfall 11: App Store / TestFlight gotchas — privacy nutrition label, capability provisioning, bundle ID drift

**What goes wrong:**
Submission day, App Store Connect rejects or stalls because:
- **Privacy nutrition label inconsistent with what the binary does:** dev marked "Data Not Collected" but enabled CloudKit. Apple's stance: data processed *only on device* is not collected; CloudKit private database where the developer cannot access the data is also "not collected" (the user's own iCloud, encrypted, dev has no access). But marking "Data Not Collected" while having ANY analytics SDK or any CloudKit *public* database tips the form. App Review can flag this if the metadata doesn't match the binary.
- **Sign in with Apple capability missing** in `GameKit.entitlements` — auth flow crashes at runtime with `ASAuthorizationErrorUnknown`.
- **CloudKit container not provisioned for Production** — works in development sandbox, fails in TestFlight because Production environment is empty.
- **Bundle ID friction:** dev decides post-MVP to rename `com.lauterstar.gamekit` → `com.lauterstar.GameKit` for naming consistency. Existing TestFlight users effectively have a different app; their stats / sign-in / iCloud records are stranded. (Already called out in `CLAUDE.md` §1 / `PROJECT.md` Constraints, but it bears repeating because it's irreversible damage.)

**Why it happens:**
- Privacy label form is filled at submission time, often in a rush, by someone other than the dev.
- Capabilities are easy to enable in Xcode (toggle), but the entitlements file isn't always checked into git (or is, but not regenerated correctly after a Team change).
- CloudKit Dashboard's two-environment model (Development / Production) is non-obvious and not surfaced in Xcode.
- Bundle ID feels like a string until it's not.

**How to avoid:**
- Ship a **release checklist** in `Docs/` (or `.planning/`) covering: capabilities verified, entitlements file diff-ed, CloudKit schema deployed to Production, container ID stable, privacy nutrition label answered (with reasoning recorded — "CloudKit private DB, encrypted, dev has no access → Not Collected"), Sign in with Apple tested in production.
- Lock bundle ID `com.lauterstar.gamekit` in P1 — `PROJECT.md` already does. Add a CI/pre-commit check that flags any `.pbxproj` change to `PRODUCT_BUNDLE_IDENTIFIER`.
- For privacy: the app collects **nothing**. CloudKit private DB does not transmit data the developer can access; with proper answer it is "Data Not Collected." Confirm by reading Apple's "User Privacy and Data Use" before submission. If you ever add an analytics SDK (you won't, per constitution), the label changes.
- Test the CloudKit production environment via TestFlight *before* App Review, not during.

**Warning signs:**
- Entitlements file shows changes you didn't make (Xcode auto-add).
- `git diff` on `project.pbxproj` shows bundle ID changing.
- "Works in Xcode but not TestFlight for CloudKit" — almost always production schema not deployed.
- Privacy nutrition label form was filled out in <2 minutes by someone who didn't read the questions.

**Phase to address:** **P5** (release). Bundle ID stability is a **P1** invariant.

---

### Pitfall 12: SwiftUI ModelContainer initialized at cold-start blocks the Home screen, breaking FOUND-01 (<1s cold start)

**What goes wrong:**
Standard SwiftData pattern: `.modelContainer(for: [GameStats.self, ...])` on `WindowGroup`. With CloudKit enabled, container init does iCloud schema reconciliation, which can be slow on cold start (especially first launch after install, where it may make a network round-trip). Cold start exceeds 1s. P0 bug per `PROJECT.md` Constraints.

**Why it happens:**
- `.modelContainer(...)` modifier blocks the scene from rendering until the container is ready.
- First-launch CloudKit handshake is variable latency.
- Dev tests on "warm" simulator with no real iCloud, never sees the cold path.

**How to avoid:**
- Render Home with a *local-only* ModelContainer at cold start. Spin up the CloudKit-mirrored container *after* `onAppear` of Home, off the main thread, then swap or wire it in. This is non-trivial but matches how Apple's sample apps handle it.
- Alternative: ship local-only in P1–P3 (no CloudKit at all). Adding CloudKit in P4 lets you measure cold-start delta directly and adjust. Don't enable CloudKit until P4 explicitly.
- Measure cold start in CI: `xcrun simctl launch --console-pty <device> com.lauterstar.gamekit` → assert <1s on a recent simulator. Failure = build failure.

**Warning signs:**
- Cold-start time on iPhone 16 simulator > 1.0s after enabling CloudKit.
- Home screen flashes a blank state for 1-2s on first launch.
- TestFlight users on slow networks report "the app takes forever to open."

**Phase to address:** **P4** when CloudKit lands — measure cold-start regression and address before merging.

---

### Pitfall 13: Accessibility regressions ship — VoiceOver labels missing, reduce-motion ignored, Dynamic Type breaks the grid

**What goes wrong:**
- **VoiceOver:** each cell renders `Text("3")` or an SFSymbol with no `accessibilityLabel`. VoiceOver reads "3" or "image" with no context. Player can't tell unrevealed from flagged from numbered.
- **Reduce-motion:** the win-sweep animation runs full-throttle for users who set Settings → Accessibility → Motion → Reduce Motion = on. For motion-sensitive users this triggers nausea; A11Y-03 already requires dampening.
- **Dynamic Type:** all non-grid text respects DT (per A11Y-01) but the dev applies `theme.typography.body` to the cell text too. At AX5 (largest accessibility size), the "5" in a Hard cell overflows its 18pt cell, making the entire grid unreadable.

**Why it happens:**
- Accessibility is treated as a final-polish concern, not designed in.
- Dev tests on default settings, not with VoiceOver / Reduce Motion / large Dynamic Type enabled.
- Cells are visually small (Hard cells are tiny on iPhone) and the dev never imagined typography scaling them.

**How to avoid:**
- Cell `accessibilityLabel`: state + position + adjacency. E.g. "Unrevealed, row 3 column 5" / "Revealed, 2 mines adjacent, row 3 column 5" / "Flagged, row 3 column 5." Build this into `MinesweeperCellView` from day 1 (P2), not added in P3.
- `accessibilityValue` and `accessibilityHint` ("Double tap to reveal, double tap and hold to flag") complete the pattern.
- Wrap animations in `if !UIAccessibility.isReduceMotionEnabled` *or* use `theme.motion.normal` set to 0 when reduce-motion is on (DesignKit motion tokens may already handle this — verify; if not, propose the addition). Even simpler: wrap `withAnimation(theme.motion.normal)` in an `accessibilityReduceMotion`-aware helper.
- Cell text uses a fixed-size font (or a typography token like `theme.typography.gameCell`) that doesn't scale with Dynamic Type, while *all surrounding chrome* (counter, timer, settings) scales. Mines numbers must remain readable in their cells; that's a fixed-grid invariant, not a DT invariant.
- Test pass before "done": VoiceOver navigation through a partial board, Reduce Motion ON during a win, Dynamic Type set to AX3 / AX5, smallest device (iPhone SE).

**Warning signs:**
- VoiceOver reads "image" or "3" with no context.
- A reduce-motion-on user reports the win animation still plays.
- AX5 Dynamic Type renders the grid as overlapping numbers.

**Phase to address:** **P3** (accessibility pass — but cell `accessibilityLabel` baked in at P2 to avoid retrofit cost).

---

### Pitfall 14: Project hygiene — Finder-dupe `*.swift 2` files, hand-patched `project.pbxproj`, stale simulator SwiftData stores breaking test runs

**What goes wrong:**
Already burned the team per `CLAUDE.md` §8.7-§8.9 / `AGENTS.md` §9.7-§9.9. Recap:
- Xcode 16 (`objectVersion = 77`) uses `PBXFileSystemSynchronizedRootGroup` — every `.swift` in a folder is auto-compiled. A Finder-duplicated file (`MinesEngine 2.swift`) causes "invalid redeclaration" and blocks the entire target build.
- Hand-patching `project.pbxproj` to add a file produces merge-conflict-prone diffs and is unnecessary in Xcode 16; just drop the file in the folder.
- Test-runner crashes with `_findCurrentMigrationStageFromModelChecksum` mean the simulator has a stale SwiftData store from a prior schema. It's not a code bug.

**Why it happens:**
- macOS Finder + iCloud Drive duplicates files when there's a conflict, naming them `Foo 2.swift`.
- Habit of hand-editing pbxproj from older Xcode workflows.
- Schema changes during dev create stranded simulator stores.

**How to avoid:**
- Pre-commit hook: `find . -name '*\ 2.swift' | grep .` returns nothing — fail commit if any.
- Codify in onboarding: "Don't edit `project.pbxproj` to add a Swift file. Drop it in the folder."
- Test-runner crash triage: `xcrun simctl uninstall <device> com.lauterstar.gamekit` first, retry, *then* debug.
- A `Scripts/reset-sim.sh` one-liner saves time across the team.

**Warning signs:**
- `git status` shows untracked `*\ 2.swift` files.
- `project.pbxproj` diff in a feature commit (suspect — should only happen for new top-level folders or target-membership changes).
- Tests fail with `NSStagedMigrationManager` in the trace.

**Phase to address:** **P1** (hooks + onboarding doc) — the cost of these issues is so cheap to prevent and so expensive to debug that they belong in foundation.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode a color "just for the cell grid" because no token fits perfectly | Saves 5 min in P2 | Theme switch breaks legibility on at least one of 34 presets; refactor cost is finding every literal across game folder | **Never** — codified in `CLAUDE.md` §1. Add the token to DesignKit instead. |
| Skip `String(localized:)` for engine-internal strings ("they're not user-facing") | Saves boilerplate in P2 | Strings leak to UI later (debug overlay, accessibility labels, error toasts) and are now untranslatable; xcstrings catalog has gaps that show up in diff reviews | When the string genuinely never reaches the UI (asserts, log-only). Default to `String(localized:)` everywhere user-touchable. |
| Use `Timer.publish` for elapsed time | Trivial implementation | Timer drifts on backgrounding; stats become wrong | **Never.** Use wall-clock `Date` + scene-phase accumulator. |
| Re-fetch SwiftData in every reusable subview | Each view "owns" its data | Same query runs 30+ times on a screen; every save triggers cascading re-renders | **Never.** Per `CLAUDE.md` §8.2: parent owns query, children take props. |
| Skip the "Resume game?" feature in MVP | One less screen to build | Force-quit during Hard game = ~10 min lost. User churn after one bad accident | **Acceptable for MVP** but accept the bug and mention in TestFlight notes. Restoration lands in v1.1. |
| Initialize `ModelContainer` synchronously on `WindowGroup` with CloudKit on | Default Apple pattern | Cold start exceeds 1s on first launch (P0 violation per `PROJECT.md`) | Only when CloudKit is **off**. With CloudKit on, the container init must be deferred. |
| Use `LazyVGrid` for all difficulties | "Lazy = faster" intuition | LazyVGrid has overhead on non-scrolling fixed boards; eager `Grid` is often faster for ≤256 cells | Acceptable on Hard (480 cells) if measured to be faster; never assume. |
| Map flag color to `theme.colors.accentPrimary` | Reads "branded" | Collides with mine-danger color on warm-accent presets (Forest, Maroon, Ember) | **Never** without contrast verification per preset. |
| Defer accessibility to P3 | Faster P2 | Cell labels need the same VM as cell rendering; retrofitting touches every cell view | Cell `accessibilityLabel` ships in P2 with the cell view. Reduce-motion / Dynamic Type tuning is fine to defer to P3. |
| Run `xcodebuild test` without uninstalling stale sim apps | "It worked yesterday" | `NSStagedMigrationManager` crash in CI; hours wasted on fake bug | When schema hasn't changed since last green run. Always uninstall on schema change. |

---

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **SwiftData + CloudKit** | Use `@Attribute(.unique)` and non-optional fields, then enable CloudKit later | Design models for CloudKit constraints from day 1, even when shipping local-only. Test container init with CloudKit config at P1. |
| **CloudKit Dashboard** | Forget to deploy schema to Production before TestFlight | Add "Promote schema to Production" to the release checklist; verify by toggling environment in dashboard before each TestFlight build. |
| **CloudKit container ID** | Rename mid-development | Lock container ID in P1 (`iCloud.com.lauterstar.gamekit`); CI check on `Info.plist` / entitlements changes flags any drift. |
| **Sign in with Apple** | Treat sign-in as one-shot, no revocation handling | `getCredentialState(forUserID:)` on every active scene transition; observe `credentialRevokedNotification`; clear local sign-in state on `.revoked` / `.notFound`. |
| **Sign in with Apple** | Store Apple user ID in UserDefaults | Use Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; survives backgrounds, doesn't sync across devices. |
| **App Review (Guideline 4.8)** | (N/A here — Sign in with Apple is the *only* auth, no third-party login to require parity for. But the inverse trap: adding any third-party login later mandates Sign in with Apple parity. Stay Apple-only.) | If a future game adds Game Center / GameKit framework auth, verify whether 4.8 applies. For MVP: zero exposure. |
| **DesignKit (local SPM dep)** | Edit DesignKit and forget to commit it to the DesignKit repo | DesignKit changes are PRs to `../DesignKit` first; GameKit consumes via path. Two-commit dance: commit in DesignKit, then commit consumption in GameKit. |
| **DesignKit ThemeManager** | Initialize `ThemeManager` per-view (e.g. each game makes its own) | One `@StateObject` at app root, `@EnvironmentObject` everywhere — per `DesignKit/README.md` Quickstart. |
| **String catalog** | Migrate from NSLocalizedString partway, leave both styles in code | EN-only ship is fine, but commit to `String(localized:)` exclusively from P1. xcstrings auto-extracts only from `String(localized:)` usage. |
| **Privacy Nutrition Label** | Fill out at submission, no audit | Decide answer in P1 ("Data Not Collected" — no analytics, CloudKit private DB only); document reasoning; verify against current binary at P5. |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Re-rendering the full 480-cell grid on every state change | Frame drops on Hard reveal cascade; timer tick causes UI twitch | `Equatable` cells; theme via environment; timer in separate view; profile in Instruments before optimizing | Visible at Hard mode (480 cells) on iPhone 11 / SE. Easy / Medium are fine. |
| Recursive flood-fill on Hard | Stack overflow risk on degenerate boards (very few mines in a corner of a 16x30) | Iterative flood-fill using a queue, not recursion. Test on a 16x30 with mines clustered in one corner — flood may visit ~470 cells in one cascade. | Theoretically possible at 16x30; iterative is cheap insurance. |
| Animating every cell flip in a 100+ cell cascade | Animation duration exceeds user patience; input blocked during animation | Stagger reveal animations slightly (per-cell 10-20ms offset, capped total ~300ms), don't block input — let user start the next move while the cascade finishes | At Hard mode after a corner first-tap that cascades 200+ cells. |
| `@Observable` ViewModel republishes board on every cell update | All 480 cells re-evaluate on every reveal | Update by replacing only the changed cells in a copy-on-write structure, or use `@Bindable` with selective `objectWillChange` | At Hard mode during cascades. |
| ModelContainer init at cold start with CloudKit | App takes 1.5-2s to render Home on first launch | Defer CloudKit container; render Home from local-only first | At first launch with CloudKit signed-in user on slow network. |
| Stats fetch in `StatsView`'s body | Query runs on every redraw | Fetch in `init` or via `@Query`, pass into reusable subviews as props | Per `CLAUDE.md` §8.2 — already codified. |

---

## Security Mistakes

Domain-specific security issues beyond general iOS basics.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing Apple user ID with `kSecAttrAccessibleAlways` | Token exposed when device is locked | Use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — accessible after first unlock post-boot, not synced across devices, not exposed pre-unlock. |
| Logging the Apple user ID or auth identityToken to console | Token in OSLog persistent buffer; appears in sysdiagnose / shared crash reports | Never log auth tokens. Use os.log with `.private` privacy modifiers around any auth-related fields. |
| Treating CloudKit private DB as "private therefore shareable" | It's the user's data, not yours. Misconfiguring to public DB exposes everything | Always `.privateCloudDatabase`. Never write user data to `.publicCloudDatabase` (the only legitimate public-DB use here would be e.g. shared theme packs — none in MVP). |
| Bundle entitlements include Sign in with Apple but app is rejected | App Review notes "missing capability" because entitlements file disagrees with capability toggle | Verify entitlements file is committed to git and matches the Xcode capability checkbox. Diff entitlements file before each TestFlight build. |
| Privacy Nutrition Label says "Data Not Collected" while later adding analytics | False statement to App Store; potential rejection | Hard rule (already in constitution): no analytics ever. If anyone proposes adding crash reporting (Crashlytics, etc.), it changes the label and requires re-submission. Apple's own MetricKit is acceptable and doesn't change "not collected." |
| Export/Import JSON written to insecure location, including stats from another user (multi-user device — unlikely but) | Stats leakage | Export/Import targets a user-chosen file via `fileExporter` / `fileImporter`; never written to a shared cache directory. |

---

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Win/loss overlay blocks input until animation completes | "I have to wait for the celebration to start a new game" — irritating on rapid replays | Restart button is tappable from frame 1 of the overlay; animation is a backdrop, not a gate. |
| 3-step intro shows on every launch (state-tracking bug) | "This app keeps re-onboarding me" — instant uninstall trigger | Persist `hasSeenIntro: Bool` in UserDefaults; verify on launch with a test that simulates first launch + second launch. |
| Long-press to flag has no haptic confirmation before commit | Player isn't sure if their flag registered until they release; double-flags happen | Haptic at the 0.25s long-press threshold, then a second confirm-haptic on flag commit. DesignKit haptics handle this — wire to `theme.haptics.<...>`. |
| Stats screen empty state is "0 / 0 / —" with no copy | Looks like a bug | Per `CLAUDE.md` §8.3: explicit empty copy ("No games played yet. Start your first game to see your stats here.") before the chart/list ships. |
| Theme picker is the most visible thing in Settings | Settings screen feels like a "theme gallery" rather than functional settings | Per DesignKit Pattern A: 5 Classic swatches + "More themes & custom colors" link. Full picker on a separate screen. |
| Sign-in card nags after dismissal | "I said no, stop asking" | Surfaced *once* in 3-step intro and *once* in Settings. Never modal, never push, never re-prompted. PERSIST-05 already states this. |
| Reset Stats has no confirmation | Tap, all stats gone, no recovery | Confirmation alert with explicit "Reset" + "Cancel"; consider an undo affordance (10s undo banner) — though the latter is polish. |
| Theme switch mid-game causes visual glitch (unrevealed cells appear to "flash" through old colors before settling) | Looks broken | Apply theme change with a short cross-fade animation tied to `theme.motion.fast`. Or block theme switching while a game is active and queue the change for game-over (heavier-handed; only if cross-fade isn't smooth enough). |
| Subtle SFX on by default | Coffee-shop play surfaces unwanted sound | **Off by default** — `PROJECT.md` MINES-10 already specifies. |
| No "how to play" affordance for new users | First-time players bounce | The 3-step intro covers themes + stats + sign-in, *not* gameplay. Mines is recognizable enough that explicit rules likely aren't needed for v1, but a one-screen "Tap to reveal, long-press to flag" hint on first game launch is cheap insurance. Defer if scope-bound. |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **First-tap safety:** verify on (a) Easy corner tap (b) Hard corner tap (c) Hard center tap — assert mine count and safe-zone in tests.
- [ ] **Win detection:** all non-mine cells revealed = win. Verify off-by-one — a Hard board has 16x30 - 99 = 381 non-mine cells; win triggers at exactly 381 reveals. Test: 380 = ongoing, 381 = win.
- [ ] **Flag-on-revealed:** long-press on a revealed cell is a no-op — explicit unit test.
- [ ] **SwiftData ModelContainer init with CloudKit config:** test passes even before CloudKit is enabled to catch model violations early.
- [ ] **CloudKit production schema deployed** before any TestFlight build that uses CloudKit.
- [ ] **Sign in with Apple entitlement** present in `.entitlements` file *and* committed to git *and* matches the Xcode capability.
- [ ] **Credential revocation observed:** `credentialRevokedNotification` has a registered observer; `getCredentialState` runs on scene-active.
- [ ] **VoiceOver labels:** every cell has a context-rich label; navigated through a partial board with VO on.
- [ ] **Reduce Motion:** win-sweep / loss-shake honor the system setting.
- [ ] **Dynamic Type:** non-grid text scales to AX5 without overflow; grid stays fixed.
- [ ] **Theme legibility:** Hard board sample rendered + visually verified on at least one preset from each of Classic / Sweet / Bright / Soft / Moody / Loud (per THEME-01) — and contrast smoke test passes for all 34 presets if implemented.
- [ ] **Cold start:** measured <1s on iPhone 16 simulator with CloudKit on (post-P4).
- [ ] **Force-quit recovery:** kill app via simulator force-quit between games, relaunch — stats intact. During a game — stats not corrupted (game lost is acceptable; corruption is not).
- [ ] **Export/Import round-trip:** export JSON → reset stats → import → all original values restored, including `schemaVersion`.
- [ ] **Bundle ID stability:** `git log -p --follow GameKit.xcodeproj/project.pbxproj | grep PRODUCT_BUNDLE_IDENTIFIER` shows no changes since P1.
- [ ] **Privacy nutrition label** decided and documented before submission; matches what the binary actually does.
- [ ] **No `Color(...)` literals or numeric radii** in `Games/` or `Screens/` — grep returns empty.
- [ ] **No `*\ 2.swift`** files in repo (Finder dupes).
- [ ] **EN-only at v1, but xcstrings catalog has zero stale entries** — Xcode flag-clean.
- [ ] **Plurals correct in xcstrings** for "X mines remaining" — uses `String(localized:)` with `defaultValue:` plural variants.

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| First-tap loss bug ships | LOW | Hot-fix the engine; ship 1.0.1 within days; no data corruption. |
| `@Attribute(.unique)` slipped into a model and was discovered post-CloudKit-enable | MEDIUM | Migrate model: remove the macro, write a migration that handles existing records, ship as a schema bump. Bug-fix deploy before TestFlight goes wide. |
| Local-to-CloudKit sign-in promotion lost stats for early TestFlight users | HIGH | Apologize, can't recover — local store is gone unless user has a device-level backup. Ship a fix and a "this won't happen again" note. Cost is trust. |
| Bundle ID renamed mid-TestFlight | HIGH | Effectively unrecoverable — early users have a different app. Either revert the rename quickly (before more users install the new ID) or accept the cohort split. **Never rename once daily-use begins.** |
| CloudKit container ID drifted | HIGH | Same as above; container ID is part of the app's identity to iCloud. Revert if caught early; if not, accept that those users' cloud records are stranded. Local store is intact. |
| Sign in with Apple credentials revoked en masse (rare — Apple doesn't do this) | LOW per app | Each user re-prompts on next launch via `getCredentialState`; their CloudKit data remains. UX inconvenience, no data loss if anonymous-mode is feature-parity (per PERSIST-04). |
| Cold start regressed to 1.5s after enabling CloudKit | LOW | Defer CloudKit container init off the main thread / past Home render. Measurable in CI, fix in a focused commit. |
| Theme legibility regression on a specific preset | LOW | Add the missing token to DesignKit, update the offending view to use it, verify across all presets. |
| Stale simulator SwiftData store crashes CI tests | LOW | `xcrun simctl uninstall` step in CI before each `xcodebuild test`. |
| Privacy nutrition label submitted incorrectly | MEDIUM | Update label in App Store Connect; if app already shipped with wrong label, file a metadata-only update — no binary change needed. |
| Force-quit lost a game's worth of stats | LOW | Per game = small. Document the limitation in v1; ship resume-game in v1.1. |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. First-tap loss / corner-tap edge case | **P2** | Three explicit unit tests (Easy corner, Hard corner, Hard center) committed with engine. |
| 2. SwiftData CloudKit constraints violated | **P1** (model design) **/ P4** (verify) | `ModelContainer` test with `cloudKitDatabase` config, even pre-CloudKit. |
| 3. Silent CloudKit sync failures | **P4** | Sync-status row in Settings; production schema deployed before TestFlight. |
| 4. Sign-in promotion data loss | **P4** | Manual test: seed local data → sign in → verify cloud has all records. |
| 5. Sign in with Apple revocation/reinstall | **P4** | Test matrix: revoke via system Settings → relaunch → graceful sign-out. |
| 6. Grid re-render perf | **P3** | Instruments measurement on Hard mode at 60fps target, iPhone SE / 11. |
| 7. Tap/long-press conflict | **P2** (compose gesture correctly) **/ P3** (tune threshold + haptic) | Manual test on iPhone SE + iPhone 16 Pro; flag-on-revealed unit test. |
| 8. DesignKit consumer mistakes (hardcoded colors / radii) | **P1** (lint) **/ ongoing** | Pre-commit grep for `Color(`, `cornerRadius:\s*\d`, `padding(\s*\d` in `Games/` and `Screens/`. |
| 9. Theme presets break Mines legibility | **P3** | Visual audit on one preset per category + contrast smoke test (optional but cheap). Hard ship gate per THEME-01. |
| 10. Force-quit / timer drift | **P4** (persistence robustness) **/ P2** (timer wall-clock from start) | Force-quit during/between-games test; backgrounded-timer test. |
| 11. App Store / TestFlight gotchas | **P5** (release checklist) **/ P1** (bundle ID lock) | Pre-submission checklist; CI flag on `PRODUCT_BUNDLE_IDENTIFIER` change. |
| 12. ModelContainer cold-start blocks Home | **P4** | CI cold-start measurement; <1s assertion. |
| 13. Accessibility regressions | **P2** (cell labels) **/ P3** (motion + DT pass) | VoiceOver navigation; Reduce Motion ON win replay; AX5 Dynamic Type smallest device. |
| 14. Project hygiene (Finder dupes, pbxproj, sim stores) | **P1** (hooks + onboarding) | Pre-commit hook; `Scripts/reset-sim.sh`; documented in CLAUDE.md (already done §8.7-§8.9). |

---

## Sources

- [Designing Models for CloudKit Sync: Core Data & SwiftData Rules — fatbobman](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
- [SwiftData, meet iCloud — Alex Logan](https://alexanderlogan.co.uk/blog/wwdc23/08-cloudkit-swift-data)
- [Best way to handle unique values with SwiftData and CloudKit — Hacking with Swift Forums](https://www.hackingwithswift.com/forums/swiftui/best-way-to-handle-unique-values-with-swiftdata-and-cloudkit/30145)
- [Some Quirks of SwiftData with CloudKit — firewhale.io](https://firewhale.io/posts/swift-data-quirks/)
- [Syncing SwiftData with CloudKit — Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit)
- [SwiftData CloudKit integration requirements — Apple Developer Forums](https://developer.apple.com/forums/thread/735349)
- [Local SwiftData to CloudKit migration data loss — Apple Developer Forums](https://developer.apple.com/forums/thread/756538)
- [Fixing SwiftData & Core Data Sync: initializeCloudKitSchema — fatbobman](https://fatbobman.com/en/snippet/resolving-incomplete-icloud-data-sync-in-ios-development-using-initializecloudkitschema/)
- [Deploy your CloudKit-backed SwiftData entities to production — leojkwan](https://www.leojkwan.com/swiftdata-cloudkit-deploy-schema-changes/)
- [SwiftData ModelActor concurrency pitfalls — Massicotte](https://www.massicotte.org/model-actor/)
- [SwiftData ModelContainer documentation — Apple Developer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [Handling account deletions and revoking tokens for Sign in with Apple — Apple Developer Forums](https://developer.apple.com/forums/thread/708415)
- [A Comprehensive Guide to Implementing Apple Sign-In Token Revocation — Medium](https://medium.com/@dabhir16/a-comprehensive-guide-to-implementing-apple-sign-in-token-revocation-in-ios-applications-e30d36c43e33)
- [App Review Guidelines (4.8 Design: Login Services) — Apple Developer](https://developer.apple.com/app-store/review/guidelines/)
- [Guideline 4.8 Design Login Services — Apple Developer Forums](https://developer.apple.com/forums/thread/750911)
- [SwiftUI Grid, LazyVGrid, LazyHGrid Explained — SwiftLee](https://www.avanderlee.com/swiftui/grid-lazyvgrid-lazyhgrid-gridviews/)
- [SwiftUI gestures — Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/how-to-use-gestures-in-swiftui)
- [Customizing Gestures in SwiftUI — fatbobman](https://fatbobman.com/en/posts/swiftuigesture/)
- [Privacy Nutrition Label with encryption — Apple Developer Forums](https://developer.apple.com/forums/thread/710456)
- [App Privacy Details — Apple Developer](https://developer.apple.com/app-store/app-privacy-details/)
- [User Privacy and Data Use — Apple Developer](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Xcode String Catalog (.xcstrings) Guide — SimpleLocalize](https://simplelocalize.io/blog/posts/xcstrings-string-catalog-guide/)
- [Localizing and varying text with a string catalog — Apple Developer](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Minesweeper Rules Explained — minesweeperhub](https://minesweeperhub.com/minesweeper-rules-explained/)
- [Minesweeper for Beginners (corner/edge strategy) — Cyber-Sweeper](https://cybersweeper.io/beginners-guide)
- Internal sources: `/Users/gabrielnielsen/Desktop/GameKit/CLAUDE.md` §8.1-§8.12 (session-derived rules from prior pain), `/Users/gabrielnielsen/Desktop/GameKit/AGENTS.md` §9.1-§9.12, `/Users/gabrielnielsen/Desktop/GameKit/.planning/PROJECT.md`, `/Users/gabrielnielsen/Desktop/DesignKit/README.md` (token vocabulary).

---

*Pitfalls research for: GameKit (iOS Minesweeper-first suite, SwiftData + optional CloudKit, DesignKit consumer)*
*Researched: 2026-04-24*
