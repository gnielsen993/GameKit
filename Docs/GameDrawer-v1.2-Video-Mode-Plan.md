# GameDrawer v1.2 Video Mode Plan

Date: 2026-05-12
Status: draft product/UX plan
Scope: GameDrawer v1.2 discussion input, no implementation yet

## Goal

Video Mode lets someone play GameDrawer while a floating video/PiP window is on screen. The app should move game UI out of the way when possible without making normal gameplay worse.

This is an optional mode. It does not need to be perfect in every layout. The promise is: choose where the video is, and GameDrawer will do its best to keep the game playable.

## Core rule

- Small PiP = control-aware.
- Large PiP = board-aware.

Small PiP usually blocks controls more than the board. Large PiP can remove enough screen space that the board itself needs to reflow, shrink, or scroll.

## Auto detection

Treat auto-detection as best-effort/future work. iOS likely does not expose another app's PiP frame or location to third-party apps through public APIs.

Reliable v1.2 path:

- User turns Video Mode on.
- User chooses video location manually.
- GameDrawer adapts layout from that setting.

If a safe public API or app-owned video flow later gives us location data, Auto can be added as a convenience on top of the same layout model.

## Settings

Proposed settings surface:

- Video Mode: Off / On
- Video location:
  - Large top
  - Large bottom
  - Small top-left
  - Small top-right
  - Small bottom-left
  - Small bottom-right

Do not design v1.2 around large left/right PiP. Current observed large PiP positions are top and bottom.

Portrait/vertical PiP exists but is rare. Defer TikTok/vertical-video layouts beyond v1.2 unless real usage shows it matters.

## Layout behavior

### Small PiP

Small PiP should not force a full board redesign by default.

Behavior:

- Avoid the covered corner.
- Move picker, back, settings, and info chips away from that corner.
- Keep the board in the normal layout unless the PiP covers playable cells.
- Prefer moving controls to the opposite side over shrinking the board.

Examples:

- Small top-right: move settings/top-right actions into the compact row or opposite side.
- Small top-left: move back/exit away from the covered corner.
- Small bottom-left: move picker or bottom controls to bottom-right or top row.
- Small bottom-right: move picker/settings away from bottom-right.

### Large PiP

Large PiP reserves a top or bottom band.

Behavior:

- Large top: keep the video area clear at the top, move controls toward the bottom, and fit the board between the video zone and control row.
- Large bottom: keep the video area clear at the bottom, move controls/info to the top, and fit the board below that row.
- Board gets priority over secondary controls.
- Controls collapse before the board becomes unplayable.

## Compact control row

Video Mode should use a compact row instead of normal scattered navigation/toolbars.

Target order when controls need to be consolidated:

Back | primary info | picker | secondary info | settings

Game-specific examples:

- Minesweeper: Back | Flags/mines | Reveal/Flag picker | Time | Settings
- Merge: Back | Score | Mode picker | Best/time if used | Settings
- Nonogram: Back | Lives/size | Fill/Mark picker | Time | Settings
- Sudoku: Back | Mistakes/notes | Number/notes picker | Time | Settings

The picker should become a compact primary pill:

- Smaller than the current full picker.
- Slightly more prominent than info chips.
- Same visual family as the rest of the row.
- Easy to hit, but not allowed to dominate the Video Mode layout.

## Compromise order

When space gets tight:

1. Preserve playable board.
2. Preserve critical game info, such as flags/mines/lives/mistakes.
3. Keep the mode/picker reachable.
4. Collapse settings and secondary controls into a menu.
5. Reduce visible time/secondary stats if needed.
6. Shrink or scroll the board only when controls are already compact.

Do not hide information that makes the game unfair or confusing.

## Game-specific notes

### Minesweeper

Minesweeper is the hardest Video Mode case.

- Easy should be manageable.
- Medium has room to work with.
- Hard/large Minesweeper is not solved yet with the current board sizing.

Known issue: hard Minesweeper can take nearly the whole screen. A large top/bottom PiP may leave too little room for the current fixed board plus usable controls.

Possible directions to explore:

- Smaller cells in Video Mode.
- Pan/scroll the hard board.
- Zoom controls or pinch-to-zoom later.
- Board-first layout with controls compressed into one row.
- A warning/hint for hard mode: Video Mode works best with small PiP or a different PiP location.

No final answer yet. Do not treat hard Minesweeper as solved in the v1.2 design until it has a real prototype.

### Merge

Likely straightforward.

- Square board is easier to fit.
- Compact row should be enough for most PiP cases.
- Large PiP may only require vertical compression.

### Nonogram

Medium complexity.

- Hints plus board need careful space management.
- Large sizes may behave more like Minesweeper.
- Small PiP should mostly move controls, not redesign the grid.

### Sudoku

Design Sudoku with Video Mode in mind from the start.

- Board plus number picker should avoid bottom PiP conflicts.
- The number picker may need compact/side variants.
- Notes/mistakes/time should fit the shared compact-row model.

## Win/loss screens

v1.2 also needs win/loss changes so the board stays visible.

Video Mode should align with that direction:

- Avoid full-screen end overlays that hide the board.
- Prefer docked result panels, sheets that leave board context visible, or compact cards that avoid the selected PiP zone.
- Large PiP layouts should place result actions opposite the video band when possible.

## Open questions

- What exact hard Minesweeper strategy feels best: smaller cells, scroll/pan, zoom, or warning plus compromise?
- Should Video Mode default to the last chosen PiP location globally or per game?
- Should small PiP always be corner-aware, or should users be able to choose a simpler top/bottom mode only?
- Does compact picker design need per-game variants or one shared component?
- Should vertical/portrait PiP be tracked as a future v1.3+ item?
