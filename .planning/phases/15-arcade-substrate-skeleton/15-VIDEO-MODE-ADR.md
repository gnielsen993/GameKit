# ADR: Stack and Snake are exempt from Video Mode (ARCADE-08)

**Status:** Accepted — 2026-06-26 · **Amended 2026-07-02 — Stack exemption lifted (see Amendment below); Snake remains exempt**
**Satisfies:** ARCADE-08 (documentation deliverable)

---

## Context

Video Mode (v1.2, Phase 9) pauses layout and reflows game chrome when a PiP video overlay
occupies screen space. It is applied via `.videoModeAware(minBoardHeight:)` in
`HomeView.destination(for:)` before `.disableInteractivePop()`. The modifier triggers a layout
pass mid-play, compressing board height to make room for the PiP strip.

Eight existing games receive `.videoModeAware()`:
- Minesweeper, Merge, Nonogram, Sudoku, FreeCell, FiveLetter, WordGrid

Two existing games already omit it:
- Klondike (Solitaire) — see **Precedent** below

Stack and Snake are two additional games that omit it — this ADR records why.

---

## Decision

Stack and Snake do **NOT** receive `.videoModeAware(minBoardHeight:)` in
`HomeView.destination(for:)`.

The code landed in Phase 15 (Plan 04, commit 54b9d31):

```swift
case .stack:
    StackHarnessView()
        .disableInteractivePop()   // ADR ARCADE-08: no .videoModeAware() for real-time games
case .snake:
    SnakeHarnessView()
        .disableInteractivePop()   // ADR ARCADE-08: same exemption
```

Only `.disableInteractivePop()` is applied — no Video Mode adoption.

---

## Rationale

Real-time continuous-input games cannot pause-and-reflow for a PiP overlay without
disrupting the run. An incoming layout change during active play causes desync between
the engine's computed frame and the rendered frame:

- Stack: blocks are falling in real time. A sudden height compression mid-drop changes the
  coordinate system the fall is computed in, producing an invalid board state.
- Snake: the snake occupies grid cells indexed by pixel-derived cell size. A reflow changes
  cell size mid-game, snapping the snake to a different position.

This is fundamentally different from turn-based games (Minesweeper, Merge, Nonogram, Sudoku)
where layout can safely change between player taps. Those games tolerate the PiP reflow
because the engine only computes on tap events, not on every frame.

---

## Precedent

`klondike` (Solitaire) already ships without `.videoModeAware()` in `HomeView.destination(for:)`:

```swift
case .klondike(let difficulty):
    SolitaireGameView(initialDifficulty: difficulty ?? .easy)
        .disableInteractivePop()
```

Solitaire omits Video Mode by convention (card-drag interactions are sensitive to layout shift).
Stack and Snake omit it by this explicit ADR decision — same result, explicit rationale.

---

## Future

If Video Mode support for arcade games is desired in a later milestone, it requires a separate
design pass. The correct approach is a **SUSPEND-on-PiP** mode: the active run pauses entirely
when PiP activates (no layout reflow), and resumes on PiP dismiss. This preserves run integrity
and gives the user a safe pause point.

A layout-reflow approach (`.videoModeAware()` as-is) is not viable for real-time games — the
engine and renderer would need to be redesigned around dynamic coordinate systems. Out of scope
for v1.5.

---

## Consequences

- Stack and Snake tile navigation in `HomeView.destination(for:)` carries only
  `.disableInteractivePop()` — no `.videoModeAware()`.
- The ARCADE-08 documentation deliverable is satisfied in Phase 15 (D-11), pulled earlier
  than the ROADMAP/REQUIREMENTS Phase-18 mapping.
- Phase 18 (score-based stats + polish) references and closes this ADR; it does not reopen
  the decision.
- No PiP overlay surface is introduced for Stack/Snake — the exemption bounds the exposure
  rather than expanding it (STRIDE T-15-04: Information Disclosure → accepted).

---

## Amendment — 2026-07-02: Stack exemption lifted

User decision during Phase 16 polish: Stack adopts `.videoModeAware(minBoardHeight: 480)`.

The original rationale does not hold for Stack as built:
- `StackEngine` is pure normalized-coordinate (playfield width = 1.0) — it has zero pixel
  knowledge. There is no pixel-derived state to invalidate.
- `StackBoardCanvas` derives ALL geometry from its size inside the draw closure, every frame.
  A mid-run reflow rescales the render; the engine's computed frame is untouched. No desync
  is possible — the "invalid board state" claim assumed pixel-anchored fall physics Stack
  never had (falls are view-layer FX in normalized coords, scaled at draw time).

Adoption (DESIGN.md §7, mirroring MergeGameView+VideoMode.swift):
- Large zones: nav bar hidden, `VideoCompactControlRow` opposite the band
  (Back | ScoreChip | empty picker | StreakChip). No restart in the row — Stack has no
  mid-run restart by design; the game-over banner carries it.
- Small zones: existing layout; back chevron via `anchors.back`, score/streak overlay to
  the `anchors.headerBar` corner.
- Off-path byte-identical (§7.6).

**Snake remains exempt** — its rationale is real: grid cells are pixel-derived and input is
continuous steering. The suspend-on-PiP design in **Future** above is still the correct path
for Snake if adoption is ever desired. *(Superseded by Amendment 2, 2026-07-09 — the
"pixel-derived" claim was wrong; see below.)*

---

## Amendment 2 — 2026-07-09: Snake exemption lifted

User decision during the Video Mode compliance audit: Snake adopts
`.videoModeAware(minBoardHeight: 480)`.

The 2026-07-02 amendment's closing claim ("grid cells are pixel-derived") was stale —
it did not survive contact with Snake as actually built in Phase 17:
- `SnakeConfig` fixes a LOGICAL 20×32 grid (`cols`/`rows` constants). Snake body and food
  positions are logical cell coordinates in `SnakeEngine` — zero pixel knowledge.
- `SnakeBoardCanvas` derives `cellSize = size.width / cols` inside the draw closure, every
  frame. A mid-run band reflow rescales the render; engine state is untouched. This is the
  exact property that lifted Stack's exemption.
- Continuous steering is unaffected: swipe direction mapping and the D-pad are
  size-independent; the direction queue lives in the VM.

The suspend-on-PiP design in **Future** is therefore unnecessary — no suspend is added.

Adoption (DESIGN.md §7.7 necessity principle, mirroring StackGameView+VideoMode.swift):
- `.largeTop`: nav bar hidden, `VideoCompactControlRow` at the bottom edge
  (Back | SnakeScoreChip compact | empty picker | row-height wall-mode menu).
- `.largeBottom` + small-bottom zones: off-path chrome unchanged — the band inset
  compresses the stack; the centered D-pad clears corner PiPs on both sides.
- Small-top zones: per-corner moves only (back/menu re-anchor away from the covered
  corner; the score chip moves only when `.smallTopRight` covers it).
- Off-path byte-identical (§7.6).

With this amendment the ARCADE-08 exemption class is empty — every shipped game is Video
Mode aware. Klondike's separate never-formalized exemption ("drag interactions, by
convention") was closed the same day: its drag math is view-local, and its +VideoMode
branches had shipped without the band-reserving modifier, leaving large-zone layouts
under the real PiP.

---

*Phase: 15-arcade-substrate-skeleton*
*Written: 2026-06-27*
*Amended: 2026-07-02 (Stack adoption — Phase 16 polish)*
*Amended: 2026-07-09 (Snake adoption — Video Mode compliance audit; exemption class now empty)*
