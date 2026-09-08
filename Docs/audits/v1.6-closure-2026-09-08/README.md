# GameDrawer 1.6 closure verification

Date: 2026-09-08. Version: 1.6, build 3. Local implementation; not published.

## Decision

The Be Kind direction makes sense: help explains a specific next action, lets the player choose whether to apply it, and keeps assisted wins separate from records. The original user audit found correctness and layout blockers, not a reason to abandon hints. The closure work fixes those defects and adds Math Crossword as the eleventh game.

Math Crossword fits the release: crossing equations provide an understandable deduction, and the finite number bank gives the player a clear interaction. The partner engine was reusable, but the partner application was not a drop-in GameDrawer game. The local adaptation adds the required interface, saves, undo, stats, validation and accessibility without bringing over quotas, purchases or networking. See [source assessment](../../partners/solvara-engine.md).

The code is a candidate for commit and device testing. App Store release still requires the physical-device checks below. The website and store changes are prepared as release drafts, not published claims.

## Original findings addressed

| Finding | Implemented correction | Verification |
| --- | --- | --- |
| F01: hints collapse boards in constrained layouts | Bounded coach text with separate apply/dismiss controls; game viewport scrolls when space is tight. Sudoku retains legible cells in a pannable board. The viewport floor does not scale with font size. Accessibility-sized coaching leads with the explanation. | SE and iPad captures, Video Mode, XXXL. Final large-text confirmation passed; see Confirmed screenshots. |
| F02: Nonogram deductions can rest on wrong marks | Check puzzle truth and all line consistency before giving advice; invalidate active advice after a contradictory mutation. | Engine and view-model regressions, including a locally satisfiable but wrong mark. |
| F03: Sudoku hint in Notes makes a note | Apply the proved value through the value-commit path while preserving the player's Notes selection. | Unit regression and UI notes/apply/resume journey. |
| F04: FreeCell retains stale guidance | Revalidate exact card identity, sequence and destination after mutations; retain only still-legal guidance. | Focused mutation/undo tests and apply/undo/resume journey. |
| F05: Five Letter wastes the final turn | No guaranteed-wrong final-turn probe; reject probes with zero information gain. | Focused last-turn and candidate tests. |
| F06: backgrounding resumes a timer under help | Compose scene and hint pause reasons; close-to-resume guards in timed game view models. | Sudoku foreground/background timer equality test and game lifecycle suites. |
| F07: first Minesweeper hint does nothing; comparison copy ambiguous | Explain first-tap safety before play without charging an assist; close that explanation on the first reveal; name both evidence coordinates. Compact the ordinary toolbar. | First-move safety regression plus played-board hint journey. |
| F08: incomplete accessibility semantics | Sudoku coordinates and hint roles, actionable Word Grid letters with hint order, Minesweeper evidence roles, FreeCell guidance and real playing-card suit labels. | Accessibility trees and updated user journeys. Actual VoiceOver audio remains a device check. |
| F09: assistance consequences hidden | Shared help discloses that assisted wins count but do not set records. | Visible coach captures and existing record-eligibility tests. |
| F10: revealed Word Grid words display points they did not earn | Found-word displays use zero for revealed words. | Trace revealed word, submit, inspect awarded points, finish. |

## Additional defect found during closure

The new Math Crossword stats round-trip test exposed a cross-game backup defect: `StatsExporter` omitted assist counts and puzzle IDs. Importing a backup therefore lost assisted labels and solved-puzzle identity. Export schema 3 now preserves both optional fields. Import accepts schemas 1, 2 and 3; older records decode with nil metadata. No SwiftData model migration or data reset is introduced.

## Math Crossword coverage

- Easy, Medium and Hard generate and open; the package checks equation correctness and bank-constrained uniqueness across all difficulties.
- Manual number-bank placement, erase and undo exercised through UI controls.
- Explanation, explicit number reveal, apply, app termination, resume, undo and assisted completion exercised on SE and iPad.
- Full puzzle, placements and history persist together. Invalid/future saves are preserved until the player confirms replacement.
- Unit tests cover duplicate tiles, invalid hint premises, stale hints, terminal mutation guards, replay record eligibility and save round-trips.
- Four presets: Classic, Dracula, Voltage and Lavender. Light phone and dark iPad captures retained. XXXL uses a pannable board and a horizontal number bank so two-digit values remain intact.
- New game appears in Home and Stats; assisted wins export/import without creating a best time.

## Executed checks

Commands use `gamekit/gamekit.xcodeproj`, scheme `gamekit`, and `-parallel-testing-enabled NO`. Result bundles are retained in `/tmp`; compact summaries are under [logs](logs).

| Run | Result | Scope |
| --- | --- | --- |
| `swift test --package-path Packages/MathCrosswordCore --scratch-path /tmp/GameDrawerMathCore` | 13 passed | Standalone partner engine/session tests. |
| `/tmp/GameDrawer16ClosureUnitFinal.xcresult` | 514 distinct passed, 1 skipped; 1,464 passing parameterized executions | Full app unit suite on SE, iOS 18.5. |
| `/tmp/GameDrawer16ClosureSE2.xcresult` | 6 passed | Small-screen hints, Sudoku background timer, Math assisted completion/resume, four presets, large text. |
| `/tmp/GameDrawer16ClosureMathFinal.xcresult` | 4 passed | Math manual play, assisted completion/resume, themes and accessibility. |
| `/tmp/GameDrawer16ClosureReleaseChecks.xcresult` | 10 passed | Final schema-3 exporter and Math stats tests, all difficulty layouts and manual controls. |
| `/tmp/GameDrawer16ClosurePad.xcresult` | 24 passed, 1 test-driver failure | All ten existing games plus Math, deep resume/practice/arcade/Settings flows, themes and large text on iPad mini, iOS 26.2. |
| `/tmp/GameDrawer16ClosureAccessibilityFlow.xcresult` | 2 passed | Scroll/read/apply a Sudoku hint and place/undo a Math Crossword tile at XXXL. |
| `/tmp/GameDrawer16ClosureLargeTextFinal.xcresult` | 3 passed | Final accessibility viewport, readable two-digit number bank, simplified coach and manual controls on SE. |
| `/tmp/GameDrawer16ClosurePadFinal.xcresult` | 3 passed | Corrected Word Grid trace/finish test; final Math manual controls and all difficulty layouts. |

The iPad test-driver failure queried Word Grid letters as static text after the accessibility fix made them buttons. Changing that query to buttons passed the full trace-and-finish journey. An earlier iPhone 17 unit launch stalled without results and was stopped; the full suite was then run successfully on SE. Initial compilation/test-fixture failures were corrected before the passing runs above.

The full unit pass preceded the final export-version constant and accessibility-only layout changes. The exporter suite and relevant UI flows were rerun after those respective changes. A build alone is not the verification claim.

## Visual evidence

[Selected screenshots](evidence) retain both intermediate and confirmed states. `SE-` and `iPad-` show the broad regression runs; `Math-final-` shows manual input and revised instructional copy. Final large-text images use `Confirmed-` and supersede the earlier XXXL captures, where screenshot review caught an oversized viewport and wrapped number-bank digits despite passing button assertions.

## Release preparation and remaining checks

Prepared:

- [Closure plan](../../../.planning/v1.6-CLOSURE-PLAN.md), source provenance and durable partner-reuse guidance in CLAUDE.md.
- [1.6 release notes](../../releases/v1.6.md), build 3, and [App Store copy](../../store/app-store-copy.md). Store fields are within their character limits.
- [Website patch](../../releases/v1.6-website-draft/website.patch): index/about/press/updates/version config. `git apply --check` passed against the current website checkout; HTML and embedded JSON-LD parse. It remains unapplied and unpublished until release.

Still required before declaring 1.6 shipped:

- Physical Picture-in-Picture video in the six reserved positions, including interaction while the real window is present.
- Real-device haptics, sound, Reduce Motion and animations-off behavior; cold launch and sustained gameplay responsiveness.
- iCloud sign-in, same-session sync reconfiguration, sign-out and restore on a second device. This turn did not change credentials or exercise live account transitions.
- Archive/upload the verified release build, and apply/browser-check/publish the website draft when the release is actually available.

No partner repository was modified. The pre-existing localization edit was preserved. Gabe approved commits on 2026-09-08. Fixes are committed as `76b152f`; Math Crossword as `471162e`. Both were pushed to `origin/main`. The closure documentation follows as its own commit.
