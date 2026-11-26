---
sketch: 010
name: home-library-navigation
question: "Which navigation model lets a new player find a game and a returning player resume or jump to a pinned mode without coaching?"
winner: null
tags: [home, library, navigation, pins, continue-playing, phase-19]
---

# Sketch 010: Home and Library navigation

## Design Question
2.0 adds a personal layer (Continue Playing, Pinned, Today) to a product whose
root is a flat grid. Where does that layer live relative to the complete list
of games? Vision open decision 1.

## How to View
```
open .planning/sketches/010-home-library-navigation/index.html
```

## Variants
- **A: Home and Library tabs** — a two-item tab bar returns. Home is personal, Library is the complete grid.
- **B: One scrolling Home** — no tab bar. Personal sections first, All Games as the last section, with a jump link in the bar.
- **C: Drawer with a personal shelf** — the 1.6 grid stays the root. Saves and pins sit in one horizontal shelf above it. Smallest change from what ships.

## What it models from the shipped code
- Saves are per game and mode: 32 slots (`*SaveState.key(...)`), FreeCell being the one single-slot game. Starting a different mode never replaces another mode's save.
- Each game already asks Resume or New when its slot has a save, so Home needs no conflict screen of its own.
- Mode shapes come from `GameDescriptor.all`: Sudoku and Nonogram are mode by difficulty, Stack and Snake have no modes and never save.
- Today is the existing Five Letter Daily, not a new puzzle.
- Continue Playing shows the newest three saves plus See all. Pins cap at six.

Tile colors for the five games not in the older sketch theme are approximations,
and the icons are redrawn, not exported from `GameIconView`.

## Running the walkthrough
Pick a variant and a player, press Start on a task, read it aloud, then stay
quiet. The tap log times every tap from Start; Copy log gives the record the
Phase 19 exit asks for (first taps, hesitation, wrong turns). Run each tester
on one variant first, rotating which, so order does not decide the winner.

## What to Look For
- Task 1 (find FreeCell): in A, does the tester notice the Library tab, or hunt on Home? In B, do they scroll or use All Games?
- Task 3 (pin a mode): is the pin on the mode chip found without help, and is it confused with Pin game?
- Task 5 (new Hard Sudoku, keep the saved one): does anyone expect to lose the Lives board?
- With the heavy player, does C's shelf turn into a second, unlabeled launcher?
- With Larger accessibility text on, which variant still shows a useful first screen?
