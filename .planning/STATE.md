---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: "Phase 7 Release pre-flight in progress. ✅ PF-01 doc-drift / PF-02 icon / PF-07 name=GameDrawer / PF-05 code-side (Settings ABOUT rows + AppInfo URLs targeting gamedrawer.lauterstar.com — DNS deploy pending) / repo health audit (SettingsView 556→347, MinesweeperVM 472→393, GameDescriptor routing). ☐ PF-03 CloudKit Dev → Production schema deploy via Dashboard / PF-04 schema verify / PF-05 DNS go-live / PF-06 theme-matrix screenshots / PF-08 ASC metadata / PF-09 nutrition label. Then SC1-SC5 sweep + TestFlight."
last_updated: "2026-05-01T00:00:00.000Z"
last_activity: 2026-05-01
progress:
  total_phases: 8
  completed_phases: 7
  total_plans: 49
  completed_plans: 46
  percent: 94
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-24)

**Core value:** Calm, premium, fully theme-customizable gameplay with zero friction — no ads, no coins, no pushy subscriptions, no required accounts.
**Current focus:** Phase 07 — Release (pre-flight PF-01..09 + SC1-SC5 sweep before TestFlight upload). v1.0 ships under display name **GameDrawer**.

## Current Position

Phase: 07-release — PRE-FLIGHT
Plan: pre-flight tasks PF-01..09 (canonical: `.planning/phases/07-release/07-CHECKLIST.md`)
Status: PF-01 (doc-drift) ✅ · PF-02 (icon) ✅ · PF-07 (name = GameDrawer) ✅ · PF-03/04 (CloudKit Prod schema deploy) ☐ · PF-05 (privacy.md live URL) ☐ · PF-06 (theme-matrix screenshots) ☐ · PF-08 (ASC metadata) ☐ · PF-09 (privacy nutrition label) ☐
Last activity: 2026-05-01

Progress: [█████████░] 94%

## Performance Metrics

**Velocity:**

- Total plans completed: 16
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 8 | - | - |
| 02 | 1 | 3 min | 3 min |
| 05 | 7 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: — (no execution history yet)

*Updated after each plan completion*
| Phase 01 P01 | 190 | 2 tasks | 2 files |
| Phase 01-foundation P02 | 4 | 2 tasks | 2 files |
| Phase 01-foundation P04 | 2 | 1 tasks | 1 files |
| Phase 01-foundation P03 | 180 | 2 tasks | 4 files |
| Phase 01-foundation P05 | 14 | 2 tasks | 1 files |
| Phase 01-foundation P06 | 2 | 1 tasks | 4 files |
| Phase 01-foundation P07 | 120 | 3 tasks | 6 files |
| Phase 01-foundation P08 | 15 | 2 tasks | 1 files |
| Phase 02-mines-engines P01 | 3 | 2 tasks | 5 files |
| Phase 02-mines-engines P02 | 144 | 1 tasks | 1 files |
| Phase 02-mines-engines P03 | 591 | 2 tasks | 7 files |
| Phase 02-mines-engines P04 | 618 | 2 tasks | 2 files |
| Phase 02-mines-engines P05 | 222 | 2 tasks | 2 files |
| Phase 02-mines-engines P06 | 428 | 1 tasks | 1 files |
| Phase 03-mines-ui P01 | 8 | 2 tasks | 9 files |
| Phase 03-mines-ui PP02 | 12 | 3 tasks | 3 files |
| Phase 03-mines-ui PP03 | 6 | 4 tasks tasks | 4 files files |
| Phase 04-stats-persistence P01 | 4 | 2 tasks | 6 files |
| Phase 04-stats-persistence P02 | 8 | 1 tasks | 2 files |
| Phase 04-stats-persistence P03 | 10 | 2 tasks | 5 files |
| Phase 04-stats-persistence P04 | 3 | 2 tasks tasks | 2 files files |
| Phase 04-stats-persistence P05 | 21 | 5 tasks tasks | 5 files files |
| Phase 05-polish P01 | 18 | 2 tasks | 3 files |
| Phase 05-polish P03 | 12 | 2 tasks | 5 files |
| Phase 05-polish PP04 | 12 | 2 tasks | 4 files |
| Phase 05-polish P05 | 12 | 2 tasks tasks | 5 files files |
| Phase 05-polish P06 | 18 | 2 tasks tasks | 5 files files |
| Phase 05-polish P07 | 5 | 2 tasks | 2 files |
| Phase 06-cloudkit-siwa P01 | 5 | 3 tasks tasks | 3 files files |
| Phase 06-cloudkit-siwa P02 | 3 | 2 tasks | 2 files |
| Phase 06-cloudkit-siwa P03 (Tasks 1+2 of 3 — Task 3 checkpoint pending) | 3 | 2 tasks | 3 files |
| Phase 06-cloudkit-siwa P04 | 5 | 1 task | 2 files |
| Phase 06-cloudkit-siwa P05 | 13 | 1 tasks | 2 files |
| Phase 06-cloudkit-siwa P06 | 6 | 3 tasks | 3 files |
| Phase 06-cloudkit-siwa P07 | 25 | 3 tasks | 3 files |
| Phase 06-cloudkit-siwa P08 | 13 | 2 tasks | 1 files |
| Phase 06.1 P03 | 25 | 4 tasks | 3 files |
| Phase 06.1 P01 | 5 | 3 tasks | 4 files |
| Phase 06.1 P02 | 12 | 4 tasks | 5 files |

## Accumulated Context

### Roadmap Evolution

- Phase 6.1 inserted after Phase 6 (2026-04-27): pre-release polish — Home cards 2-per-row grid + Mines flag-mode toggle + Hard-board horizontal-scroll fix; pre-deploy gate before P7 wave 2 (URGENT)

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- **Roadmap (2026-04-24):** Adopted 7-phase sequence (Foundation → Mines Engines → Mines UI → Stats & Persistence → Polish → CloudKit + SIWA → Release) directly from research convergence — both ARCHITECTURE.md and PITFALLS.md proposed identical sequencing.
- **Roadmap (2026-04-24):** Phase 5 (Polish) and Phase 6 (CloudKit) flagged for `/gsd-research-phase` before planning; Phases 1, 2, 3, 4, 7 proceed direct to planning with standard patterns.
- **Project (2026-04-24):** MVP = Minesweeper only; second-game work deferred until Mines is shipping clean.
- **Project (2026-04-24):** SwiftData with CloudKit-compatible schema from day 1 even though CloudKit only turns on at Phase 6.
- **Project (2026-04-24):** Sign in with Apple + CloudKit private DB (optional, never gates gameplay) is the only auth/sync surface — no third-party backend.
- Deployment target fixed from 26.2 (template typo) to 17.0 per CLAUDE.md §1
- Bundle ID com.lauterstar.gamekit contractually frozen as of P1-01 commit 3e8c43a
- SWIFT_STRICT_CONCURRENCY = complete enabled across all 6 build configs
- CloudKit container ID iCloud.com.lauterstar.gamekit pinned in PROJECT.md; capability deferred to P6 per D-10
- Pure shell + core.hooksPath bootstrap chosen over lefthook/husky to match no-extra-dependency posture (P1-02)
- Hook scope limited to Games/ and Screens/ only; App/ and Core/ excluded for legitimate Color imports (P1-02)
- D-09: Docs/derived-data-hygiene.md ships as docs-only mitigation; escalate to script only if manual ritual becomes painful
- Colors baked into AppIcon PNGs at design time; icons are NOT theme-responsive (static bundle assets resolved at install time per CONTEXT D-06)
- D-07: DesignKit linked via Xcode UI (Add Local Package) — not hand-patched pbxproj; avoids malformed sync-root-group hooks in Xcode 16 objectVersion=77
- D-08: No version pin for DesignKit — local-path (../../DesignKit) tracks disk; breaking changes ripple immediately (accepted ecosystem risk per D-08)
- Used theme(using: colorScheme) from DesignKit public API — avoided theme(for:) shim per PATTERNS Note A
- RootTabView stub uses Rectangle().fill(theme.colors.background) — cleaner token consumption, avoids pre-commit hook edge cases
- NavigationStack owned by each tab root (HomeView/StatsView/SettingsView), not RootTabView — per ARCHITECTURE.md Anti-Pattern 3
- ComingSoonOverlay uses radii.chip + sparkles SF Symbol per D-06; 1.8s auto-dismiss via Task.sleep
- GameCard model stays local to HomeView.swift — single-use, DesignKit promotion threshold (2+ games) not met
- Localizable.xcstrings authored with 25 EN keys (extractionState:manual) to capture all P1 String(localized:) call sites; plurals deferred to P4; xcstrings in Resources/ auto-extracts future keys via SWIFT_EMIT_LOC_STRINGS=YES
- 02-01: MinesweeperDifficulty raw values lowercase 'easy'/'medium'/'hard' — locked stable serialization key for P4 (D-02); renaming = data break
- 02-01: MinesweeperDifficulty has no displayName/String(localized:)/description — engine layer carries no localized names per D-03; P3/P5 view layer owns mapping
- 02-01: MinesweeperGameState.lost carries mineIdx: MinesweeperIndex so P3 renders mineHit overlay without diffing; intentionally NOT Codable (P4 persists outcome via GameRecord, not live state)
- 02-01: MinesweeperBoard uses flat [Cell] indexed row*cols+col (Swift-idiomatic for fixed-size grids, simpler flood-fill); zero mutating funcs — engines compose replacingCell(at:with:) / replacingCells(_:) per D-10
- 02-01: MinesweeperCell.State is a single enum (hidden/revealed/flagged/mineHit); adjacency lives on Cell as `let adjacentMineCount` (precomputed at generation, read 100s of times per game)
- 02-01: Models layer ships with default internal visibility — @testable import gamekit reaches everything; no public surface needed
- 02-02: SeededGenerator (SplitMix64) test PRNG ships in test target only — production engines stay Foundation-only per D-12; nested test-folder auto-registered by Xcode 16 PBXFileSystemSynchronizedRootGroup with no pbxproj edits (CLAUDE.md §8.8 empirically validated for nested folders)
- 02-04: RevealEngine uses iterative BFS via Array<Index> queue + head pointer (Claude's Discretion per CONTEXT) — layer-by-layer reveal order maps cleanly to P3 MINES-08 cascade animation; visited set bounds work to O(rows*cols)
- 02-04: RevealEngine flag-protection (Pitfall 7) and idempotence (.revealed/.mineHit) share a single early-return path that returns (board, []) — pure no-op without entering the BFS algorithm
- 02-04: Plan 03 nonisolated lesson applied proactively — both 'nonisolated enum RevealEngine' and 'nonisolated struct RevealEngineTests' declared upfront so no Rule 3 deviation needed; this is now the standard pattern for Plan 02 engine + test pairs (Plan 05 should follow)
- 02-04: cornerClusteredHardBoard test hand-builds the 99-mine fixture inline (not via BoardGenerator) — keeps SC3 proof self-contained and reproducible regardless of BoardGenerator RNG order; 99 mines fit exactly in top-left 11x9, far-corner tap from (15,29) reveals >200 cells without stack growth
- 02-05: WinDetector finalizes ROADMAP P2 SC5 (engine purity) across all 3 engines (BoardGenerator + RevealEngine + WinDetector all Foundation-only); SC4 verbatim spec proven by 3 single-shot boundary tests + 30-seed mutualExclusionFuzz
- 02-05: isWon short-circuits via 'if isLost(board) { return false }' — mutual exclusion enforced at the function-body level, not just by test convention; D-17 invariant becomes a structural property of the implementation
- 02-05: Tests hand-craft won/lost/mixed boards via board.replacingCell / replacingCells (no RevealEngine dependency) — proves WinDetector correctness in isolation regardless of how a Board reached its state, simplifies bisection if RevealEngine ever regresses
- 02-06: Phase 2 ships — engine purity (SC5) proven by integrated grep across all 8 production files; full test suite green; Xcode template stub deleted per PATTERNS.md (D-15 finalized — Swift Testing replaces template scaffold)
- 02-06: CLAUDE.md §8.8 fully validated across all of Phase 2 — zero pbxproj hand-patching needed for new top-level folders, new test-target subfolders, same-folder file additions, OR file deletion under PBXFileSystemSynchronizedRootGroup (Xcode 16 objectVersion=77)
- 03-01: theme.gameNumber(_:) extension on Theme clamps n to 1...8 and reads gameNumberPaletteWongSafe ?? gameNumberPalette (D-13); 6 audit-set presets ship distinct length-8 palettes; 28 non-declared presets fall back to Classic via ColorDerivation.fallbackGameNumberPalette
- 03-01: Classic palette entry 5 retuned from purple #7B1FA2 to deep orange #E65100 (and entry 7 #FFC107 to #F9A825) to satisfy Wong audit ΔE2000 ≥ 10 under all three CVD simulations — purple/cyan adjacent pair collapsed under protanopia (ΔE 4.33). Classic IS the canonical safe palette per D-15 so the entries themselves were tuned rather than adding an override; threshold was NOT lowered
- 03-01: Loud presets (bubblegum, barbie, dracula, voltage) ship aesthetic gameNumberPalette defaults plus gameNumberPaletteWongSafe: classicGameNumberPalette override; resolver path always emits a Wong-safe palette via theme.colors.gameNumberPaletteWongSafe ?? theme.colors.gameNumberPalette (D-15)
- 03-01: PresetTheme.swift palette constants extracted to sibling extension PresetTheme+GameNumberPalettes.swift to keep palette-data growth scoped (CLAUDE.md §8.5); pre-existing ~791-line baseline of PresetTheme.swift kept out of scope per executor scope-boundary rule
- 03-01: DesignKitTests target uses XCTest (not Swift Testing) — PATTERNS critical correction held through implementation; ColorVisionSimulator helper is pure Foundation/SwiftUI, no third-party dep, ~240 lines including Brettel/Machado matrices + CIE ΔE2000 + sRGB↔Lab pipeline
- 03-02: MinesweeperViewModel — @Observable @MainActor final class with injection seams (clock, rng, userDefaults); first-tap firewall enforces exactly ONE BoardGenerator.generate call site (.idle branch in reveal); Foundation-only purity verified by grep + structural Swift Testing case
- 03-02: LossContext modeled as Equatable Sendable struct (not inline tuple from RESEARCH §Code Examples 1) — tuples not Equatable in Swift; struct ships at file scope alongside GameOutcome enum
- 03-02: 'var rng: any RandomNumberGenerator' stored existentially — Swift 5.7+ implicit existential opening lets &rng flow into BoardGenerator.generate's 'inout some RandomNumberGenerator' parameter cleanly (verified by build)
- 03-02: Tests use firstHiddenNonMine(on:) helper instead of hardcoded (8,8) target — seed-1 cascade reaches (8,8), making the literal coordinate brittle; helper guarantees the toggleFlag transition is exercised regardless of cascade reach
- 03-02: Wave-0 GameKit tests complete (5/5 across DesignKit + GameKit); Plan 03-03/03-04 view tier can author against locked VM contract — views never import engines directly
- 03-03: 4 leaf views ship props-only — receive theme: Theme as let parameter, never read @EnvironmentObject themeManager directly (RESEARCH Anti-Pattern 'Re-fetching theme tokens inside cell views'). MinesweeperGameView in Plan 04 hoists theme once and threads it down.
- 03-03: SC1 long-press constants locked in source — LongPressGesture(minimumDuration: 0.25).exclusively(before: TapGesture()). The 0.25s threshold and .exclusively (NOT .simultaneously) are the load-bearing patterns for SC1's 50-tap iPhone SE manual gate (scheduled in Plan 04 verification).
- 03-03: HeaderBar timer fallback uses .distantPast (not .now) when timerAnchor is nil — TimelineView stops firing entirely; display math returns pausedElapsed regardless of context.date. Practically equivalent but avoids wasted ticks (planner-noted choice).
- 03-03: ToolbarMenu trigger uses theme.typography.headline (17pt semibold) over .title (22pt) — fits Easy/Medium/Hard inside iPhone SE toolbar width; documented planner deviation from UI-SPEC's .title suggestion.
- 03-03: EndStateCard secondary 'Change difficulty' button calls onChangeDifficulty closure which Plan 04 will wire to viewModel.restart() per refined D-03 (W-02). Sheet-presented difficulty picker deferred to P5.
- 03-03: formatElapsed(_:) intentionally duplicated between HeaderBar and EndStateCard — 2 call sites in one game is below the DesignKit-promotion bar (CLAUDE.md §4); P5 may extract MinesweeperTimeFormat.swift if duplication grows.
- 04-01: @Model Date defaults use Date() (not .now) — @Model macro substitution rejects .now shorthand at expansion time; semantically identical because Date() == .now
- 04-01: SwiftData CloudKit-compat constraints validated by Wave-0 SC3 smoke test from day 1 — both .none and .private('iCloud.com.lauterstar.gamekit') configurations pass with isStoredInMemoryOnly: true (Assumption A2 confirmed: CloudKit handshake skipped when in-memory)
- 04-01: Container ID 'iCloud.com.lauterstar.gamekit' is now a load-bearing literal in test source (D-09 forcing-function lock) — any rename anywhere trips the smoke test deliberately on PR
- 04-01: P4 Core tests use @MainActor struct (NOT P2's nonisolated struct) — ModelContext is not Sendable per RESEARCH Pattern 6; locked as standard for ALL P4 Core tests
- 04-01: Comment text rewords 'no @Attribute(.unique)' as 'no SwiftData unique-attribute decorator' so source negative-greps for the literal token stay clean while preserving the documentation intent
- 04-02: GameStats is @MainActor final class with single private let modelContext: ModelContext + os.Logger; record(...) wraps evaluateBestTime in do/catch so flaky predicate cannot block GameRecord persistence (Discretion lock); resetAll uses modelContext.transaction { delete(model:) × 2 } for atomic batch-delete (D-13)
- 04-02: BestTime mutation uses strictly-less-than guard — equal-seconds is no-op on both seconds and achievedAt; matches PROJECT.md calmer-fewer-writes tone and avoids unnecessary CloudKit sync-token consumption when sync flips on in P6
- 04-02: Capture-let predicate pattern locked (let kindRaw = gameKind.rawValue before #Predicate) — RESEARCH Pattern 4 footnote: KeyPath cannot capture self; future P4 service patterns inherit this idiom
- 04-02: TDD plan-level RED→GREEN gate sequence honored — test commit ed5cce6 (build error: 'Cannot find type GameStats in scope') landed BEFORE feat commit f3974bd; verifiable in git log --oneline
- 04-02: os.Logger first-use in GameKit at subsystem 'com.lauterstar.gamekit', category 'persistence' (RESEARCH §Standard Stack); error interpolation uses privacy: .public for diagnostic logs (non-PII fetch error names) — locked as standard for all future P4 services
- 04-03: StatsExporter is @MainActor enum (D-16) — codec namespace pattern matches P2 engines; ModelContext non-Sendable still requires actor isolation even for static surface
- 04-03: Codec layer split into 4 files (envelope/error/document/exporter) instead of inlining — each has a single responsibility; document is the only file requiring SwiftUI/UniformTypeIdentifiers, isolating the SwiftUI dependency to the FileDocument bridge alone
- 04-03: Encoder configuration [.prettyPrinted, .sortedKeys] + .iso8601 is non-negotiable for SC4 byte-for-byte determinism (RESEARCH Pitfall 7); .sortedKeys grepped in CI verify and tested by encoderDeterministic
- 04-03: importing(...) runs decode -> validate schemaVersion == 1 -> transaction { delete x2; insert } -> save (RESEARCH Pitfall 6) — schemaVersion guard sits BEFORE destructive transaction; future-schema files cannot destroy data; proven by schemaVersionMismatchThrows test
- 04-03: roundTripFifty asserts SEMANTIC payload byte-equality (decode both, sort by id, re-encode (gameRecords, bestTimes) under same encoder) instead of raw two-export Data equality — exportedAt = .now makes raw byte-equality structurally impossible across two export() calls; SC4 intent (records survive identically) preserved
- 04-03: UUID + per-row schemaVersion preserved across round-trip via post-init assignment (rec.id = r.id; rec.schemaVersion = r.schemaVersion) — default id: UUID = UUID() would emit fresh UUIDs and break SC4; init param list stays minimal for the GameStats.record(...) call site
- 04-03: TDD plan-level RED -> GREEN gate sequence honored — test commit 453e6ee (Cannot find type StatsExporter in scope) precedes feat commit a9384c8 in git log; identical pattern to Plan 04-02; locked as standard for P4 codec layers
- 04-03: P4 Wave-0 COMPLETE — 4/4 required test artifacts (smoke + GameStats + StatsExporter + InMemoryStatsContainer) shipped before any production wiring; downstream Plans 04-04/05/06 author against locked APIs without risk of cascading fixes back into Wave-0 files
- 04-04: SettingsStore is @Observable @MainActor final class over UserDefaults.standard with cloudSyncEnabled: Bool surface (D-28); didSet writes / init reads at construction (D-29); Foundation+SwiftUI imports only — no SwiftData at the settings layer
- 04-04: Custom EnvironmentKey + EnvironmentValues.settingsStore extension is the iOS-17-canonical injection path for @Observable types — @EnvironmentObject requires ObservableObject and is incompatible with @Observable (P3 RESEARCH Pitfall 1 inheritance). @MainActor static let defaultValue satisfies Swift 6 strict concurrency
- 04-04: Existing @StateObject themeManager seam in GameKitApp.swift preserved VERBATIM — only additive changes per 04-PATTERNS.md line 9 critical correction; @State + _ivar = State(initialValue:) rebinding pattern in App.init() locked for @Observable values that need to be read BEFORE other init
- 04-04: Three-place lock for iCloud.com.lauterstar.gamekit honored end-to-end — PROJECT.md:141 + GameKitApp.swift:52 (production literal in cloudKitDatabase ternary) + ModelContainerSmokeTests.swift:52 (Plan 04-01 smoke test). T-04-16 forcing function: rename in one place trips smoke test on PR
- 04-04: do/catch fatalError on ModelContainer init failure (RESEARCH §Code Examples 1) — silent persistence loss would break PERSIST-02; Plan 04-01 smoke test gates schema regressions at PR time so production fatalError indicates OS-level disk/sandbox issue. P4 Wave-2 COMPLETE (3/3 plans: GameStats + StatsExporter + App composition)
- 04-05: VM 5th seam APPENDED at tail-of-init (D-14 + 04-PATTERNS line 11) — preserves the existing 4 seams verbatim, default nil keeps Plan 03-02 tests green
- 04-05: recordTerminalState ordering enforced at call site — gameState→freezeTimer→recordTerminalState; inverting freeze/record silently records durationSeconds:0 because frozenElapsed reads pausedElapsed (RESEARCH Pitfall 3)
- 04-05: GameStats injection via .task modifier + @State didInjectStats one-shot guard — RESEARCH Pitfall 8 mitigation; never construct GameStats inside body
- 04-05: VM stays Foundation-only — GameStats? forward-resolved within gamekit module per RESEARCH Code Examples 4 line 1131; ARCHITECTURE Anti-Pattern 1 enforced by vmSourceFile_importsOnlyFoundation grep gate
- 04-05: StatsView two @Query declarations + file-private MinesStatsCard/MinesDifficultyStatsRow receive props — CLAUDE.md §8.2 data-driven-not-data-fetching pattern; @Query lives once in parent
- 04-05: SettingsView .fileImporter security-scoped URL bookends LOAD-BEARING for real-device imports — defer-guarded release; if didStart guards against double-release (RESEARCH Pitfall 5)
- 04-05: xcstringstool sync (not Xcode catalog editor) — deterministic command-line catalog population from build-time .stringsdata; default behavior removes orphaned automatic entries while preserving manual ones
- 05-01: MinesweeperPhase enum (5 cases per CONTEXT D-06) declared Equatable + Sendable only — NOT Hashable (would force [MinesweeperIndex] payload Hashable, no consumer needs it), NOT Codable (transient view-layer enum, never persisted, matches MinesweeperGameState precedent)
- 05-01: SettingsStore extended additively — 3 new flags hapticsEnabled (default true) / sfxEnabled (default false) / hasSeenIntro (default false) under keys gamekit.{hapticsEnabled,sfxEnabled,hasSeenIntro}; cloudSyncEnabled + EnvironmentKey injection preserved verbatim
- 05-01: hapticsEnabled init uses (object(forKey:) as? Bool) ?? true pattern — bool(forKey:) returns false for unset keys per Apple docs, and a default-true flag must survive fresh installs without .register(defaults:) (intentionally avoided per existing P4 invariant SettingsStore.swift:25-26)
- 05-01: TDD plan-level RED→GREEN gate honored — test commit 64dc5be (build error: 'no member hapticsEnabledKey/sfxEnabledKey/hasSeenIntroKey' x 14) precedes feat commit 19c4f32 in git log; same TDD pattern locked across P4-02/P4-03/P5-01
- 05-01: isLossShake helper (var isLossShake: Bool) added to MinesweeperPhase per RESEARCH §Pattern 2 — keyframe-trigger reads a Bool value-change rather than payload-bearing case match, so a fresh .lossShake(mineIdx:) doesn't replay against the same payload pointer in .keyframeAnimator
- 05-03: Haptics is @MainActor enum (NOT class) per CONTEXT D-11 — static methods only, no env-key injection; call sites use Haptics.playAHAP(...) directly
- 05-03: SFXPlayer is @MainActor final class injected via custom EnvironmentKey mirroring SettingsStore D-29 pattern; @State sfxPlayer construction in GameKitApp.init() AFTER SettingsStore (D-12)
- 05-03: Both services gate at the source — hapticsEnabled / sfxEnabled is the FIRST guard inside the service method; call sites pass settingsStore.{flag} explicitly so services have NO SettingsStore coupling (D-10)
- 05-03: SFXPlayer init non-throwing under all conditions including missing CAFs — players become nil, play(...) is no-op via optional-chain; critical because Plan 05-02 Task 3 (CAF binaries) deferred and SFXPlayer must construct cleanly so GameKitApp.init() does not crash
- 05-03: Swift Testing .disabled(if: Bundle.main.url(...) == nil, 'TODO(05-02-CAF)...') gates the file-presence assertion — auto un-skips when CAF files land; cleaner than try #require which would fail the test
- 05-03: AVAudioSession.setCategory(.ambient) called ONCE in SFXPlayer.init() — adversarial grep verifies only 1 actual call site in entire gamekit/gamekit/ codebase; threat T-05-07 (audio session drift) mitigated by construction
- 05-03: Test-seam dual pattern locked — lastInvocationAttempt set BEFORE the gate (records every call) + lastPlayedEvent set ONLY AFTER the gate passes; distinguishes 'method called with disabled' from 'method never called', proves D-10 contract directly. All seams #if DEBUG-gated.
- 05-03: TDD plan-level RED→GREEN gate honored for both services — bf38819 precedes 695f753 (Haptics); a7fa1ec precedes a2116a6 (SFXPlayer); 4 commits in TDD order visible in git log --oneline
- 05-04: SettingsToggleRow uses Toggle(label, isOn:) + .labelsHidden() to satisfy A11Y-02 — VoiceOver reads 'Haptics/Sound effects, switch button, on/off' per UI-SPEC line 174-175. Empty-string Toggle initializer NOT used anywhere; adversarial negative-grep gate locks the contract
- 05-04: AcknowledgmentsView extracted to sibling Screens/AcknowledgmentsView.swift instead of file-private inside SettingsView.swift — keeps SettingsView under CLAUDE.md §8.1 ~400-line soft cap (final: 410 lines incl. expanded P5 doc-header). Planner-anticipated fallback per Plan §STEP 9 + UI-SPEC §Component Inventory line 232
- 05-04: P4 DATA section preserved BYTE-IDENTICAL per CONTEXT D-16 — verified via diff of git show HEAD:... lines 125-162 vs current SettingsView.swift lines 187-224; exit code 0. Locked invariant for future Settings touches
- 05-04: Navigation graph for Plan 05/06 LOCKED — RootTabView → SettingsView (NavigationStack owner) → FullThemePickerView (NavigationLink) AND RootTabView → SettingsView → AcknowledgmentsView (NavigationLink). Both destinations DO NOT own their own NavigationStack (CLAUDE.md / ARCHITECTURE Anti-Pattern 3)
- 05-05: Both Skip and Done call dismissIntro() — single source of truth for hasSeenIntro=true + dismiss (PATTERNS line 451). RootTabView.onAppear reads the flag ONCE; cold-relaunch reads persisted true from UserDefaults via SettingsStore.init
- 05-05: Step 3 uses .accessibilityElement(.contain) not .combine — SIWA owns its own a11y label (Apple HIG forbids tint/label override); .contain lets VoiceOver navigate the SIWA button as its own element while still reading title/body in order
- 05-05: Sample stats in Step 2 are hand-coded literals (Easy 12/8/67%/1:42, Medium 5/2/40%/4:15, Hard —/—/—/—) — onboarding never shows the empty state per CLAUDE.md §8.3
- 05-05: SIWA capability registered in P5 (not P6) per RESEARCH §Standard Stack lines 213-214 + 1058 — entitlement key com.apple.developer.applesignin = [Default] in gamekit.entitlements, CODE_SIGN_ENTITLEMENTS set on Debug + Release of gamekit app target only (not test targets). Build proof: codesign now invoked with --entitlements <derived>.xcent (post-Task-2)
- 05-05: pbxproj edit is the legitimate CLAUDE.md §8.8 capability exception (target-config change, not new source file registration); synchronized root group untouched — gamekit.entitlements is a non-source build resource referenced via CODE_SIGN_ENTITLEMENTS only
- 05-06: VM additively publishes phase + revealCount + flagToggleCount; Foundation-only invariant intact (single import Foundation); P3 ViewModelTests still 31/31 green
- 05-06: revealCount idempotency contract — bumps only when RevealEngine returns ≥1 cell (engine D-19 returns (board,[]) for already-revealed); .sensoryFeedback(.selection) does NOT fire on rejected reveals (calmer haptic profile)
- 05-06: Phase set BEFORE freezeTimer in win/loss branches — gameState→phase→freezeTimer→recordTerminalState; preserves P4 04-05 ordering lock and prevents SwiftData failure logging from intercepting the phase change
- 05-06: Loss shake .keyframeAnimator trigger uses viewModel.phase.isLossShake Bool (not payload-bearing case match) — fresh .lossShake(mineIdx:) doesn't replay against same payload pointer (RESEARCH §Pattern 2)
- 05-06: Win-wash Rectangle z-ordered ABOVE board, BELOW end-state DKCard; .allowsHitTesting(false) double-enforces non-blocking; Reduce Motion → phases [0.0] (no fade)
- 05-06: Reduce Motion gates per surface independently (D-04) — BoardView .identity transition; CellView .symbolEffect value=0; GameView .keyframeAnimator trigger=false + .phaseAnimator phases=[0.0]; VM stays Foundation-only (D-05)
- 05-06: TDD plan-level RED→GREEN gate honored — test commit 6b31869 (12 compile errors before any phase property defined) precedes feat commit 421cfcc; same TDD pattern as 04-02/04-03/05-01/05-03
- 06-01: Wave-0 TDD RED-gate shipped — KeychainBackend.swift (126 lines, prod) + InMemoryKeychainBackend.swift (30 lines, tests-only) + AuthStoreTests.swift (190 lines, RED skeleton). Verbatim SC2 attribute set locked: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly + kSecClassGenericPassword + service 'com.lauterstar.gamekit.auth'. Test target compile-fails 9× ('cannot find AuthStore/CredentialStateProvider in scope') — Plan 06-04 feat commit will flip GREEN. Single atomic commit per CLAUDE.md §8.10 (test(06-01): a18a186).
- 06-02: SyncStatus.swift (63 lines, Foundation-only) ships the D-10 4-state contract verbatim (.syncing / .syncedAt(Date) / .notSignedIn / .unavailable(lastSynced: Date?)) as Equatable + Sendable; label(at now: Date) -> String pure function takes `now` explicitly (TimelineView 06-07 + tests drive determinism — no internal Date.now). Verbatim labels locked: 'Syncing…' / 'Synced just now' / 'Synced %@' (RelativeDateTimeFormatter .named .full) / 'Not signed in' / 'iCloud unavailable'. T-06-state-drift mitigation by construction: 5th case = compile error in exhaustive switch.
- 06-02: CloudSyncStatusObserverTests.swift (157 lines) ships @MainActor @Suite skeleton with 9 @Test methods (5 state-machine + 4 label tests); applyEvent_forTesting(type: NSPersistentCloudKitContainer.EventType, endDate: Date?, succeeded: Bool, error: Error?) seam locks Plan 06-05 observer API surface BEFORE the production type exists. RED-gate verbatim: 'cannot find CloudSyncStatusObserver in scope' (line 55:24). Single atomic commit per CLAUDE.md §8.10 (test(06-02): a0d4364) — both tasks shipped together because the test file references SyncStatus symbols introduced in Task 1, so a Task-1-only commit would be intermediate dead code.
- 06-02: Sibling-enum-file pattern locked across the codebase — Outcome.swift / GameKind.swift / SyncStatus.swift all small (≤80 lines) Foundation-only Sendable enums in their own file. Sendable conformer is a pure value type (enum), so no @MainActor crossing protocol isolation — the strict-concurrency error class that bit Plan 06-01 (`@MainActor` on Sendable-protocol conformer requiring `@unchecked Sendable` + non-MainActor class) is structurally avoided here.
- 06-03: Wave-0 capabilities preflight Tasks 1+2 shipped (b1f2956 entitlements doc-comment lock + b0b1ed0 DEBUG-only CloudKitSchemaInitializer + GameKitApp._runtimeDeployCloudKitSchema lldb entry point). Container literal `iCloud.com.lauterstar.gamekit` is now anchored at a 4th canonical site. ENTIRE Core/CloudKitSchemaInitializer.swift gated by single `#if DEBUG ... #endif`; Release build succeeds → production binary contains zero schema-deploy symbols (T-06-schema-prod-leak structurally mitigated). GameKitApp init() body byte-identical to pre-plan; helper appended after preferredScheme. Task 3 = checkpoint:human-verify (Xcode capability sweep + lldb schema deploy + CloudKit Dashboard verification of CD_GameRecord + CD_BestTime in Development env) — BLOCKING for Plan 06-09 SC3, paused awaiting user resume signal.
- 06-04: Wave-1 GREEN gate shipped (e43cc79) — gamekit/gamekit/Core/AuthStore.swift (232 lines, ≤240 budget) flips Plan 06-01's 7 RED AuthStoreTests GREEN. @Observable @MainActor final class composes KeychainBackend (D-16) + CredentialStateProvider (PATTERNS §6 line 384) seams. Selector-based addObserver (NOT block-based with queue:.main) preserves Plan 06-01 Test 2 sync-test contract (state cleared BEFORE NotificationCenter.post returns). MainActor.assumeIsolated inside @objc handleRevocation(_:) is the narrow-correct shape on @MainActor class. Pitfall F early-return (`if error != nil { resume(returning: .notFound); return }`) ensures continuation resumes exactly once. Logger NEVER interpolates userID (T-06-02 lock proven by adversarial grep returning 0). Zero references to UserDefaults/identityToken/SwiftData/ModelContext/ModelContainer (T-06-01/03/08 locks). AuthStore stays single-responsibility — does NOT inject SettingsStore (Q2 RESOLVED-declined per CLAUDE.md §4 "smallest change"). Full regression `** TEST SUCCEEDED **`.
- 06-04: Rule 3 deviation — gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift body wrapped in `#if SKIP_OBSERVER_TESTS` so the test target compiles while Plan 06-05 is unshipped. Without the gate, Plan 06-02's symbol-level RED ("cannot find CloudSyncStatusObserver in scope") prevents the entire test target from linking and blocks `xcodebuild test -only-testing:gamekitTests/AuthStoreTests` from running (compile happens before -skip-testing). Plan 06-05 GREEN-gate executor MUST delete both `#if SKIP_OBSERVER_TESTS` and `#endif` lines when shipping Core/CloudSyncStatusObserver.swift; search for `SKIP_OBSERVER_TESTS` to find the exact lines. Plan 06-02's RED contract preserved structurally — removing the gate without the production type immediately resurfaces the same 9-error symbol-level RED.
- 06-05: Wave-1 GREEN gate fully landed (a7d10db) — gamekit/gamekit/Core/CloudSyncStatusObserver.swift (198 lines, ≤200 budget) flips Plan 06-02's 9 RED CloudSyncStatusObserverTests GREEN. @Observable @MainActor final class subscribed to NSPersistentCloudKitContainer.eventChangedNotification; translator (applyEvent) is single source of truth for the 4-state machine, called by both production handleEvent path AND #if DEBUG applyEvent_forTesting seam (PATTERNS §S5 — NSPersistentCloudKitContainer.Event has no public init). private(set) var status enforces observer-only-writer contract. EnvironmentKey injection (\.cloudSyncStatusObserver) mirrors SettingsStore D-29 pattern. Full xcodebuild test green; AuthStoreTests still 7/7 GREEN — no regression. Wave-1 (06-04 AuthStore + 06-05 CloudSyncStatusObserver) COMPLETE; ready for Wave-2 wiring.
- 06-05: Background-then-hop pattern (Task { @MainActor [weak self] in ... }) chosen over MainActor.assumeIsolated — RESEARCH §Q4 RESOLVED locks Apple's eventChangedNotification as background-queue delivery (queue:nil registration), so assumeIsolated would crash on isolation mismatch. Differs deliberately from AuthStore which uses assumeIsolated because credentialRevokedNotification has CONTRACTUAL main-thread delivery (Apple docs). Both shapes are correct in their context — locks the rule that observer-pattern actor-hop choice depends on the notification's posting-thread contract, not on a one-size-fits-all preference.
- 06-05: Event snapshot extracted OFF main before the actor hop — read-only access to Apple value-type-like Event properties (type/endDate/succeeded/error) is thread-safe; only Sendable scalars cross the boundary into Task { @MainActor [weak self] in ... }. Avoids capturing the full Event reference into the Task closure (would require Event: Sendable, which Apple does not declare). Pattern locked for future CloudKit/CoreData notification observers.
- 06-05: Plan 06-04 Rule 3 deviation (#if SKIP_OBSERVER_TESTS gate) cleanly REVERSED — both #if and matching #endif lines deleted from gamekitTests/Core/CloudSyncStatusObserverTests.swift. The 9-test suite now exercises the production CloudSyncStatusObserver type directly. Pattern validated end-to-end: a Rule 3 source-level guard wrapping a TDD RED skeleton is the correct mechanism to keep an upstream test target compiling while a downstream production type ships in a parallel plan — and the next plan in the chain MUST mechanically remove the guard as part of its acceptance criteria.
- 06-06: Wave-2 integration #1 shipped (19f693b) — single atomic commit `feat(06-06): wire AuthStore + observer + scenePhase + Restart alert at app root` (3 files / 95 insertions / 0 deletions, purely additive). GameKitApp.init() construction order is now SettingsStore → SFXPlayer → AuthStore → CloudSyncStatusObserver → schema → ModelContainer; observer initialStatus reads `store.cloudSyncEnabled ? .syncing : .notSignedIn` so a fresh-install/cloudSync-OFF user sees the SettingsView SYNC row at "Not signed in" by Plan 06-07 paint-time without a state-machine flip. Body chain extends `.environmentObject(themeManager)` → `.environment(\\.settingsStore, …)` → `.environment(\\.sfxPlayer, …)` → `.environment(\\.authStore, …)` → `.environment(\\.cloudSyncStatusObserver, …)` → `.preferredColorScheme(…)` → `.modelContainer(…)`. T-06-06 container ID literal `iCloud.com.lauterstar.gamekit` BYTE-IDENTICAL preserved at line 79.
- 06-06: RootTabView consumes only `\\.scenePhase` + `\\.authStore` (NOT `\\.cloudSyncStatusObserver` — observer is read by SettingsView only per CONTEXT D-11). scenePhase observer hops to a Task before awaiting `authStore.validateOnSceneActive()`; revocation→cloudSync flip is a pure RootTabView concern (`onChange(of: authStore.isSignedIn)` / `if wasSignedIn && !isNowSignedIn { settingsStore.cloudSyncEnabled = false }`) which keeps AuthStore single-responsibility (Q2 RESOLVED in 06-04 Summary — AuthStore does NOT inject SettingsStore). Same-store-path D-08 lock means the next cold start reconfigs `cloudKitDatabase: .none` while preserving local rows; cloud rows preserved server-side per Pitfall 4.
- 06-06: Root-level `.alert(isPresented: Bindable(authStore).shouldShowRestartPrompt)` — Bindable constructed in-place at the alert call site (no @Bindable property needed; @Observable + Bindable inits cheaply). Verbatim D-04 copy: title "Restart to enable iCloud sync", body "Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup.", Cancel button uses `role: .cancel`, Quit GameKit button uses default role (NOT .destructive — quitting is non-destructive). Both buttons are dismiss-only — empty Button bodies. T-06-05 / D-05 LOCK proven by the negative-grep gate `! grep -E "exit\\(0\\)|UIApplication\\.shared\\.suspend|abort\\(\\)" gamekit/gamekit/Screens/RootTabView.swift gamekit/gamekit/App/GameKitApp.swift` returning zero matches.
- 06-06: Source-comment self-discipline — the Quit GameKit button comment was reworded to remove literal substrings `exit(0)`, `UIApplication.shared.suspend`, `abort()` from prose so the negative-grep gate stays clean even when the comment narrates the prohibition. Same pattern as P4 04-01 "no SwiftData unique-attribute decorator" comment rewording. Locked as standard for any future hard-grep gate that has prose-explanation alongside code-prohibition: rephrase prose to NOT name the literal API tokens.
- 06-06: xcstringstool sync (deterministic CLI per STATE.md 04-05 / 05-04 precedent) added 8 P6 strings — 4 Restart alert (Restart to enable iCloud sync / Quit GameKit / Cancel pre-existing / "Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup.") + 4 SyncStatus labels carried forward from Plan 06-02 source (Syncing… / Synced just now / Synced %@ / iCloud unavailable / Not signed in). 24 insertions, 0 deletions, JSON validity preserved. Empty `{ }` entry shape (no localizations) matches existing pre-Cancel auto-extracted entries (e.g. "Reset all stats?", "Privacy") — resolves to development-language source string at runtime; no warning, no broken behavior. Plan 06-07 will rerun sync after SettingsView SYNC section adds remaining strings.
- 06-07: Wave-2 integration #2 shipped (9974f92) — single atomic commit `feat(06-07): settings SYNC section + extracted SettingsSyncSection.swift + xcstrings sync` (3 files / 225 insertions / 0 deletions). New file `Screens/SettingsSyncSection.swift` (215 lines, ≤220 budget) declares `struct SettingsSyncSection: View` consumed by SettingsView body — extraction precedent from P5 05-04 (AcknowledgmentsView) reapplied because adding ~50 lines inline would have pushed SettingsView from 410 to ~460 (well over CLAUDE.md §8.1 ~400 soft cap). SettingsView body change is exactly +1 line (`SettingsSyncSection(theme: theme)`); existing dataSection BYTE-IDENTICAL preserved (P4 D-16 lock proven by zero-line `git show HEAD~ vs HEAD` diff).
- 06-07: D-09 section order locked verbatim in SettingsView body lines 77-81: appearanceSection → audioSection → SettingsSyncSection → dataSection → aboutSection. SYNC inserts strictly between AUDIO and DATA. Forcing function: any future Settings touch that adds another section MUST first extract one of the existing inline sections (appearanceSection / audioSection / aboutSection — dataSection is locked byte-identical) into a sibling file before adding new content; the host file remains exactly at its 411-line cap.
- 06-07: SIWA onCompletion handler shape locked across the codebase (Plan 06-08 IntroFlow Step 3 will mirror): `Task { @MainActor in switch result { case .success(let auth): guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { logger.error(...); return }; do { try authStore.signIn(userID: credential.user); settingsStore.cloudSyncEnabled = true; authStore.shouldShowRestartPrompt = true } catch { logger.error(...) } case .failure(let error): logger.error(...) } }`. Five threat mitigations enforced structurally: T-06-04 (`request.requestedScopes = []` SC2 verbatim), T-06-03 (only `credential.user` String crosses into AuthStore — never the one-shot JWT), T-06-row-noSignOut (signed-in row body has zero `Button(` declarations — ARCHITECTURE §line 423 + Pitfall 5), T-06-PERSIST05 (no `.alert(...)` modifier anywhere in this file — failure path is silent `os.Logger` only per PERSIST-05 "never nag"), and the `Task { @MainActor in ... }` wrap satisfies Swift 6 strict concurrency for the cross-actor `try authStore.signIn(...)` call.
- 06-07: Source-comment self-discipline rule extended (P6 06-06 precedent) — comments referencing prohibited tokens were rephrased so the negative-grep acceptance gates pass even when the comment narrates the prohibition. Specifically: literal `identityToken` replaced by `one-shot Apple-issued JWT` and literal `.alert(` replaced by `root-level prompt`. Both rephrasings preserve the documentation intent without producing a grep hit. Locks the rule for the third time across the project (P4 04-01 "no SwiftData unique-attribute decorator" + P6 06-06 Quit-button + P6 06-07 SIWA-handler comments).
- 06-07: D-12 sync-status row implementation — `TimelineView(.periodic(from: .now, by: 60))` wraps a `VStack(alignment: .leading, spacing: 2)` containing the primary status `Text` and an OPTIONAL "Last synced X" subline `Text` returned from `unavailableSubline(at: context.date)` (returns `nil` for non-`.unavailable` cases, so `if let subline = ...` cleanly drops the line). The `.periodic(by: 60)` cadence fires once per minute regardless of observer state — Apple's TimelineView+@Observable interaction means a CloudKit event mid-tick still triggers an immediate re-render via the `private(set) var status` read. Two refresh paths compose orthogonally; no observer churn from the timer.
- 06-07: SettingsSyncSection takes `let theme: Theme` as a positional prop (NOT @EnvironmentObject themeManager) — parent SettingsView owns the `themeManager.theme(using: colorScheme)` calculation and passes the result down. CLAUDE.md §8.2 (data-driven, not data-fetching) reapplied for sibling-view extractions. Pattern locked: any extracted Settings/section view receives `theme: Theme` as a prop; only @Environment-injects @Observable singletons (settingsStore / authStore / cloudSyncStatusObserver) plus `\.colorScheme` (needed for SignInWithAppleButton style choice).
- 06-07: xcstringstool sync (rerun per Plan 06-06 closing note) added 3 net-new SYNC-section strings — `SYNC` (section header), `Signed in to iCloud` (D-10 row label), `Last synced %@` (D-10 sub-line for `.unavailable(lastSynced: Date?)`). Combined with the 5 SyncStatus strings (extracted by Plan 06-06 sync from Plan 06-02 SyncStatus.swift source) and the 4 Restart-alert strings, the catalog now carries all 12 P6 strings. JSON valid; zero localization warnings on build. Empty `{ }` entries (no `localizations` block) match existing auto-extracted shape — resolves to development-language source at runtime.
- 06-08: Wave-2 integration #3 (FINAL integration plan) shipped (a5bcfd9) — single atomic commit `feat(06-08): wire IntroFlowView Step 3 SIWA onCompletion (replaces P5 D-21 no-op)` (1 file / 51 insertions / 36 deletions). PERSIST-04 end-to-end functional: BOTH SIWA-success sites (Settings SYNC from 06-07 + IntroFlow Step 3 from 06-08) now flip the same `authStore.shouldShowRestartPrompt`. Handler shape mirrored from 06-07 verbatim — `Task { @MainActor in switch result { case .success: guard credential = ... as? ASAuthorizationAppleIDCredential else { logger; return }; do { try authStore.signIn(userID: credential.user); settingsStore.cloudSyncEnabled = true; authStore.shouldShowRestartPrompt = true; dismissIntro() } catch { logger.error } case .failure: logger.error } }`. Five threat-mitigation locks proven by acceptance grep: T-06-04 (`request.requestedScopes = []` literal in `handleSIWARequest` + zero `.email`/`.fullName` matches), T-06-03 (only `credential.user` extracted, zero `identityToken` matches), T-06-PERSIST05 (zero `.alert(` matches in IntroFlowView — failure path silent os.Logger only), T-06-introdismiss (`dismissIntro()` body byte-identical between HEAD~ and HEAD, `diff` returns 0 lines), CLAUDE.md §8.6 (zero `.foregroundColor(` matches). File length 274→289 (within ≤290 hard cap; required tightening doc-comments and 14 lines off the file header). P5 `signInTapped()` no-op REMOVED — subsumed by `handleSIWARequest`. Zero new user-facing strings added (logger-only paths). All 12 P6 strings + P5 intro strings preserved. Full test suite green: AuthStoreTests 7/7 + CloudSyncStatusObserverTests 9/9 + all P2-P5 suites — `** TEST SUCCEEDED **`.
- 06-08: SIWA-success in intro is treated as Done — calls `dismissIntro()` so the `.fullScreenCover` dismisses (`hasSeenIntro = true` flips) and the user sees the Restart alert at the root level (RootTabView's `.alert(isPresented: Bindable(authStore).shouldShowRestartPrompt)` from Plan 06-06). The user is NOT trapped in the intro after a successful sign-in. Aligns with the spirit of P5 D-21/D-22/D-23 — every Step 3 exit path writes `hasSeenIntro = true` (Skip OR Done OR SIWA-success). Three-caller `dismissIntro()` pattern: P5 had 2 callers (Skip + Done); P6 06-08 adds the third (SIWA-success). Body BYTE-IDENTICAL to P5; only the doc-comment was updated to mention the new third caller.
- 06-08: `IntroStep3SignInView` signature change — `let onSignIn: () -> Void` REMOVED; `let onSIWARequest: (ASAuthorizationAppleIDRequest) -> Void` + `let onSIWACompletion: (Result<ASAuthorization, Error>) -> Void` ADDED. The two new closure props let the parent `IntroFlowView` thread its `handleSIWARequest` and `handleSIWACompletion` instance methods down without the child view depending on `@Environment(\.authStore)` directly — preserves P5's "leaf views are props-only" pattern (CLAUDE.md §8.2). The parent owns environment reads; the child receives shaped closures.
- 06-08: Mirrored handler shape from Plan 06-07 verbatim — both SIWA-success sites are now byte-similar at the call-site logic level. Eases future maintenance (e.g., adding rate-limiting, telemetry, retry on Keychain write failure — would update both sites identically). Locks the rule that any future SIWA-success site (e.g., a hypothetical "promote anonymous → signed-in" sheet from a Stats CTA) MUST follow the same `Task { @MainActor in switch result }` shape with the D-02/D-03 sequence. The handler is effectively a project-level pattern, not a per-screen one.
- 07-01: P7 doc-drift cleanup — refreshed ROADMAP.md plan-completion counts (P3 4/4, P4 6/6, P5 7/7, P6 9/9), synced REQUIREMENTS.md traceability (35/35 Complete), flipped 06-VERIFICATION.md status pending → complete with sign-off rows pointing to 06-UAT.md as canonical evidence per v1.0-MILESTONE-AUDIT.md, advanced STATE.md current_position to Phase 7. Single docs-only commit per CLAUDE.md §8.10. ZERO code changes.
- 2026-05-01: PF-01 verified clean — ROADMAP / REQUIREMENTS / 06-VERIFICATION already in sync from the earlier 07-01 sweep; STATE.md frontmatter + Current Position advanced to Phase 7 pre-flight in this pass. PF-01 row in 07-CHECKLIST.md eligible to tick.
- 2026-05-01: Display name renamed CorePlay → **GameDrawer** (full brand also GameDrawer, no Arcade suffix). Concrete drawer-of-games metaphor preferred over play/core abstraction. Bundle ID + repo unchanged per CLAUDE §1. Naming history GameKit → PixelParlor → PlayCore → CorePlay → GameDrawer logged in `assets/icon/AI_PROVENANCE.md`. P7 PF-07 unsatisfied → re-satisfied with GameDrawer in this pass.
- 2026-05-01: **PF-05 strategy revision** — Privacy + Terms live on `gamedrawer.lauterstar.com/{privacy,terms}.html` (custom domain), skipping the D-08 GitHub Pages stopgap. Settings ABOUT rows already point to those URLs via `AppInfo.privacyURL` / `AppInfo.termsURL` (committed in `d274f3f refactor(screens): SettingsView under §8.5 cap + GameDescriptor-driven Home`). PF-05 + SC2-E now block on a single deploy step (DNS go-live); ASC App Privacy URL field (PF-08) consumes the same URL. v1.0 ships with the production URL — no follow-up ASC edit needed once the website is live.
- 2026-05-01: **CLAUDE/AGENTS §1 wording reconciled** with iCloud-opt-in reality (Phase 06 SIWA + CloudKit). "Offline-only — no backend, no cloud, no accounts" → "Offline-first. Optional iCloud sync via Sign in with Apple. No third-party backend, no analytics SDKs, no required accounts." Closes the audit-flagged constitution drift; future sessions will not steer toward removing the SIWA + CloudKit feature.
- 2026-05-01: **Audit cleanup landed** — SettingsView 556 → 347 LOC (under §8.5 hard cap; About section + AppInfo + MailComposer extracted to `Screens/SettingsAboutSection.swift`). MinesweeperViewModel 472 → 393 LOC (Timer + Persistence + InteractionMode extensions, Foundation-only invariant preserved). Home routing now driven by `Core/GameDescriptor.swift` + `Core/GameRoute.swift` — adding game N is one descriptor entry + one route case + one switch arm. ** TEST SUCCEEDED ** post-refactor.
- 06.1-03: Padding reduced from theme.spacing.l (16pt) to theme.spacing.s (8pt) on Mines board horizontal — RESEARCH open question #1 option (a). Eliminates Easy/Medium clamping-at-floor regression on 390pt iPhones while preserving 1-token visual breath
- 06.1-03: .scaleEffect anchored to LazyVGrid (not ScrollView) — cosmetic-only zoom; ScrollView clipping stays stable for consistent scroll-bumper behavior during pinch
- 06.1-03: cellSize and clampZoomScale extracted as static MinesweeperBoardView funcs — pure-computation testable from gamekitTests without SwiftUI dependency; instance computed property delegates to static helper for single-source-of-truth
- 06.1-03: MagnifyGesture default minimumScaleDelta accepted (Plan §Pitfall 5 mentioned 0.05 as defensive lock); RESEARCH HIGH confidence on .simultaneousGesture parent/child decoupling means manual SC1 50-tap recipe is the empirical gate; bumped only if SC1 surfaces misfires
- 06.1-03: Source-comment self-discipline rule reapplied for the 4th time — rephrased GeometryReader and MagnificationGesture prohibition comments to keep negative-greps clean even where prose narrates the prohibition (precedents P4 04-01 / P6 06-06 / P6 06-07)
- 06.1-03: Four-commit shape (test/feat/feat/docs) honors TDD RED -> GREEN gate (project precedent across Plans 04-02/05-01/05-06/06-01/06-02 locked) AND CLAUDE.md §8.10 atomic-per-coherent-feature; each commit independently bisectable; supersedes plan §Success Criteria's single-commit suggestion
- 06.1-01: Sheet over NavigationLink push (CONTEXT Discretion #2) — preserves HomeView NavigationStack for Mines push and reads as 'directory of placeholder games' modal vs 'going somewhere new' navigation push
- 06.1-01: Single shared tileCard(symbol:iconColor:title:caption:) helper renders both Mines and Upcoming tiles with one .aspectRatio(1, contentMode: .fit) call site — satisfies plan acceptance OR clause without duplicating the modifier per tile
- 06.1-01: GameCard struct KEPT in HomeView.swift (per plan instruction) and consumed by UpcomingGamesView via module-level visibility — DesignKit promotion threshold (2+ games / 3+ call sites) not met
- 06.1-01: xcstringstool sync invocation requires --stringsdata pointing to compiler-generated .stringsdata under DerivedData (NOT --positional-arguments + .swift files); the -print0 | xargs -0 form is load-bearing because shell word-splitting of $(find ...) was being interpreted as a single argument
- 06.1-01: Source-comment self-discipline reapplied for the FIFTH time — UpcomingGamesView header rephrases 'modelContext' prohibition as 'SwiftData context-environment' to keep negative-greps clean (precedents P4 04-01 / P6 06-06 / P6 06-07 / P6.1 06-03)
- 06.1-01: Two-commit shape (feat for code + docs for REQUIREMENTS) over plan's suggested single feat commit — matches CLAUDE.md §8.10 'one feature OR one grouped batch per commit' and 06.1-03 four-commit precedent; both commits independently bisectable
- 06.1-02: TDD plan-level RED -> GREEN gate honored — test commit aa81374 (7 RED InteractionModeTests under @Suite("InteractionMode") with 'cannot find member' compile errors for interactionMode/handleTap/handleLongPress/toggleInteractionMode/modeToggleCount) precedes feat commit 9d824c8 in git log; same shape as Plans 04-02/05-01/05-06/06-01/06-02/06.1-03 all locked test-before-feat
- 06.1-02: MinesweeperInteractionMode enum is file-scope Foundation-only (Sendable, Equatable, Codable). VM extension adds interactionMode + modeToggleCount + toggleInteractionMode() + handleTap(at:) + handleLongPress(at:); restart() resets both interactionMode = .reveal AND modeToggleCount = 0. Foundation-only invariant preserved (single import Foundation; verified by structural test vmSourceFile_importsOnlyFoundation). VM line count 381 -> 461 (within plan's 400-450 explicit acceptance range; under <500 hard cap)
- 06.1-02: GameView FAB (64pt circular Button below board) — icon swap cursorarrow.click <-> flag.fill, tint swap theme.colors.accentPrimary <-> theme.colors.danger (non-error semantic for flag mode per CONTEXT Discretion #6, no new DesignKit token per D-19), .opacity(0) + .allowsHitTesting(false) hide post-terminal preserves layout (RESEARCH open question #2), .sensoryFeedback(.impact(weight: .light), trigger: settingsStore.hapticsEnabled ? viewModel.modeToggleCount : 0) gating-at-source pattern from Plan 05-06
- 06.1-02: CellView + BoardView UNTOUCHED — git diff HEAD~3..HEAD on both files returns 0 lines. LongPressGesture(minimumDuration: 0.25) + .exclusively(before: TapGesture()) + cell-level .sensoryFeedback(.selection / .impact(.light)) all byte-identical preservation. Mode-routing logic lives ENTIRELY in vm.handleTap / vm.handleLongPress (CLAUDE.md §1 lightweight MVVM, ARCHITECTURE Anti-Pattern 1). View tier passes vm.handleTap/handleLongPress closures down via GameView -> BoardView -> CellView with no internal mode awareness
- 06.1-02: Four-commit shape (test/feat/feat/docs) — aa81374 RED gate -> 9d824c8 VM GREEN -> 6b166f0 GameView FAB -> 7276556 docs+xcstrings. Same precedent as 06.1-03 four-commit shape. Plan §Success Criteria suggested single atomic commit; the body §Task 1 explicitly required RED -> GREEN gate making the four-commit shape the only correct interpretation. Each commit independently bisectable
- 06.1-02: Phase 6.1 final REQUIREMENTS.md state — Coverage 38/38 (final target REACHED). Wave 1 (06.1-03) shipped A11Y-05 (graduated A11Y-V2-02 -> v1); Wave 2 plans (06.1-01 SHELL-05, 06.1-02 MINES-12) added two new v1 IDs. Each plan's xcstrings + REQ edits disjoint by section (Accessibility / App Shell / Minesweeper); JSON merge clean across all three

### Pending Todos

- **P7 work queued**: Plans 07-02 (icon production), 07-03 (CloudKit Production schema deploy), 07-04 (App Store metadata + privacy policy + screenshots), 07-05 (release checklist + 07-VERIFICATION.md template), 07-06 (TestFlight upload + SC1-SC5 manual sweep + submit). See `.planning/phases/07-release/` for plan files.

### Blockers/Concerns

- *(no active blockers — Phase 7 ready to execute. Earlier P6 06-03 Task 3 checkpoint and 06-09 BLOCKING checkpoint were resolved via the manual UAT recorded in 06-UAT.md and the doc-drift sweep in this plan.)*

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-04-28T03:09:44.365Z
Stopped at: Completed 06.1-02 — Minesweeper Reveal/Flag interaction-mode toggle (MINES-12); manual recipes pending human execution; phase 06.1 final plan landed
Resume file: None

**Planned Phase:** 7 (release) — 6 plans — 2026-04-27T22:00:00.000Z
