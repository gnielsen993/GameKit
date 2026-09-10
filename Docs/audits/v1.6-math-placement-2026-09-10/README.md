# Math Crossword arithmetic feedback and tile returns

## Behavior

- Matched Solvara `GameState.status(of:)` at commit
  `02203a86dbc78895bfd98f7bd3a1091b3e645b16`.
- Incomplete equations stay neutral, including placements that cannot lead to
  a solution. Only a completed equation with false arithmetic produces red
  highlights, an error message, or the error haptic counter.
- Complete alternate solutions win. Requested hints respect alternatives;
  their internal feasibility search is separate from gameplay validation.
- Dragging a placed tile back to the bank uses saved, undoable erase.
  Dropping on a given cancels without changing inventory.

## Verification

- Engine: 23 tests passed using `swift test --package-path
  Packages/MathCrosswordCore --scratch-path /tmp/GameDrawerMathArithmeticBuild`.
  Tests cover neutral impossible partial boards, a working row with an
  impossible unfilled crossing, and the crossing becoming incorrect only
  after its arithmetic is complete. Also cover alternate wins and hints,
  inventory, save restoration, Undo, and ordered versus commutative operations.
- iPhone SE (3rd generation), iOS 26.2: 13 tests passed (11 focused app
  tests and two UI methods). Verified no premature warning or error counter,
  completed-equation errors, drag back to bank, Undo, invalid drops, and
  Video Mode off / large-top / small-bottom-right.
  Result: `/tmp/GameDrawerMathArithmetic.xcresult`.
- `git diff --check` passed.
- Earlier drag implementation checks passed on iPhone SE and iPad mini,
  with Video Mode off and on. Screenshots inspected in Classic, Dracula,
  Voltage, and Lavender; XXXL controls checked after shortening the warning.
  The earlier global-solvability error behavior was rejected and replaced.
- No physical-device haptic test or full-app regression suite was run.
