---
phase: 4
slug: stats-persistence
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-25
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `04-RESEARCH.md` § Validation Architecture (lines 1292–1357).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test` / `#expect`), bundled with Xcode 16 — for `gamekitTests`. |
| **Config file** | None separate — `gamekitTests` target already exists (validated P1+P2+P3). |
| **Quick run command** | `xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,id=51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E' -only-testing:gamekitTests/Core` |
| **Full suite command** | `xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,id=51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E'` |
| **Estimated runtime** | ~4s quick (Core suite alone), ~35s full (gamekit + DesignKitTests) |

---

## Sampling Rate

- **After every task commit:** Quick run command (~4s).
- **After every plan wave:** Full suite command (~35s).
- **Before `/gsd-verify-work`:** Full suite green AND manual force-quit / crash / device-reboot tests + 6-preset theme audit screenshots in `04-VERIFICATION.md`.
- **Max feedback latency:** 35 seconds.

---

## Per-Requirement Verification Map

| Requirement | Behavior | Test Type | Automated Command | File Exists |
|---|---|---|---|---|
| PERSIST-01 / SC3 | Both `.none` and `.private("iCloud...")` configs construct | unit | `… -only-testing:gamekitTests/Core/ModelContainerSmokeTests` | ❌ Wave 0 |
| PERSIST-01 / SC3 | Schema is exactly `[GameRecord, BestTime]` | unit | `… -only-testing:gamekitTests/Core/ModelContainerSmokeTests/schemaIsLocked` | ❌ Wave 0 |
| PERSIST-02 / SC1 | `record(.win)` inserts both + saves | unit | `… -only-testing:gamekitTests/Core/GameStatsTests/recordWin` | ❌ Wave 0 |
| PERSIST-02 / SC1 | `record(.loss)` inserts only GameRecord | unit | `… -only-testing:gamekitTests/Core/GameStatsTests/recordLoss` | ❌ Wave 0 |
| PERSIST-02 / SC1 | Faster win replaces existing BestTime; slower does not | unit | `… -only-testing:gamekitTests/Core/GameStatsTests/bestTimeOnlyOnFaster` | ❌ Wave 0 |
| PERSIST-02 / SC1 | `resetAll()` deletes both atomically | unit | `… -only-testing:gamekitTests/Core/GameStatsTests/resetAllAtomic` | ❌ Wave 0 |
| PERSIST-02 | VM does NOT `import SwiftData` | structural grep | pre-commit hook | ✅ existing |
| PERSIST-03 / SC4 | 50-game round-trip is byte-for-byte identical | unit | `… -only-testing:gamekitTests/Core/StatsExporterTests/roundTripFifty` | ❌ Wave 0 |
| PERSIST-03 / SC4 | Schema-version mismatch throws | unit | `… -only-testing:gamekitTests/Core/StatsExporterTests/schemaVersionMismatchThrows` | ❌ Wave 0 |
| PERSIST-03 / SC4 | Replace-on-import wipes pre-existing | unit | `… -only-testing:gamekitTests/Core/StatsExporterTests/replaceOnImport` | ❌ Wave 0 |
| PERSIST-03 / SC4 | Encoder deterministic (sortedKeys + iso8601 + prettyPrinted) | unit | `… -only-testing:gamekitTests/Core/StatsExporterTests/encoderDeterministic` | ❌ Wave 0 |
| PERSIST-03 | JSON keys = Swift property names per D-18 | unit | `… -only-testing:gamekitTests/Core/StatsExporterTests/envelopeKeysMatchSwiftProperties` | ❌ Wave 0 |
| SHELL-03 | Win % formula = `Int(round(wins * 100 / games))`; "—" when games == 0 | unit | `… -only-testing:gamekitTests/Core/StatsAggregationTests/winPctRounding` | ❌ Wave 0 (optional) |
| FOUND-07 | Zero `Color(...)` literals in `Screens/StatsView.swift` + `Screens/SettingsView.swift` | smoke | `.githooks/pre-commit` | ✅ existing |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `gamekit/gamekitTests/Helpers/InMemoryStatsContainer.swift` — `@MainActor enum` helper exposing `make(cloudKit:)` for test container construction
- [ ] `gamekit/gamekitTests/Core/GameStatsTests.swift` — PERSIST-01 + PERSIST-02 happy paths + atomicity (~8 tests)
- [ ] `gamekit/gamekitTests/Core/StatsExporterTests.swift` — PERSIST-03 + SC4 round-trip + schemaVersion mismatch + replace-on-import (~6 tests)
- [ ] `gamekit/gamekitTests/Core/ModelContainerSmokeTests.swift` — SC3 dual-config construction (~3 tests)
- [ ] (Optional) `gamekit/gamekitTests/Core/StatsAggregationTests.swift` — pure-Swift win% / best-time formatting (~3 tests; only if planner extracts pure helpers from StatsView)

*Framework: Swift Testing bundled with Xcode 16 — no install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Force-quit survival | PERSIST-02 / SC5 | Real iOS process termination ≠ simulator quit | Win a Hard game → swipe-up + swipe-up app card → relaunch → verify StatsView row present |
| Crash survival | PERSIST-02 / SC5 | Real crash ≠ controlled exit | Temporary crash-after-win toggle → trigger → relaunch → verify record present. Remove toggle before phase end. |
| Device-reboot survival | PERSIST-02 / SC5 | OS-level state flush only happens on real reboot | Win a Hard game → reboot device → relaunch → verify record present |
| 6-preset legibility (StatsView populated) | THEME-01 / CLAUDE.md §8.12 | Visual judgment across forest / bubblegum / barbie / cream / dracula / voltage | Capture screenshot per preset → `04-VERIFICATION.md` |
| 6-preset legibility (SettingsView DATA section) | THEME-01 / CLAUDE.md §8.12 | Same | Same |
| Reset alert reads cleanly under all 6 presets | UI-SPEC §Color | System alert chrome but trigger row must be unambiguous | Screenshot Reset alert active per preset |
| `fileExporter` real-device round-trip | PERSIST-03 / SC4 | `.fileImporter` security-scoped resource handling differs sim vs device | On physical iPhone: Export to Files → Reset → Import same file → verify counts + best times match |
| Schema-mismatch import alert | D-21 | Manual JSON edit + import path | Hand-edit a known export to `schemaVersion: 2` → import → verify alert copy matches D-21 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (4 required + 1 optional)
- [ ] No watch-mode flags
- [ ] Feedback latency < 35s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
