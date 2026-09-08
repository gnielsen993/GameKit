# GameDrawer 1.6 user audit — 2026-09-08

**Verdict: hold the release. Keep the Be Kind direction; fix the help contract and constrained layouts before shipping.**

Audited application commit: `f32fb6b`, version 1.6, build 2. The branch matched `origin/main` at the start. This is a local audit, not an implementation or release. No application source fixes, commit, push, upload, or account changes were performed. The pre-existing `Localizable.xcstrings` edit was preserved; Xcode also performs string extraction during builds.

## Does the update make sense?

Yes. Free, unmetered assistance, explanations tied to the board, and practice after a recorded loss fit a calm game collection. The visible lightbulb is discoverable. Ordinary phone-size coach cards are readable, have a clear dismiss action, and leave the board accessible. Keeping targets after dismissing the prose is useful. Separate engines for separate games are appropriate; a universal hint engine or wholesale redesign is unnecessary.

The implementation fails in three places: some help is not trustworthy, persistent help is not always revalidated as the board changes, and reserving space for the coach can sacrifice the game itself. Five Letter also optimizes for information gained without considering whether that information can still help the player win.

The product should promise: **a hint gives a useful, correct next action; its target remains valid; reading it does not punish the player; the board remains usable.** The present build does not consistently meet that promise.

## Findings requiring changes before release

### 1. P1 — Help can make boards unusable in Video Mode

**Observed:** On iPhone SE at normal text size, large-top Video Mode plus a hint reduces Five Letter to tiny board fragments and Word Grid to thin columns of overlapping letters. Sudoku becomes a cramped grid whose digits no longer fit its cells. FreeCell's lowest cards meet or extend under the compact controls. At accessibility XXXL, the Sudoku board disappears and the explanation extends below the screen.

**Evidence:** [Five Letter](evidence/se-Small-Five-Letter-video-hint.png), [Word Grid](evidence/se-Small-Word-Grid-video-hint.png), [Sudoku at normal size](evidence/se-Sudoku-classicMuted-largeTop.png), [Sudoku at XXXL](evidence/se-Sudoku-accessibilityXXXL-video.png), [FreeCell](evidence/se-Small-FreeCell-video-hint.png). These SE captures wait for the transition before taking the screenshot. Earlier iPhone 17 transition frames were excluded as layout evidence.

**Cause:** `Core/GameAssistCard.swift:136` inserts the full intrinsic-height card into the safe area. Game layouts then divide the remaining height among fixed controls and a flexible board. The board is allowed to collapse while its digit fonts remain large. Opposite-edge placement alone does not guarantee usability.

**Change:** Reserve a usable board footprint first. Bound and scroll the explanation, collapse secondary help after reading, and adapt the keyboard/number-pad layout when height is constrained. Keep the dismiss and apply actions reachable. Do not solve this by shrinking all text or removing accessibility scaling. Check both large Video Mode positions, small-corner positions, and normal play.

The iPad mini follow-up shows readable normal-size Sudoku in dark Classic, but overlapping oversized digits at XXXL: [normal](evidence/ipad-Sudoku-classicMuted-largeTop.png), [XXXL](evidence/ipad-Sudoku-accessibilityXXXL-video.png). This is not limited to small phones.

### 2. P1 — Nonogram can confidently amplify a player's mistake

**Reproduction:** Use a 5×5 plus-sign puzzle with row and column clues `[[1], [1], [5], [1], [1]]`. Fill the correct middle row, then incorrectly fill row 1, column 1. The engine chooses the first row as complete and instructs the player to mark its remaining cells X, including row 1, column 3, which must be filled in the unique solution.

**Evidence:** Executed `nonogramWrongPremise` reproduction. It confirms an actual false target, not merely an awkward explanation. `Games/Nonogram/NonogramViewModel.swift:182` accepts a deduction before checking for contradictions; `Engine/NonogramTalkthrough.swift` reasons from player-entered fills and X marks and skips contradictory lines independently.

**Change:** Validate the premises before issuing guidance. A board with conflicting marks needs correction guidance rather than a confident deduction based on those marks. Check issued targets against the puzzle's truth and add corrupted-board cases, including mistakes that remain locally satisfiable. Checking only clean boards or skipping unsatisfiable lines is insufficient.

### 3. P1 — Sudoku's “Fill it in” can add a pencil note

**Reproduction:** Select Notes, request a hint, then tap Fill it in. The answer appears as a small note, and the hint disappears. Reopening the app preserves the note rather than a solved cell.

**Evidence:** Executed `sudokuHintInNotesMode` reproduction and the simulator Notes → hint → apply → relaunch flow. `Games/Sudoku/SudokuViewModel.swift:472` calls `place(value:)`, which intentionally follows the current interaction mode. The fallback at line 482 uses the same path.

**Change:** Both apply actions must commit a value through the normal correctness, undo, persistence, and completion logic regardless of Notes mode. Define whether to preserve the player's Notes selection afterward; either choice is reasonable if the advertised action actually fills the cell. Test normal, Lives, and Practice modes.

### 4. P1 — FreeCell's persistent hint can target a different card

**Reproduction:** On deal 1, request a hint, then move the named column card into the second free cell instead of the suggested first free cell. The hint remains attached to the old column, whose exposed top card has changed.

**Evidence:** Executed `freeCellHintDoesNotRetargetAnotherCard` reproduction. `Games/Solitaire/FreeCellViewModel.swift:186` resolves the current last index of the stored source column rather than checking the named card. `applyHint()` uses that computed source; applying a stale hint can reject the move or act on a different card if legal.

**Change:** Preserve hints across genuinely unrelated moves, but validate source-card identity, destination, sequence membership, and legality after relevant moves and undo. Retarget the same card when appropriate or clear/recompute the hint. Before applying, verify the move still matches the explanation.

### 5. P1 — Five Letter can recommend a guaranteed losing final guess

**Observed UI:** The initial coach says “Try TARIE” and explicitly says it cannot be the answer. That is understandable as an early information-gathering move, but it is an unfamiliar word and feels unlike help from an ordinary player.

**Reproduction:** With two answers remaining, LIGHT and NIGHT, five prior BIGHT feedback rows, and DIGHT as the accepted non-answer probe, the engine recommends DIGHT. It cannot win the final turn and does not even distinguish the two remaining answers. This is a deterministic engine fixture; a six-turn live puzzle was not used to fabricate the result.

**Evidence:** Executed `fiveLetterLastGuess` reproduction; [ordinary coach](evidence/17-Five-Letter-hint.png). `Games/Words/FiveLetter/FiveLetterAssist.swift:18` removes all answer words, and the ranking never checks guesses remaining or whether its best probe actually splits the candidates.

**Change:** Make help sensitive to the turn. A final-turn hint must not offer a guaranteed non-answer; use candidate/constraint guidance if the no-answer-reveal policy remains. Reject probes that yield no new distinction, prefer familiar words, and explain early probes as information gathering. Candidate count and an actionable clue are better than a misleading “useful guess.”

## Other defects and usability improvements

### 6. P2 — Returning from the background resumes the timer under an open hint

The small-phone Sudoku flow applied one hint, opened another, backgrounded the app, and returned. The timer changed from 0 to 3 seconds while the card remained visible. [Before](evidence/se-Small-Sudoku-hint-before-background.png), [after](evidence/se-Small-Sudoku-hint-after-background.png); retained accessibility trees record the values. The expected-failure UI assertion reproduced this.

`SudokuGameView.swift:133` resumes on scene activation, and `SudokuViewModel.swift:287` does not account for the open hint. Similar independent scene/card pause handlers exist in Minesweeper, Nonogram, FreeCell, and Five Letter; those are code-review follow-ups, not separately reproduced timer failures. Use a single derived “timer may run” condition that accounts for scene activity, active play, and every pause reason.

### 7. P2 — Minesweeper's initial help and teaching copy need clarification

The lightbulb is visible and tappable before the first move, but nothing happens because `requestHint()` requires `.playing`. A player asking “where do I start?” gets silence. Show brief first-move guidance that explains the safety guarantee, or make the unavailable state explicit.

After the first reveal, a valid safe-square hint appears. However, the tested explanation repeatedly says “the 1” for two different highlighted 1s, while both use the same visual treatment. The user must already understand the comparison to decode the explanation. [Captured hint](evidence/17-Minesweeper-playing-hint.png).

Distinguish the two evidence cells in the copy, clearly distinguish the action target from the evidence and inferred mines, and lead with a short action before the reason. The toolbar also truncates the title to “Mines...” on the ordinary iPhone 17; remove redundant toolbar text before compressing the game name.

### 8. P2 — Screen-reader target identification is incomplete

The captured Sudoku accessibility tree labels cells “Empty” or “Given 3” without coordinates or hint-target status, even though the coach names a row and column. Minesweeper exposes coordinates but not the safe/evidence hint roles. FreeCell's tree contains separate rank and suit graphics; heart symbols appear as “Remove From Favorites,” which is inappropriate for a playing card. Word Grid has letter coordinates but does not expose hint-path order.

Add combined card labels and actionable board labels with coordinates and hint roles. Announce the new explanation and expose the intended next action without making a player count anonymous elements. This is an accessibility-tree/source finding, not a claim that an end-to-end VoiceOver session was completed.

### 9. P2 — Explain the record consequence where help is requested

The assisted-win rule is sound and covered by the passing record tests. The observed coach cards do not tell the player that receiving help removes record eligibility. A short shared note such as “Your win still counts; hints do not set records” would make the consequence clear without adding a modal or a warning ceremony. Treat this as a UX recommendation, not evidence that records are currently written incorrectly.

### 10. P2 — Word Grid displays points that a revealed word did not earn

On iPad, following the hinted ROD path and submitting it correctly leaves the total at 0 and displays a +0 response, but the Found panel says “ROD +1.” [Screenshot](evidence/ipad-WordGrid-submitted-zero-points.png). `WordGridViewModel.swift:154` correctly awards zero to revealed words; `WordGridFoundWordsPanel.swift:86` and `:98` recompute the ordinary word value for display. Pass the actual awarded value or revealed status into the panel and make both layouts show 0 or “Revealed.” This is misleading presentation, not an observed stored-score error.

## User journeys and results

| Step | Flow | Result / limits |
|---|---|---|
| 1 | Launch and open The Drawer; choose games and modes | All ten games reached. Fresh and returning launch assertions passed on SE. |
| 2 | Minesweeper: ask before play, reveal first square, ask again, dismiss | Initial ask is silent; in-play advice appears and target persists. No first-tap loss observed. Exhaustive board correctness is covered by the engine suite, not this short play session. |
| 3 | Nonogram: ask, dismiss, fill highlighted cells, lose lives, Keep solving | The coached actions can be followed. Practice preserves the board and frozen run time. Wrong-premise advice is a separate confirmed engine defect. |
| 4 | Sudoku: request/apply in Notes, close/reopen, continue | Resume works; the apply action preserves the wrong kind of entry (a note). |
| 5 | FreeCell: request, apply, relaunch, continue, undo | The tested deal and undo survived relaunch. Separate changed-source reproduction confirms stale guidance. |
| 6 | Five Letter: request and dismiss useful-guess help | Visible and readable normally; unsuitable probe policy and constrained-board layout need changes. |
| 7 | Word Grid: reveal, dismiss, trace, submit, finish | Tablet trace and submission accepted the revealed word at zero total points, but the Found panel claims +1. Follow-up details below. |
| 8 | Merge: swipe in all four directions | Board changes and score advances. A stored best of 18,432 remains visible while the current score is 8. |
| 9 | Solitaire: open Easy and inspect board | Board and controls render. Undo persistence also has passing logic coverage; this was not a complete winning deal. |
| 10 | Stack and Snake: start, play, game over; restart Snake | Both games reached their game-over cards. Snake restart worked. The corrected arcade probe passed. |
| 11 | Profile and Settings | Both reachable, stats and controls render. No destructive reset/import/account action executed. Simulator reports iCloud unavailable; that is not classified as a production defect. |
| 12 | Four presets, Video Mode, XXXL, small phone, tablet | Several constrained layouts fail despite readable semantic colors. Details and device coverage below. |

## Verification and evidence limits

The baseline application built and its complete app-hosted logic suite passed: **494 tests passed, 1 skipped**, including dynamically parameterized cases. The standalone SudokuCore package completed **40 passed, 7 skipped**. These passing suites did not catch the four newly reproduced hint defects.

The first iPhone 17 UI survey passed **10/10** flow probes. The deeper iPhone 17 run passed its eight UI probes and reproduced two known issues; one FreeCell fixture precondition was wrong (the selected deal wanted the first free cell), and was corrected for the SE run. That was a harness error, not an application defect.

The SE run reproduced **four logic defects plus the background-timer defect** using explicit known-issue assertions. Seven other tests passed. The arcade probe had a false assumption: Snake defaults to wrapping at the edge, so waiting for a wall death did not produce a Restart button. Its captured “game-over” filename actually shows active play and is excluded from supporting evidence. Do not read the aggregate failed result as an additional Snake bug.

The corrected iPhone 17 arcade check explicitly enables walls and passed **1/1**, reaching Snake game over, restarting it, then playing Stack to game over. Screenshots confirm both endings.

The iPad mini run completed its four-preset matrix and XXXL captures. Its first Word Grid assertion incorrectly expected an individual word accessibility element; the panel actually combines its words into one accessibility label. The screenshot and hierarchy confirm ROD was accepted. That assertion failure is a harness error; the contradictory +1 label is a separate, confirmed app defect.

After correcting the accessibility assertion, the Word Grid journey passed **1/1**, including Finish. The [end screen](evidence/ipad-WordGrid-finished.png) correctly reports score 0 and assistance used.

Video Mode tests enabled the app's reserved-window layouts through its real stored settings. No external video player/PiP window was started, so actual system-window overlap and drag placement still need a physical-device check. Haptics, sound quality, 60/120 Hz responsiveness, and real iCloud sign-in/restore were not established by this simulator audit. Nonogram 20×20 produced a hint and accepted a target tap on SE, but that is not a frame-rate benchmark.

The four tested presets are Classic, Dracula, Voltage, and Lavender. Preset checks establish what these captured configurations look like; they do not certify every preset, size, orientation, or multitasking arrangement.

### Reproduction artifacts

- [Logic reproductions](probes/Release16AuditRegressionTests.swift) retain the four expected-correct-behavior assertions wrapped in `withKnownIssue`.
- [UI probes](probes/Release16AuditTests.swift) retain the journeys, screenshot capture, launch settings, and expected timer failure.
- The probes were temporarily compiled in the existing test targets and then archived here. They are not new production tests or application changes. To rerun, copy each to its matching `gamekit/gamekitTests/` or `gamekit/gamekitUITests/` target folder. Remove `withKnownIssue`/`XCTExpectFailure` when promoting fixed cases to regression coverage.
- [Run logs](logs/) and selected original screenshots/accessibility trees are retained locally in this report. Full result bundles are `/tmp/GameDrawer16{Unit,UI,Deep2,Small,IPad,Arcade,WordGrid}.xcresult`; these temporary bundles are not durable repository artifacts.

Commands used the project/scheme below, `-parallel-testing-enabled NO` for UI probes, and `-resultBundlePath` for each run:

```sh
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/GameDrawer16Audit -skip-testing:gamekitUITests -quiet test
swift test --package-path Packages/SudokuCore --scratch-path /tmp/GameDrawer16SudokuPackage
```

Probe selectors: `-only-testing:gamekitTests/Release16AuditRegressionTests` and `-only-testing:gamekitUITests/Release16AuditTests/<method>`. Device destinations were iPhone 17 (`82FBCB79-5A7B-4627-8CFD-F72BBF7A3C81`), iPhone SE 2nd generation (`56119D72-B9E6-48BD-88E9-1CF32AA0784B`), and iPad mini A17 Pro (`BB02A073-8B98-4E65-BD70-A7DFE9B54A73`).

## Recommended implementation order

1. Fix the four hint correctness/usefulness defects and promote the reproductions to ordinary regression tests.
2. Fix the shared height allocation and each affected board's minimum-size handling. Recheck normal text and XXXL with help both open and dismissed.
3. Fix timer pause reasons, target accessibility, and the small copy/toolbar issues.
4. Recheck practice completion and records, resume/undo, first-tap safety, and all six assisted games in ordinary and Video Mode layouts.
5. Finish the documented physical-device and iCloud checks, update the build number and release notes, then perform release wrap-up.

Do not expand this into a universal coaching framework. The existing shared presentation plus game-specific engines is a reasonable structure; it needs stronger state contracts and layout constraints.
