# v1.6 board fit and direct placement correction

Gabe reported Math Crossword overflowing in normal and Video Mode layouts,
missing drag placement, and clipped Minesweeper tools. The previous closure
review did not catch these regressions.

## Changes

- Remove the shared hint wrapper's forced 520pt scrolling viewport. Each game
  receives its actual remaining space; only long hint text scrolls.
- Reserve the small PiP footprint once in the shared Video Mode wrapper, at
  either edge. Remove duplicate reservations from individual games.
- Fit Math Crossword, Sudoku, Nonogram and Minesweeper boards to both axes.
  Wrap compact toolbars instead of clipping tools to a fixed row height.
- Drag Math Crossword numbers directly from the bank to editable cells, with
  a following tile and highlighted destination. Keep tap placement, Undo,
  inventory validation and the existing save path. Reject given/symbol drops.
- Constrain each bank tile's touch area to its visible bounds. On iPad, an
  adjacent tile's larger hit area could otherwise capture a drag.
- Use one compact Math toolbar and shorter bank tiles in all Video Mode
  positions. Fit toolbar symbols independently of Dynamic Type.
- Compress long FreeCell columns to their available height and use the same
  spacing in drag hit testing. Label free cells and foundations for VoiceOver.

## Verification

iPhone SE (375×667 points, iOS 26.2): **9 UI tests passed**, including all
**66 game/Video Mode combinations** with actual control-bound assertions.
The same run passed Math drag/Undo with Video Mode off and on, rejected given
number drops, FreeCell drag/Undo, all three Math difficulties, accessibility
XXXL interaction, and full-board hint separation for Minesweeper, Nonogram,
Sudoku and Math Crossword. Result: `/tmp/GameDrawerFit-se-final4.xcresult`.

iPad mini (iOS 26.2): **4 UI tests passed** in
`/tmp/GameDrawerFit-pad-final2.xcresult`: four Math themes (Classic, Dracula,
Voltage, Lavender), accessibility XXXL interaction, Math drag/Undo and rejection
of given drops with a full reset bank, and FreeCell drag/Undo. Although one test
requested landscape, screenshot review showed the window remained portrait.
A stricter follow-up confirmed that rotation did not produce a wide app frame;
**landscape is not counted as verified**. The test now skips explicitly when
the environment keeps a portrait window instead of silently claiming coverage.

The final full app unit suite passed **518 tests with 1 skip**, plus two
small-phone UI tests for drag/Undo and accessibility text: **520 passed total**
(1,479 parameterized runs) in `/tmp/GameDrawerFit-final-source.xcresult`. New regressions cover
constrained Minesweeper boards, small Video Mode reservations and long FreeCell
columns. The engine itself is unchanged. A final accessibility text rerun
passed in `/tmp/GameDrawerFit-final-text.xcresult` after allowing full numbers
to scale down far enough inside the smallest cells.

On iPhone 17 Pro, final native interaction tests passed Math drag/Undo with
Video Mode off, large-top and small-bottom-right, rejection of given-number
drops, FreeCell drag/Undo in both video positions, all three Math difficulties,
accessibility XXXL tap/Undo and visible Minesweeper controls.

The initial 66-screen test's coordinate parser did not match Xcode's output,
so its apparent pass is not evidence of screen bounds. The parser now reads
actual rectangles and requires a nonzero number of checked controls. The
corrected 66-screen audit passed before sign-off. Earlier simulator boot/Accessibility
timeouts happened before app tests and are not counted as passing runs.

## Limits

These are native simulator gameplay and layout checks with the app's Video
Mode reservation enabled. They do not prove the placement of another app's
live PiP window on a physical device. Physical PiP and release publication
remain the existing release checks; tablet landscape also remains unverified
because the simulator retained a portrait window. This correction does not
mark 1.6 shipped.

## Screenshot evidence

Native screenshots from the corrected iPhone SE run:

- [Math Crossword, Hard with Video Mode](se-math-hard-video.png)
- [Math Crossword with an open hint](se-math-hint.png)
- [Math Crossword, Voltage corner layout](se-math-voltage.png)
- [Minesweeper, bottom-right video](se-mines-bottom-right.png)
- [Minesweeper with an open hint](se-mines-hint.png)
- [Nonogram 20×20 with an open hint](se-nonogram-hint.png)
- [Sudoku with an open hint](se-sudoku-hint.png)

The empty band is the app's reserved video area. On a small display, dense
boards shrink while a hint is open and expand again when it is dismissed.

- [Math toolbar and board at accessibility XXXL](se-math-accessibility.png)
- [Math Crossword in Dracula on iPad](ipad-math-dracula.png)

## Self-review

Overall: 4.0/5. No outstanding implementation defect was found in the exercised
flows. Verification limits are explicit above.

| Axis | Score | Evidence and remaining improvement |
|---|---:|---|
| Accuracy | 4 | Actual bounds and drag results checked; live PiP remains a device check. |
| Completeness | 4 | Reported defects and shared cross-game overflow fixed; landscape could not be exercised. |
| Clarity | 4 | Causes, final behavior and screenshots documented; historical test failures are separated from final results. |
| Actionability | 4 | Code and regression tests are ready to commit; release still needs the listed device checks. |
| Conciseness | 4 | Shared fixes avoid per-game duplicate insets; the audit retains only selected screenshots. |

Highest-impact follow-up: exercise live PiP and a genuinely wide tablet window
on a device before publishing the release. Gabe should be able to review the
actual fixes from the screenshots and reproduce the checks from the test names.
