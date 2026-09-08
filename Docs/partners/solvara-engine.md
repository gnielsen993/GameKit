# Solvara Math Crossword engine reuse

## Provenance

- Partner repository: `cxnielsen/solvara`
- Upstream path: `Solvara/Solvara/Engine/Engine.swift`
- Source commit: `02203a86dbc78895bfd98f7bd3a1091b3e645b16`
- Reviewed and adapted: 2026-09-08

Gabe confirmed that reuse from `cxnielsen` repositories is generally
preapproved. This package retains the upstream deterministic generator,
arithmetic equation model, uniqueness gate, forced-chain solver, and seeded
random-number generator. It is a source adaptation rather than a dependency on
the Solvara application target.

## Adaptation

`Packages/MathCrosswordCore` exposes the reusable puzzle layer as Swift 5.10
code with no SwiftUI, storage, network, purchase, quota, or theme dependency.
The original 614-line engine is split by concern:

| Package file | Responsibility |
| --- | --- |
| `CoreTypes.swift` | public puzzle, equation, position, operation, and validation model |
| `LayoutTemplates.swift` | internal crossword layouts |
| `PuzzleFactory.swift` | deterministic bounded generation |
| `Solver.swift` | solution count and forced hints |
| `MathCrosswordSession.swift` | Codable player placement, inventory, erase, undo, and hint application |

The package adds validation at the persistence boundary. A restored session
rejects invalid puzzles, coordinates outside the 64×64 supported layout bound,
placements outside blank cells, overspent duplicate tiles, or history that does
not replay to its placement state. Erase and replacement are recorded as
reversible moves, so Undo restores the actual previous tile. Arithmetic uses
overflow-reporting operations for malformed saved operands. Hints only use a
board whose placements match the verified solution and available bank, so a
wrong player tile cannot produce an authoritative but false next move.

## Integration assessment

The **engine is ready to integrate**, but a Math Crossword game is not
drop-in at the app level. GameDrawer still needs its own `Games/MathCrossword`
view model, board layout, tile interaction, timer/stat persistence, hints UI,
accessibility labels, navigation, and DesignKit token styling. Those are
consumer responsibilities and deliberately do not live in this reusable
package.

The intended consumer flow is:

1. Generate `TallyPuzzle` with `PuzzleFactory.generate(difficulty:seed:)`.
2. Initialize `MathCrosswordSession(puzzle:)` and persist it through the app's
   existing local save mechanism.
3. Render `equations`, `givens`, `placements`, and `remainingBank`; apply user
   moves through `place(_:at:)`, `replace(_:at:)`, `erase(at:)`, and `undo()`.
4. Present `nextHint()` as a proposed action, or deliberately apply it with
   `applyNextHint()`.

`PuzzleFactory.generate(difficulty: .easy, seed: 1)` is a verified deterministic
fixture for development and tests. Production should supply a recorded random
seed and handle `attemptBudgetExhausted` by advancing to another seed. It must
also honor cancellation when generation is run from a task.

## Verified engine guarantees

- The same difficulty and seed produce the same equations, solution, givens,
  and bank.
- Every generated equation holds under the supplied solution.
- The generator accepts only puzzles with one bank-constrained solution.
- Generation has a per-seed attempt budget and cancellation exit.
- Forced hints reject untrusted board premises.
- Duplicate-valued tiles retain multiplicity through placement, undo, and
  Codable restoration.

These guarantees are covered by `Packages/MathCrosswordCore` unit tests. They
do not replace game-level simulator, accessibility, theme, persistence, or
physical-device verification.
