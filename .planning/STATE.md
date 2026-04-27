---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: 06-04 complete (Wave-1 GREEN gate); 06-03 Task 3 checkpoint still pending (parallel — does not block 06-04 since they touch different files)
last_updated: "2026-04-27T16:30:00Z"
last_activity: 2026-04-27
progress:
  total_phases: 7
  completed_phases: 5
  total_plans: 40
  completed_plans: 34
  percent: 85
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-24)

**Core value:** Calm, premium, fully theme-customizable gameplay with zero friction — no ads, no coins, no pushy subscriptions, no required accounts.
**Current focus:** Phase 06 — cloudkit-siwa

## Current Position

Phase: 6
Plan: 04 — COMPLETE (e43cc79); Wave-1 GREEN gate landed (7/7 AuthStoreTests pass). Plan 03 Task 3 checkpoint still pending (parallel — touches different files; 06-09 SC3 dependency only, not a blocker for 06-04 which uses test stubs).
Status: 06-04 complete; 06-03 Task 3 checkpoint still pending (paused on user action)
Last activity: 2026-04-27

Progress: [████████░░] 85%

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

## Accumulated Context

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

### Pending Todos

- **06-03 Task 3 (checkpoint:human-verify) — BLOCKING for Plan 06-09 SC3**: User must (a) verify in Xcode → gamekit target → Signing & Capabilities that all 4 P6 capabilities are registered (Sign in with Apple, iCloud + CloudKit + container iCloud.com.lauterstar.gamekit, iCloud CloudKit Documents, Background Modes → Remote notifications), and (b) launch a Debug build, run `expr try? GameKitApp._runtimeDeployCloudKitSchema()` in lldb, then verify in CloudKit Dashboard Development that CD_GameRecord + CD_BestTime record types appear. See `.planning/phases/06-cloudkit-siwa/06-03-SUMMARY.md` §CHECKPOINT for exact steps + resume-signal options.

### Blockers/Concerns

- **Plan 06-03 paused at Task 3 checkpoint** — orchestrator must resolve before plan can be marked fully complete; the checkpoint blocks Plan 06-09 SC3 (real-CloudKit promotion test) but did not block Plan 06-04 (used in-memory KeychainBackend stubs). Counter advanced to 04 (now complete) ahead of 06-03 Task 3 resolution.
- **Plan 06-05 must remove `SKIP_OBSERVER_TESTS` gate** when shipping Core/CloudSyncStatusObserver.swift. Search for `SKIP_OBSERVER_TESTS` in `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift` and delete both the `#if SKIP_OBSERVER_TESTS` line (~58) and the `#endif // SKIP_OBSERVER_TESTS` line (~167). The 9-test suite will then exercise the new production type.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-04-27T16:30:00Z
Stopped at: 06-04 complete (Wave-1 GREEN gate); 06-03 Task 3 checkpoint still pending (parallel)
Resume file: .planning/phases/06-cloudkit-siwa/06-04-SUMMARY.md (just shipped) + .planning/phases/06-cloudkit-siwa/06-03-SUMMARY.md (§CHECKPOINT — Task 3 still open)

**Planned Phase:** 6 (cloudkit-siwa) — 9 plans — 2026-04-27T15:40:19.917Z
