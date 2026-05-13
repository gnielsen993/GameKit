---
phase: 09
slug: video-mode-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-12
---

# Phase 09 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> See 09-RESEARCH.md §"Validation Architecture" for the full test surface map and 8-dimension coverage rationale.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test` macros) + XCTest host (existing v1.0 setup) |
| **Config file** | `gamekit/gamekit.xcodeproj` (gamekitTests target) — no new config |
| **Quick run command** | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:gamekitTests/VideoModeStoreTests` |
| **Full suite command** | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'` |
| **Estimated runtime** | quick ~12s · full ~90s |

---

## Sampling Rate

- **After every task commit:** Run quick command (VideoModeStoreTests only)
- **After every plan wave:** Run full suite (regression check vs v1.0 + v1.1)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~12s for quick, ~90s for full

---

## Per-Task Verification Map

> Authoritative test surface for Phase 9. Each task in `09-NN-PLAN.md` must point to a row here for its `<automated>` verify (or declare Wave 0 dependency).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 09-01-01 | VideoModeStore impl | 1 | VIDEO-01, VIDEO-03 | — | UserDefaults round-trip survives store reconstruction | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeStoreTests/test_isEnabled_persists` | ❌ W0 | ⬜ pending |
| 09-01-02 | VideoModeStore impl | 1 | VIDEO-01 | — | Default isEnabled is `false` for unset key | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeStoreTests/test_isEnabled_defaults_to_false` | ❌ W0 | ⬜ pending |
| 09-01-03 | VideoModeStore impl | 1 | VIDEO-02, VIDEO-03 | — | location round-trips through UserDefaults (all 6 cases) | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeStoreTests/test_location_persists_all_cases` | ❌ W0 | ⬜ pending |
| 09-01-04 | VideoModeStore impl | 1 | VIDEO-02 | — | Default location is `.largeBottom` (D-03) | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeStoreTests/test_location_default_is_largeBottom` | ❌ W0 | ⬜ pending |
| 09-01-05 | VideoModeStore impl | 1 | VIDEO-02 | — | `VideoModeLocation` enum is exhaustive (6 cases via CaseIterable) | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeStoreTests/test_location_enum_has_6_cases` | ❌ W0 | ⬜ pending |
| 09-02-01 | EnvironmentKey wiring | 2 | VIDEO-03 | — | `@Environment(\.videoModeStore)` returns injected store, not default | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeEnvironmentTests/test_environmentKey_returns_injected` | ❌ W0 | ⬜ pending |
| 09-02-02 | GameKitApp injection | 2 | VIDEO-03 | — | `GameKitApp.init` constructs store + injects via environment | unit | `xcodebuild test ... -only-testing:gamekitTests/GameKitAppTests/test_videoModeStore_injected_at_app_root` | ❌ W0 | ⬜ pending |
| 09-03-01 | Settings card | 3 | VIDEO-01 | — | Toggle is wired to `videoModeStore.isEnabled` (round-trip via Toggle binding) | unit | `xcodebuild test ... -only-testing:gamekitTests/SettingsViewTests/test_videoMode_toggle_binds_to_store` | ❌ W0 | ⬜ pending |
| 09-03-02 | Settings card | 3 | VIDEO-01 | — | "Video location: <label>" row appears ONLY when isEnabled is true | unit (snapshot or condition test) | `xcodebuild test ... -only-testing:gamekitTests/SettingsViewTests/test_locationRow_visibility_follows_isEnabled` | ❌ W0 | ⬜ pending |
| 09-04-01 | Picker sub-screen | 3 | VIDEO-02 | — | Tapping each of 6 zones updates `videoModeStore.location` to corresponding enum case | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoLocationPickerViewTests/test_zone_tap_updates_location` | ❌ W0 | ⬜ pending |
| 09-04-02 | Picker sub-screen | 3 | VIDEO-02 | — | A11y label for each zone matches design vocabulary ("Large top", "Small bottom-left", etc.) | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoLocationPickerViewTests/test_zone_a11y_labels` | ❌ W0 | ⬜ pending |
| 09-05-01 | Manual-selection copy | 3 | VIDEO-14 | — | xcstrings key `videoMode.manualSelectionExplanation` exists with non-empty value | unit | `xcodebuild test ... -only-testing:gamekitTests/LocalizableCatalogTests/test_videoMode_copy_keys_exist` | ❌ W0 | ⬜ pending |
| 09-06-01 | Compact row component | 2 | VIDEO-04 | — | `VideoCompactControlRow` compiles in main target (smoke) | smoke (build) | `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'` | ✅ in W0 | ⬜ pending |
| 09-06-02 | Compact row #Preview stub | 2 | VIDEO-04 | — | `#Preview` block renders the 3 game slot mappings (Mines/Merge/Nonogram) without crash | manual (Xcode Preview canvas) | n/a — manual sign-off | ✅ in W0 | ⬜ pending |
| 09-07-01 | SC5 byte-identical Off | 4 | (SC5) | — | With `isEnabled = false` injected, Mines/Merge/Nonogram views produce no diff vs pre-v1.2 snapshot | regression (snapshot) | `xcodebuild test ... -only-testing:gamekitTests/SC5RegressionTests/test_off_state_byte_identical` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Validation dimensions covered (per 09-RESEARCH §Validation Architecture):**
- **D1 Functional correctness:** unit tests for all VIDEO-01..04 + VIDEO-14 round-trips
- **D2 Boundary conditions:** all 6 `VideoModeLocation` cases tested individually (09-01-03)
- **D3 Error / invalid state:** unset UserDefaults key → default value (09-01-02, 09-01-04)
- **D4 Concurrency / lifecycle:** `@MainActor` enforcement compile-checked (no separate runtime test)
- **D5 Integration / wiring:** environment injection round-trip (09-02-01, 09-02-02)
- **D6 UI behavior:** Settings card binding + picker zone tap + a11y labels (09-03, 09-04)
- **D7 Localization / a11y:** xcstrings key existence (09-05-01) + a11y label coverage (09-04-02)
- **D8 Regression / SC5:** Off-state byte-identical against v1.0 + v1.1 baseline (09-07-01)

---

## Wave 0 Requirements

- [ ] `gamekit/gamekitTests/Core/VideoModeStoreTests.swift` — stub w/ 5 tests for VIDEO-01..03
- [ ] `gamekit/gamekitTests/Core/VideoModeEnvironmentTests.swift` — stub w/ 1 test for VIDEO-03 environment wiring
- [ ] `gamekit/gamekitTests/App/GameKitAppTests.swift` — stub w/ 1 test for store injection at app root
- [ ] `gamekit/gamekitTests/Screens/SettingsViewTests.swift` — stub w/ 2 tests for VIDEO-01 binding + conditional row
- [ ] `gamekit/gamekitTests/Screens/VideoLocationPickerViewTests.swift` — stub w/ 2 tests for VIDEO-02 zone tap + a11y
- [ ] `gamekit/gamekitTests/Resources/LocalizableCatalogTests.swift` — stub w/ 1 test for VIDEO-14 copy key
- [ ] `gamekit/gamekitTests/Regression/SC5RegressionTests.swift` — stub w/ 1 snapshot test for SC5 off-state baseline
- [ ] No new framework install — existing Swift Testing + XCTest infrastructure from v1.0 (Phase 2) covers all

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `#Preview` canvas renders 3 game slot mappings correctly | VIDEO-04 | Xcode Preview canvas state can't be asserted from CLI test runner | Open `VideoCompactControlRow.swift` in Xcode → check the `#Preview` canvas shows Mines / Merge / Nonogram variants side by side, each readable on Classic + Dracula presets |
| VIDEO-14 manual-selection copy is locale-readable + non-jargon | VIDEO-14 | Copy quality is a human judgment; xcstrings catalog only verifies existence | Open Settings → Video Mode → On → "Video location: Large bottom" → sub-screen → read the explanation paragraph aloud; confirm it parses without thinking |
| iPhone-outline picker is visually legible on Classic + Dracula (§8.12) | VIDEO-02 | Theme audit requires human visual review | Toggle Video Mode On → open picker → flip preset to Dracula via Settings → return to picker → confirm 6 zones + selected-zone fill + "Your video will go here" label all readable |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (7 new test files; existing framework reused)
- [ ] No watch-mode flags
- [ ] Feedback latency: 12s quick / 90s full < project standard
- [ ] `nyquist_compliant: true` set in frontmatter (after Wave 0 lands)

**Approval:** pending
