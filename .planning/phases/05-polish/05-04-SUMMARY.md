---
phase: 05-polish
plan: 04
subsystem: settings-spine
tags: [settings, theme-picker, audio-toggles, voiceover, a11y, navigation, xcstrings, full-theme-picker]
dependency_graph:
  requires:
    - "SwiftUI (NavigationLink, ScrollView, DKCard, Toggle, Bindable)"
    - "DesignKit (DKThemePicker, DKCard, PresetCatalog.{core,all}, theme tokens)"
    - "Core/SettingsStore.swift (P5-01 baseline — hapticsEnabled / sfxEnabled flags consumed by AUDIO toggles)"
    - "Screens/SettingsComponents.swift (settingsSectionHeader + settingsNavRow helpers — used unchanged)"
    - "Screens/SettingsView.swift P4 DATA section (preserved BYTE-IDENTICAL per D-16)"
  provides:
    - "Screens/FullThemePickerView.swift — NavigationLink destination wrapping DKThemePicker(catalog: .all, grouped: true) for the full preset gallery + custom-color editor"
    - "Screens/AcknowledgmentsView.swift — NavigationLink destination from ABOUT row; 3 credit lines per UI-SPEC §Copywriting"
    - "Screens/SettingsView.swift APPEARANCE section — 5 Classic preset swatches inline + 'More themes & custom colors' NavigationLink"
    - "Screens/SettingsView.swift AUDIO section — 2 SettingsToggleRow rows bound to settingsStore.hapticsEnabled / .sfxEnabled"
    - "Screens/SettingsView.swift ABOUT section — Version (mono digits) / Privacy (inline disclosure) / Acknowledgments (NavigationLink)"
    - "File-private SettingsToggleRow struct — A11Y-02 compliant Toggle(label, isOn:) + .labelsHidden() pattern, locked for any future toggle row"
    - "Localizable.xcstrings — 11 new EN keys auto-extracted via xcstringstool sync"
  affects:
    - "Plan 05-05 — IntroFlowView Step 3 sign-in card path lands on SHELL-02 surface complete; intro dismissal continues to settle on the populated Settings spine"
    - "Plan 05-06 — Mines view animation pass reads settingsStore.hapticsEnabled / .sfxEnabled flags now editable from Settings AUDIO; THEME-03 custom-palette overrides editable from FullThemePickerView"
    - "Plan 05-07 — Theme matrix legibility audit covers the new APPEARANCE / AUDIO / ABOUT cards and the FullThemePickerView destination"
    - "Future games — Settings spine is now production-ready (no more P1 stubs); per-game additions plug into existing structure"
tech-stack:
  added: []  # no new frameworks; SwiftUI + DesignKit already present
  patterns:
    - "A11Y-02 lock (T-05-17): SettingsToggleRow uses Toggle(label, isOn:) + .labelsHidden() so VoiceOver reads 'Haptics, switch button, on/off' per UI-SPEC line 174-175. Empty-string Toggle label initializer NOT used anywhere — adversarial grep gate locks the contract"
    - "Bindable(settingsStore).{flag} — produces SwiftUI Bindings from @Observable @MainActor store; the canonical iOS 17+ pattern for binding @Observable properties to SwiftUI controls"
    - "P4 DATA section preservation (D-16): byte-identical diff verified via git show HEAD:... | sed -n '125,162p' vs current sed extraction; locked invariant for future plans"
    - "Privacy row inline disclosure: Button toggling @State isPrivacyExpanded inside withAnimation(.easeInOut(duration: theme.motion.fast)); lighter-weight than NavigationLink for one-sentence body copy per UI-SPEC option A"
    - "Version display defensive read: Bundle.main.infoDictionary['CFBundleShortVersionString'] / ['CFBundleVersion'] with '1.0' / '1' fallbacks per T-05-12 mitigation"
    - "AcknowledgmentsView extracted to sibling file per CLAUDE.md §8.1 — keeps SettingsView.swift under the ~400-line soft cap (final: 410 lines incl. expanded header doc, was at 425 with both inlined)"
    - "FullThemePickerView is NOT a NavigationStack owner — parent SettingsView.swift line 59 owns one (CLAUDE.md §0 / ARCHITECTURE Anti-Pattern 3)"
    - "xcstringstool sync against build-time .stringsdata — same workflow locked in P4 04-05; sync is deterministic and removes orphaned automatic entries while preserving manual ones"
key-files:
  created:
    - "gamekit/gamekit/Screens/FullThemePickerView.swift"
    - "gamekit/gamekit/Screens/AcknowledgmentsView.swift"
  modified:
    - "gamekit/gamekit/Screens/SettingsView.swift"
    - "gamekit/gamekit/Resources/Localizable.xcstrings"
decisions:
  - "05-04: SettingsToggleRow Toggle(label, isOn:) — NOT empty-string label initializer — locks A11Y-02 VoiceOver phrase 'Haptics/Sound effects, switch button, on/off' per UI-SPEC line 174-175 + threat T-05-17. .labelsHidden() suppresses the duplicate visible label since the leading Text(label) already shows it sighted-side."
  - "05-04: AcknowledgmentsView extracted to sibling file (Screens/AcknowledgmentsView.swift) instead of file-private inside SettingsView.swift — file-private inline kept SettingsView at 425 lines (over CLAUDE.md §8.1 ~400 soft cap); extraction brings SettingsView to 410 lines (acceptable; expanded header doc adds ~40 lines vs P4 baseline) and AcknowledgmentsView at 43 lines."
  - "05-04: FullThemePickerView uses grouped: true (categorized sections) for the full PresetCatalog.all (34 presets across 6 categories); APPEARANCE inline picker uses grouped: false (single 5-swatch row) for compact rendering. maxGridHeight: nil on both — full picker uses intrinsic height inside outer ScrollView; inline picker has only 5 swatches so no height cap needed."
  - "05-04: P4 DATA section preserved BYTE-IDENTICAL per CONTEXT D-16 — verified via diff of git show HEAD:... lines 125-162 against current SettingsView.swift lines 187-224; exit code 0."
  - "05-04: Privacy row uses inline-disclosure (UI-SPEC option A) NOT NavigationLink (option B) — body is one sentence (4 short phrases); NavigationLink for one sentence is overkill. withAnimation(.easeInOut(duration: theme.motion.fast)) provides the disclosure animation."
  - "05-04: Version row reads Bundle.main.infoDictionary['CFBundleShortVersionString'] + ['CFBundleVersion'] with defensive fallbacks ('1.0' / '1') per T-05-12 mitigation. Renders via theme.typography.monoNumber + .monospacedDigit() per UI-SPEC §Typography line 65."
  - "05-04: AUDIO toggle .tint(theme.colors.accentPrimary) — accent reservation site #5 per UI-SPEC §Color line 103. The system Toggle's on-state pill becomes accent-tinted, matching the rest of the accent surface across the audit set (instead of the system blue iOS Settings convention)."
  - "05-04: Localizable.xcstrings auto-sync via xcrun xcstringstool sync against DerivedData *.stringsdata files; catalog grew 663 → 699 lines (+36). 11 new EN keys: AUDIO, Haptics, Sound effects, More themes, More themes & custom colors, Version, Privacy, Acknowledgments, 'All data stored locally...' (privacy body), 'DesignKit · own work' / 'SF Symbols · Apple Inc.' / 'GameKit is built with care...' (3 acknowledgments lines)."
  - "05-04: Comment-line A11Y-02 documentation rephrased to avoid literal `Toggle(\"\", isOn:` substring — original wording would trip the negative-grep acceptance check; rephrased to 'empty-string label initializer' so the adversarial gate stays clean while preserving the documentation intent."
  - "05-04: Navigation graph for Plan 05/06 LOCKED: RootTabView → SettingsView (NavigationStack owner) → FullThemePickerView (NavigationLink) AND RootTabView → SettingsView → AcknowledgmentsView (NavigationLink). Both destinations DO NOT own their own NavigationStack."
metrics:
  duration_minutes: 12
  completed_date: 2026-04-27
  total_lines_added: 270
  files_created: 2
  files_modified: 2
  tests_added: 0
  tests_passing: "all gamekitTests still green (regression check)"
---

# Phase 5 Plan 04: Settings Spine Rebuild + FullThemePickerView Summary

Wave 2 of P5 ships the SHELL-02 surface complete: the rebuilt Settings spine (APPEARANCE / AUDIO / DATA / ABOUT in that exact order) replaces the P1 APPEARANCE + ABOUT stubs and adds the new AUDIO section between APPEARANCE and DATA, with the P4 DATA section preserved byte-identical per D-16. The new `FullThemePickerView` NavigationLink destination ships the THEME-03 entry point (DesignKit's built-in custom-color UI inside `DKThemePicker(catalog: .all, grouped: true)`). Settings AUDIO toggles wire the Wave-1 SettingsStore flags (hapticsEnabled / sfxEnabled) to user-facing controls, with the A11Y-02 VoiceOver phrase locked at the source via `Toggle(label, isOn:)` + `.labelsHidden()`.

## Files

| File | Type | Lines | Purpose |
| ---- | ---- | -----:| ------- |
| `gamekit/gamekit/Screens/FullThemePickerView.swift` | NEW | 38 | NavigationLink destination wrapping `DKThemePicker(catalog: .all, grouped: true)` inside a themed `ScrollView`; no NavigationStack ownership (parent Settings owns one) |
| `gamekit/gamekit/Screens/AcknowledgmentsView.swift` | NEW | 43 | NavigationLink destination from ABOUT; 3 credit lines (DesignKit / SF Symbols / no-telemetry one-liner) per UI-SPEC §Copywriting |
| `gamekit/gamekit/Screens/SettingsView.swift` | EDIT | 410 (was 239) | APPEARANCE rebuilt with 5-swatch DKThemePicker + NavigationLink; new AUDIO section; ABOUT rebuilt with Version / Privacy (inline disclosure) / Acknowledgments NavigationLink; SettingsToggleRow file-private struct added; DATA section preserved byte-identical |
| `gamekit/gamekit/Resources/Localizable.xcstrings` | EDIT | 699 (was 663) | +36 lines / 11 new EN keys auto-extracted via `xcrun xcstringstool sync` against build-time `.stringsdata` files |

**Total:** 270 net lines added (+250 across SettingsView/Resources, +81 in 2 new files, -20 P1 stub copy removed).

## Build & Test

- `xcodebuild build -scheme gamekit -destination 'generic/platform=iOS Simulator'` → **BUILD SUCCEEDED**
- `xcodebuild test -scheme gamekit -destination '...iPhone SE (2nd generation),OS=18.5' -only-testing:gamekitTests` → **TEST SUCCEEDED**
- All Plan 05-01 SettingsStoreFlagsTests still green (AUDIO toggle bindings round-trip through the same SettingsStore surface)
- All P3 + P4 ViewModel + GameStats + StatsExporter test suites still green

## Section Order Proof

Extracted from `SettingsView.body` VStack at lines 77-80:

```
77:                    appearanceSection
78:                    audioSection
79:                    dataSection
80:                    aboutSection
```

Section order matches CONTEXT D-13 exactly: **APPEARANCE → AUDIO → DATA → ABOUT**.

## P4 DATA Section Byte-Identity Proof

```bash
git show HEAD:gamekit/gamekit/Screens/SettingsView.swift | sed -n '125,162p' > /tmp/data_orig.txt
sed -n '187,224p' gamekit/gamekit/Screens/SettingsView.swift > /tmp/data_new.txt
diff /tmp/data_orig.txt /tmp/data_new.txt
echo "exit=$?"
```

Result: **exit=0** (no diff). DATA section preserved byte-identical per CONTEXT D-16.

## A11Y-02 Lock Proof (UI-SPEC line 174-175 + threat T-05-17)

```bash
grep -F 'Toggle(label, isOn: $isOn)' gamekit/gamekit/Screens/SettingsView.swift | wc -l
# → 2  (one in code at line 386, one in doc-comment at line 376)

grep -F 'Toggle("", isOn:' gamekit/gamekit/Screens/SettingsView.swift | wc -l
# → 0  (neither code nor comments contain the empty-string anti-pattern)
```

Both AUDIO toggles VoiceOver-read as **"Haptics, switch button, on/off"** and **"Sound effects, switch button, on/off"** per UI-SPEC line 174-175. The `.labelsHidden()` modifier hides the duplicate visible label (since the leading `Text(label)` already shows it sighted-side); only the a11y string differs from the empty-string variant.

## Localizable.xcstrings New Keys (11)

Synced via `xcrun xcstringstool sync gamekit/gamekit/Resources/Localizable.xcstrings --stringsdata $DERIVED_DATA/.../arm64/*.stringsdata`. Catalog grew from 663 → 699 lines (+36).

| Key | Source |
| --- | ------ |
| `AUDIO` | SettingsView.swift `audioSection` header |
| `Haptics` | SettingsToggleRow label |
| `Sound effects` | SettingsToggleRow label |
| `More themes & custom colors` | APPEARANCE NavigationLink row title |
| `More themes` | FullThemePickerView navigationTitle |
| `Version` | ABOUT Version row label |
| `Privacy` | ABOUT Privacy row label |
| `Acknowledgments` | ABOUT Acknowledgments row label + AcknowledgmentsView navigationTitle |
| `All data stored locally. CloudKit sync optional. No analytics. No tracking.` | Privacy inline-disclosure body |
| `DesignKit · own work` | AcknowledgmentsView credit line 1 |
| `SF Symbols · Apple Inc.` | AcknowledgmentsView credit line 2 |
| `GameKit is built with care, by hand, with no telemetry, no ads, and no third-party dependencies beyond the above.` | AcknowledgmentsView credit line 3 |

(`Version` strings themselves are not localized — version numbers are language-neutral per UI-SPEC §Copywriting line 192.)

## FOUND-07 Hook Compliance (token discipline)

```bash
grep -E "Color\(|cornerRadius:" gamekit/gamekit/Screens/SettingsView.swift
# → only matches in comment text ("zero Color(...) literals" — not actual code)

grep -E "padding\(\s*[0-9]+(\.[0-9]+)?\s*\)" gamekit/gamekit/Screens/SettingsView.swift
# → 0 matches (no integer-literal padding)

grep -E "Color\(|cornerRadius:|padding\(\s*[0-9]" gamekit/gamekit/Screens/FullThemePickerView.swift gamekit/gamekit/Screens/AcknowledgmentsView.swift
# → 0 matches
```

All three files pass the FOUND-07 pre-commit hook unconditionally — every padding reads `theme.spacing.{token}`, every color reads `theme.colors.{token}`, no `cornerRadius:` literals.

## Navigation Graph Lock for Plan 05 / 06

```
RootTabView (P1)
  └─ SettingsView (NavigationStack owner — P4 line 59)
       ├─ FullThemePickerView (NavigationLink, NEW — destination from APPEARANCE)
       └─ AcknowledgmentsView (NavigationLink, NEW — destination from ABOUT)
```

Both destinations DO NOT own their own NavigationStack (per CLAUDE.md / ARCHITECTURE Anti-Pattern 3). Plan 05-05 IntroFlowView lands as a `.fullScreenCover` from `RootTabView` and is OUTSIDE this nav graph (cover, not push).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 / scope clarification] Comment-line A11Y-02 docs rephrased**
- **Found during:** Task 2 verification — running `grep -F 'Toggle("", isOn:' SettingsView.swift` returned 2 matches when acceptance criterion required 0.
- **Issue:** The file-header doc and the SettingsToggleRow doc-comment originally explained the A11Y-02 anti-pattern by quoting the exact literal `Toggle("", isOn:` — which tripped the adversarial negative-grep gate even though the actual production code never used the anti-pattern.
- **Fix:** Rephrased both doc-comments from the literal `Toggle("", isOn:)` to the prose form 'empty-string label initializer'. Documentation intent preserved; adversarial grep stays clean (0 matches now).
- **Files modified:** gamekit/gamekit/Screens/SettingsView.swift (2 doc comments)
- **Commit:** `038072b` (Task 2)

**2. [Rule 3 / planner-anticipated fallback] AcknowledgmentsView extracted to sibling file**
- **Found during:** Task 2 line-count check — initial inlined SettingsView.swift was 425 lines after the doc-header expansion + 3 new sections + 2 file-private structs.
- **Issue:** CLAUDE.md §8.1 sets a ~400-line soft cap for view files; 425 is over.
- **Fix:** Extracted `AcknowledgmentsView` to a sibling file `gamekit/gamekit/Screens/AcknowledgmentsView.swift` per the planner's anticipated fallback (Plan §STEP 9 + UI-SPEC §Component Inventory line 232). Final SettingsView.swift = 410 lines (acceptable; expanded P5 doc-header adds ~40 lines vs P4's 239-line baseline). AcknowledgmentsView.swift = 43 lines.
- **Files modified:** gamekit/gamekit/Screens/SettingsView.swift; gamekit/gamekit/Screens/AcknowledgmentsView.swift (new)
- **Commit:** `038072b` (Task 2)

No other deviations. Both Tasks executed exactly as written.

## Authentication Gates

None — this plan is a pure UI rebuild with no auth surface.

## Self-Check: PASSED

- [x] `gamekit/gamekit/Screens/FullThemePickerView.swift` exists (38 lines)
- [x] `gamekit/gamekit/Screens/AcknowledgmentsView.swift` exists (43 lines)
- [x] `gamekit/gamekit/Screens/SettingsView.swift` exists (410 lines)
- [x] `gamekit/gamekit/Resources/Localizable.xcstrings` exists (699 lines, +36)
- [x] Commit `659e4fe` exists (`feat(05-04): add FullThemePickerView NavigationLink destination`)
- [x] Commit `038072b` exists (`feat(05-04): rebuild Settings spine APPEARANCE/AUDIO/ABOUT (P4 DATA verbatim)`)
- [x] Build succeeds: `xcodebuild build -scheme gamekit` → BUILD SUCCEEDED
- [x] Tests pass: `xcodebuild test -scheme gamekit -only-testing:gamekitTests` → TEST SUCCEEDED
- [x] Section order: APPEARANCE → AUDIO → DATA → ABOUT (verified by grep at lines 77-80)
- [x] P4 DATA section byte-identical (verified by `diff` exit=0)
- [x] A11Y-02 lock: `Toggle(label, isOn: $isOn)` matches; `Toggle("", isOn:` zero matches
- [x] FOUND-07 token discipline: zero `Color(...)` / `cornerRadius:` / `padding(<int>)` in any P5 file
- [x] All 11 new EN xcstrings keys present
