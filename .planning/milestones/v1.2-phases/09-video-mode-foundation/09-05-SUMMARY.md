---
phase: 09-video-mode-foundation
plan: 05
subsystem: shared-components
tags: [video-mode, shared-component, viewbuilder, design-tokens, wave-2, sc4]

# Dependency graph
requires:
  - phase: 09-video-mode-foundation
    provides: 09-02 VideoModeStore + VideoModeLocation (consumer ergonomics — Phase 11/12 will read the store inside the closures passed to this row)
  - phase: 08-video-mode-design
    provides: 08-COMPACT-ROW-TOKENS.md (D-13 token anchors — pill radius button, pill height xl, gap s, chip radius chip, chip height l) + 08 D-08 per-game slot mapping
provides:
  - VideoCompactControlRow<Primary: View, Picker: View, Secondary: View> — generic @ViewBuilder shared compact control row in slot order Back | primary info | picker | secondary info | settings (internal access, gamekit target only)
  - SC4 ("at least one stub call site compiles") inherent satisfaction via single #Preview rendering all 3 game slot mappings (Minesweeper / Merge / Nonogram) — no DEBUG-only standalone screen, no HomeView dev hook (D-04 lock)
  - The contract Phase 11 (Minesweeper adoption) and Phase 12 (Merge + Nonogram adoption) build against: each game wraps its existing board in `VStack { VideoCompactControlRow(...) { … }; existingGameBoard }` with zero changes to this file
affects: [09-06-PLAN, 09-07-PLAN, 09-08-PLAN, 11-*, 12-*]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Generic @ViewBuilder slot pattern (09-RESEARCH Topic 1 verdict) — type parameters `<Primary: View, Picker: View, Secondary: View>` + three `@ViewBuilder let ...: () -> View` closure slots, mirroring DKCard<Content: View>. No AnyView, no @Environment slot injection (rejected as anti-patterns in 09-RESEARCH §Topic 1)."
    - "Token-pure layout (09-PATTERNS §3 reminder; Phase 8 D-13 lock) — every dimension reads a DesignKit token via the passed-in `theme: Theme` parameter. Zero literal `cornerRadius:` ints, zero `padding(N)` ints in the file. `Core/` is exempt from the pre-commit hook (CLAUDE.md §8 — hook targets Games/ + Screens/) but token discipline carries."
    - "Embedded slot-mapping #Preview as SC4 stub call site (D-04 lock) — one `#Preview { … }` block at the bottom of the component file renders Mines / Merge / Nonogram in their locked slot orders. Avoids the trail-leaving cost of a DEBUG-only standalone screen or HomeView dev preview hook that Phase 11/12 would have to clean up."
    - "Preview-only private helpers (`PreviewChip`, `PreviewPicker`) scoped to the same file — keeps the SC4 preview self-contained, scopes the helpers out of the rest of the target, and avoids creating throwaway sibling files."

key-files:
  created:
    - gamekit/gamekit/Core/VideoCompactControlRow.swift
  modified:
    - Docs/releases/v1.1.md

key-decisions:
  - "Generic @ViewBuilder over AnyView struct or @Environment slot injection — 09-RESEARCH §Topic 1 explicitly rejected both alternatives (AnyView erases type info / breaks SwiftUI diffing; environment injection forces consumers into binding gymnastics and obscures the slot contract at the call site). Generic @ViewBuilder is the same shape as DKCard<Content: View> and reads naturally at the consumer's `} primaryInfo: { … } picker: { … }` call site."
  - "Internal access (not public DesignKit promotion) — CLAUDE.md §2 'promote to DesignKit only when proven (used in 2+ games)'. This component is brand-new and unused; Phase 11 will be its first real consumer, Phase 12 the second. Re-evaluate promotion after Phase 12 lands."
  - "Theme constructed via `Theme.resolve(preset:scheme:)` in the #Preview — the canonical DesignKit resolver, used at runtime by SettingsView. The plan body called the exact preview-theme accessor 'Claude's Discretion' and noted `Theme.classicMutedLight` may not exist as a direct accessor; `Theme.resolve(preset: .classicMuted, scheme: .light)` is the in-repo precedent that works end-to-end. Verified via `xcodebuild build` → BUILD SUCCEEDED."
  - "Settings button glyph: `gearshape` (not `gear`) — matches the existing SettingsView entry point convention across the codebase."
  - "Picker pill background: `theme.colors.accentPrimary.opacity(0.15)` in the preview — illustrative-only (the real picker each game ships will use its own surface). The body of `VideoCompactControlRow` itself does not assert a picker pill background; that's the consumer's call. This keeps the shared component shape-agnostic about picker visual treatment beyond the height/radius tokens."

patterns-established:
  - "Pattern: shared SwiftUI components with generic @ViewBuilder slots live in `gamekit/Core/` (not DesignKit) until proven across 2+ games. File header doc-comment names the locked invariants (slot order, token anchors, SC4 satisfaction mechanism) so a future maintainer sees what's load-bearing without re-deriving from plan docs."
  - "Pattern: SC4-style 'at least one stub call site compiles' criteria are satisfied by a single multi-mapping #Preview block in the component file itself, not by a separate DEBUG screen. Avoids the cleanup tax Phase 11/12 would otherwise pay."

requirements-completed: [VIDEO-04]

# Metrics
duration: 8min
completed: 2026-05-12
---

# Phase 09 Plan 05: VideoCompactControlRow Shared Component Summary

**Shipped `VideoCompactControlRow<Primary, Picker, Secondary>` — the generic @ViewBuilder shared compact control row every Phase 11/12 Video Mode game adoption will wrap around its existing board. Slot order, token anchors, and SC4 stub-call-site mechanism all locked to Phase 8 D-13 / D-04 specs.**

## Performance

- **Duration:** ~8 min (resumed from partial-file state — partial was complete and correct; only build verification, release-log append, and commit/summary work remained)
- **Started:** prior-session partial draft (~155-line file already in working tree)
- **Resumed / completed:** 2026-05-12
- **Tasks:** 1 / 1 completed
- **Files created:** 1 (`gamekit/gamekit/Core/VideoCompactControlRow.swift`)
- **Files modified:** 1 (`Docs/releases/v1.1.md` — release-log bullet per §0.3 / §8.14)

## Accomplishments

- Generic SwiftUI component shipped with the locked signature:

  ```swift
  struct VideoCompactControlRow<Primary: View, Picker: View, Secondary: View>: View {
      let theme: Theme
      let onBack: () -> Void
      let onSettings: () -> Void
      @ViewBuilder let primaryInfo: () -> Primary
      @ViewBuilder let picker: () -> Picker
      @ViewBuilder let secondaryInfo: () -> Secondary
      // body: HStack(spacing: theme.spacing.s) { backButton; primaryInfo(); picker(); secondaryInfo(); settingsButton }.frame(height: theme.spacing.xl)
  }
  ```

- **Slot order locked verbatim to Phase 8 D-13:** `Back | primary info | picker | secondary info | settings`.
- **All dimensions read DesignKit tokens** (verified by grep — every `cornerRadius:` and frame height/width references a `theme.*` path):

  | Anchor | Token | Source |
  |---|---|---|
  | Back/Settings icon button radius | `theme.radii.button` | Phase 8 D-13 |
  | Back/Settings icon button frame | `theme.spacing.xl` × `theme.spacing.xl` | D-13 pill-height anchor |
  | Inter-item HStack spacing | `theme.spacing.s` | D-13 gap |
  | Row overall height | `theme.spacing.xl` | D-13 pill height |
  | Preview info-chip radius | `theme.radii.chip` | D-13 |
  | Preview info-chip height | `theme.spacing.l` | D-13 |
  | Preview picker-pill radius | `theme.radii.button` | D-13 |
  | Preview picker-pill height | `theme.spacing.xl` | D-13 |

- **SC4 inherent satisfaction** via a single `#Preview` block rendering the three locked slot mappings (Phase 8 D-08):
  - **Minesweeper:** `Back | Flags/mines (flag.fill 10) | Reveal/Flag picker | Time (timer 1:23) | Settings`
  - **Merge:** `Back | Score (number 2048) | Mode picker | Best (star.fill) | Settings`
  - **Nonogram:** `Back | Lives/size (heart.fill 3 / 5x5) | Fill/Mark picker | Time (timer 2:45) | Settings`
- **No DEBUG-only standalone screen, no HomeView dev preview hook** — D-04 lock honored. Phase 11/12 inherit a clean component with no scaffolding to delete.
- **Build verification:** `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'` → `** BUILD SUCCEEDED **`. SourceKit's transient "No such module 'DesignKit'" indexer warning was a known cold-index artifact, not a real compile error.
- **Token discipline holds:** zero literal `cornerRadius: <int>` matches, zero `padding(<int>)` matches, zero `AnyView` matches, zero `foregroundColor` matches (uses `foregroundStyle` per §8.6).

## Task Commits

1. **Task 1: Create VideoCompactControlRow.swift with generic @ViewBuilder slots + token-pure layout + 3-game #Preview** — `328f277` (feat)

## Files Created / Modified

### Created

- `gamekit/gamekit/Core/VideoCompactControlRow.swift` (155 lines, well under §8.5 500-line cap):
  - File header doc-comment names Phase 9 invariants: generic @ViewBuilder shape, token anchors, hook-exempt-but-discipline-carries note, single-#Preview SC4 mechanism, no-DEBUG-screen lock.
  - `import SwiftUI`, `import DesignKit`.
  - Public type, internal access (NOT `public` — CLAUDE.md §2 promote-on-proof rule).
  - Two computed `@ViewBuilder` properties (`backButton`, `settingsButton`) with `accessibilityLabel(Text(String(localized: ...)))` for VoiceOver per A11Y-02.
  - One `#Preview` block + two file-private helpers (`PreviewChip`, `PreviewPicker`) scoped to the file.

### Modified

- `Docs/releases/v1.1.md` — appended Plan 09-05 bullet under "Internal changes" per CLAUDE.md §0.3 / §8.14.

## Decisions Made

- **Generic @ViewBuilder, not AnyView struct, not @Environment slot injection.** 09-RESEARCH §Topic 1 rejected both alternatives (AnyView erases type info / breaks SwiftUI diffing; environment injection forces consumers into binding gymnastics and obscures the slot contract at the call site). Generic @ViewBuilder mirrors DKCard<Content: View> — the same idiom DesignKit already uses for its public card primitive.
- **Internal access, not `public` DesignKit promotion.** CLAUDE.md §2: "promote to DesignKit only when proven (used in 2+ games)". Component is brand-new; Phase 11 (Minesweeper) is its first real consumer, Phase 12 (Merge + Nonogram) its second. Re-evaluate promotion after Phase 12 lands.
- **`Theme.resolve(preset: .classicMuted, scheme: .light)` for the #Preview Theme.** Plan body called the exact preview accessor "Claude's Discretion" and noted `Theme.classicMutedLight` may not exist. `Theme.resolve(preset:scheme:)` is the canonical DesignKit resolver used by SettingsView at runtime — verified existence via `grep -n "public static func resolve" Theme.swift` and verified end-to-end via `xcodebuild build` → BUILD SUCCEEDED.
- **`gearshape` glyph for the settings button** (not `gear`) — matches the existing SettingsView entry-point convention across the codebase.
- **Picker pill preview background = `theme.colors.accentPrimary.opacity(0.15)`** — illustrative only; the component body does NOT assert a picker pill background. Each game's actual picker chooses its own surface treatment; the shared component is shape-agnostic about picker visuals beyond height/radius tokens.
- **One `#Preview` block, three slot-mapping invocations inside a single `VStack`.** The plan's automated verifier requires exactly one `#Preview` (`grep -c "#Preview" | grep -q "^1$"`) — multiple `#Preview` blocks would have shown each mapping in its own canvas tile but failed the automated gate. Single VStack lets all three mappings appear in one canvas render.

## Deviations from Plan

None — plan executed exactly as written. Resumed from a prior-session partial file that already implemented the plan's `<action>` block verbatim; verified completeness against the automated `<verify>` grep checks and `xcodebuild build`, then committed.

The plan's `tdd="true"` task attribute is a misnomer for this plan: there is no test target authored in the plan body (the verifier is `xcodebuild build` + greps + the `#Preview`-compiles inherent gate). The cross-plan TDD framing from 09-04 does not apply here — 09-05 is a pure additive shared-component drop with no test fixture. The plan's `<verify>` step is the gate, and it passed.

## Issues Encountered

- **Prior-session partial untracked file** (`gamekit/gamekit/Core/VideoCompactControlRow.swift`, 155 lines, never committed) found in working tree on resume. Verified line-by-line against plan's `<action>` block — implementation was complete and correct (all generic params, all @ViewBuilder slots, both action closures, all four required token references, single #Preview with three slot mappings, no AnyView, no literal radii/padding ints, no foregroundColor). Action: build-verify, append release-log entry, commit. No rewrite, no repair.
- **SourceKit "No such module 'DesignKit'" diagnostic** on the partial file when opened in an editor — known indexer cold-start lag for workspace SPM dependencies, not a real compile error. `xcodebuild build` from the CLI succeeded; trusted that signal over SourceKit per the resume objective note.
- **Pre-existing unstaged `Localizable.xcstrings` modification** (drawer-redesign work carried from a prior session, per the 09-04 summary's "Issues Encountered" section). Per resume-objective constraint: did NOT touch, did NOT stage, did NOT commit. Used per-file `git add` (NOT `git add .` / `-A`) per task_commit_protocol step 2.
- **`.claude/` untracked directory** — editor cruft per resume objective. Left untouched.

## TDD Gate Compliance

Plan frontmatter has `type: execute` and the single task carries `tdd="true"`, but the plan body authors no test file — the verification step is `xcodebuild build` + grep gates + the `#Preview`-compiles inherent gate. No `test(...)` commit precedes this plan, no separate test target was created. The cross-plan TDD framing inherited from Plans 09-01 / 09-04 does not extend to 09-05; the `tdd="true"` attribute is best read as a copy-paste residue from the phase's earlier RED-driven plans.

**Plan-level TDD compliance is N/A for this plan.** Verification gate: `xcodebuild build` → `** BUILD SUCCEEDED **`. This matches the plan's `<verify>` block, which is the authoritative gate.

## User Setup Required

None — the component is a pure additive SwiftUI type. Phase 11 (Minesweeper Video Mode adoption) and Phase 12 (Merge + Nonogram Video Mode adoption) will be the first real consumers; until then, the `#Preview` is the only call site and is built automatically by Xcode's preview compile.

## Next Phase Readiness

- **Plan 09-06 (Settings VideoModeSection + VideoLocationPickerView)** — independent of this component. The Settings card UI consumes the `videoMode.*` xcstrings keys from Plan 09-04 and the `VideoModeStore` from Plans 09-02 / 09-03; it does not embed `VideoCompactControlRow` (that's per-game adoption, Phase 11+).
- **Plan 09-07 (regression test sweep)** — no test changes needed against `VideoCompactControlRow` itself (component compiles; visual correctness is Phase 11/12 adoption-time, validated against Classic + one Loud preset per CLAUDE.md §8.12).
- **Plan 09-08 (phase-close integration smoke)** — `VideoCompactControlRow` is wired into nothing yet, so no integration smoke for it lands in this phase. First integration smoke happens at Phase 11 wave-1 (Minesweeper adoption).
- **Phase 11 (Minesweeper Video Mode adoption)** is now UNBLOCKED. Adoption pattern:

  ```swift
  VStack(spacing: theme.spacing.s) {
      VideoCompactControlRow(
          theme: theme,
          onBack: { dismiss() },
          onSettings: { showSettings = true }
      ) {
          MinesweeperFlagsChip(remaining: vm.flagsRemaining, theme: theme)
      } picker: {
          RevealFlagModePicker(mode: $vm.tapMode, theme: theme)
      } secondaryInfo: {
          MinesweeperTimerChip(seconds: vm.elapsedSeconds, theme: theme)
      }
      MinesweeperBoardView(vm: vm)  // existing board, unchanged
  }
  ```

- **Phase 12 (Merge + Nonogram adoption)** inherits the same adoption pattern with each game's own primary/picker/secondary slot closures.

**No blockers.** SC4 satisfied. Component is the locked contract Phase 11/12 build against.

---
*Phase: 09-video-mode-foundation*
*Completed: 2026-05-12*

## Self-Check: PASSED

- `gamekit/gamekit/Core/VideoCompactControlRow.swift` exists on disk
- `Docs/releases/v1.1.md` exists on disk (modified, contains the Plan 09-05 bullet)
- `.planning/phases/09-video-mode-foundation/09-05-SUMMARY.md` exists on disk (this file)
- Commit `328f277` verified present in `git log --oneline`
- `xcodebuild build` (gamekit scheme, iPhone 17 Pro Max simulator destination) → `** BUILD SUCCEEDED **`
- No accidental file deletions in the commit (`git diff --diff-filter=D --name-only HEAD~1 HEAD` → empty)
- `gamekit/gamekit/Resources/Localizable.xcstrings` working-tree drawer-redesign change preserved unstaged (per resume-objective constraint)
