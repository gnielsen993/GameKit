# DESIGN.md
## GameDrawer — Visual Design Constitution

Every game in GameDrawer must feel like it was built by the same team,
with the same care, from the same parts. A player switching from Minesweeper
to Sudoku to Nonogram should feel continuity — consistent chrome, familiar
gestures, predictable information hierarchy. This document is the binding
contract for how that consistency is achieved.

**Relation to other docs:**
- `CLAUDE.md` / `AGENTS.md` govern *what to build* and *how to code it*.
- `DESIGN.md` (this file) governs *how it looks and behaves* — the visual
  and interaction language. When the two conflict on a non-functional detail,
  DESIGN.md wins.

---

## 1. Philosophy

### 1.1 One product, many games
Each game has a distinct board and mechanic. All game screens share the
same chrome, color system, component shapes, and motion language. The only
thing that changes per game is the board itself and its interaction verbs.
A new contributor should be able to look at a Sudoku screen and a Minesweeper
screen and instantly recognize they're the same app.

### 1.2 No bespoke exceptions
Do not invent new chip shapes, new button radii, new font pairings, or new
icon families for a specific game. If a game needs something not in this
document, propose it here first — don't silently diverge.

### 1.3 Token-only styling
Every color, radius, spacing, and typographic decision reads a DesignKit
semantic token. Never hardcode a hex, a point value for color, a radius
integer, or a raw font name in a game view. "Looks right on Classic" is not
a substitute for correct token usage — verify against at least one Loud/Moody
preset (Voltage or Dracula) per CLAUDE.md §8.12.

### 1.4 Haptics and animations are features, not fallbacks
The Settings screen has haptics and animations toggles because these are
meaningful enough to turn off — not because they are optional garnish that
can be ignored during design.

Design the full-feedback experience first. Every new game interaction must
have a specified haptic response and a specified animation or motion treatment
before any code ships. A game that ships with visual-only feedback is
incomplete in the same way a game with no sound design is incomplete on a
platform where sound matters.

The rule is: **design the triple**. Every significant interaction has three
simultaneous design decisions: (1) what changes visually, (2) what haptic
fires, (3) what animation plays. If any of the three is "nothing" — that
should be an explicit decision, not an omission.

The OFF state (haptics off, or animations off) must be fully functional and
clearly readable, but it should feel like the stripped version. ON should
feel like the real game. Players who disable these settings know what they're
trading off.

---

## 2. Color Semantics

These meanings are fixed across all games. Using a color for a different
purpose breaks the shared language.

| Token | Meaning | Examples |
|-------|---------|---------|
| `theme.colors.danger` | Threat · lives consumed · wrong move · destructive state | Heart glyphs when life spent, wrong-guess flash, mine explosion, flag icon active state |
| `theme.colors.success` | Win state · correct completion | Win-sweep overlay, correct row/column in Nonogram |
| `theme.colors.accentPrimary` | Player's active choice · selection · current mode | Selected Sudoku cell, active mode-pill segment, Nonogram cell fill highlight |
| `theme.colors.textPrimary` | Primary readable content | Board digit values, icon fills in toolbar buttons |
| `theme.colors.textSecondary` | Supporting readable content | Loading text, hint labels, empty-state copy |
| `theme.colors.textTertiary` | Exhausted / inactive state | Consumed lives (hearts dimmed), exhausted number-pad digits |
| `theme.colors.surface` | Chip / button background | All info chips, mode-pill background, toolbar button fills |
| `theme.colors.border` | Chip / button stroke | 1pt stroke on all chips and pills |
| `theme.colors.background` | Screen background | ZStack base layer |

### 2.1 Danger is not "red"
Use `danger` for all loss-state feedback. Never hardcode a red color. The
Classic preset maps `danger` to diner-red; Dracula maps it to a different
shade. Using the token keeps every preset correct automatically.

### 2.2 Accent is not "highlight"
`accentPrimary` signals an active player choice. It is not a generic
highlight for hover states or informational callouts. The selected Sudoku cell
uses `accentPrimary`; a peer cell uses a separate, lower-opacity overlay.

---

## 3. Component Dictionary

### 3.0 Depth rules
Interactive surfaces carry a consistent, physical depth treatment from
`Core/SurfaceDepth.swift` — light always comes from the top, on every preset:

| Treatment | Helper | Applies to |
|-----------|--------|-----------|
| Ambient shadow | `.chipShadow()` — black 10%, radius 5, y 2 | Info chips, mode pills, pad keys, keyboard keys, board tiles that sit "on" the board |
| Raised sheen | `SurfaceDepth.raisedSheen` overlay — white 16% top edge → black 8% bottom edge | Tiles that read as pressable caps: Merge tiles, Minesweeper hidden cells, Home game tiles |
| Active glow | `.activeGlow(color, active:)` — accent 45%, radius 8 | The element currently under the player's finger (Word Grid trace) |

Rules:
- These are **lighting effects, not theme colors** — the white/black literals
  live only in `Core/SurfaceDepth.swift`. Game views consume the helpers and
  never write a color literal.
- Flat stays flat: board backgrounds, empty wells, and revealed cells carry
  no sheen or shadow — depth marks *interactivity*, not decoration.
- `VideoModeBanner` stays shadow-free by design (it is chrome, not a modal).
- One treatment per element: never stack `chipShadow` under `activeGlow`
  (the glow helper already carries the resting shadow in its inactive state).

Every game must draw its chrome from this set of shared primitives.
Do not build game-specific variants of these components unless the
game-specific behavior is genuinely different (e.g. Sudoku's erase button
is game-specific; `SudokuLivesChip` is not — it should look identical to
`NonogramLivesChip`).

### 3.1 Lives Chip
**Shape:** Horizontal row of N glyphs (N = `livesPerPuzzle`, typically 3).

| Property | Value |
|----------|-------|
| Glyph filled | `heart.fill` — `theme.colors.danger` |
| Glyph empty | `heart` — `theme.colors.textTertiary` |
| Font size (full) | 14pt semibold |
| Font size (compact) | 11pt semibold |
| Padding (full) | `theme.spacing.s` H + V |
| Padding (compact) | `theme.spacing.xs` H + V |
| Background | `theme.colors.surface` |
| Corner radius | `theme.radii.chip` |
| Border | 1pt `theme.colors.border` |
| Accessibility | Combined element, "X of Y lives remaining" |

**Rule:** Hearts everywhere, always. Never circles, dots, bars, X-marks, or
numeric counters as the primary lives indicator. The heart glyph is the
shared language for "a life" in this app.

### 3.2 Timer Chip
**Component:** Always `VideoModeTimerChip` (in `Core/`). Never duplicate
the `TimelineView` timer logic in a game-specific chip.

| Property | Value |
|----------|-------|
| Font (full) | `theme.typography.monoNumber` + `.monospacedDigit()` |
| Font (compact) | `theme.typography.caption` + `.monospacedDigit()` |
| Padding (full) | `theme.spacing.m` H, `theme.spacing.s` V |
| Padding (compact) | `theme.spacing.xs` H + V |
| Icon | `clock` system glyph |
| Background | `theme.colors.surface` |
| Corner radius | `theme.radii.chip` |
| Border | 1pt `theme.colors.border` |

**Rule:** Always pass `compact: true` when the chip appears inside any
compact control row (Video Mode large-zone bar). Never use the non-compact
variant in a row constrained to `theme.spacing.xl` height.

### 3.3 Generic Info Chip
All non-lives, non-timer info chips (score, best, mines-remaining, size,
difficulty) share the same shell:

| Property | Value |
|----------|-------|
| Background | `theme.colors.surface` |
| Corner radius | `theme.radii.chip` |
| Border | 1pt `theme.colors.border` |
| Padding (full) | `theme.spacing.s` H, `theme.spacing.s` V |
| Padding (compact) | `theme.spacing.xs` H + V |
| Typography | `theme.typography.body` full; `theme.typography.caption` compact |

### 3.4 Mode Pill
Two-segment interactive capsule for toggling between a game's two
interaction modes (e.g. Reveal/Flag, Place/Mark, Value/Notes).

| Property | Value |
|----------|-------|
| Outer shape | `Capsule` |
| Outer background | `theme.colors.surface` |
| Outer stroke | 1pt `theme.colors.border` |
| Outer padding | `theme.spacing.xs` (wraps both segments) |
| Segment font (full) | `theme.typography.headline`, icon 16pt semibold |
| Segment font (compact) | `theme.typography.body`, icon 13pt semibold, `.lineLimit(1)` + `.minimumScaleFactor(0.7)` |
| Segment H-padding (full) | `theme.spacing.l` |
| Segment H-padding (compact) | `theme.spacing.s` |
| Segment V-padding (full) | `theme.spacing.s` |
| Segment V-padding (compact) | `theme.spacing.xs` |
| Segment min-height (full) | 44pt |
| Segment min-height (compact) | `theme.spacing.l` |
| Active segment fill | `theme.colors.accentPrimary` (or `danger` for destructive modes like Flag) |
| Active segment text | `theme.colors.background` |
| Inactive text | `theme.colors.textPrimary` |
| Accessibility | Each segment: `.isButton` + `.isSelected` when active |

**When to include a mode pill:**
The pill appears when a game has two distinct interaction verbs that apply
to the same board tap (e.g. reveal vs flag). If only one verb exists (Merge's
swipe), no pill is shown. If the game has modes that are better changed at
setup than during play (e.g. Win vs Infinite in Merge), the pill appears
in the full off-path layout but is **omitted from the Video Mode large-zone
compact row** — changing game mode mid-round doesn't make sense.

### 3.5 Compact Control Row (Video Mode Large Zone)
Shared component: `VideoCompactControlRow` in `Core/`.

| Property | Value |
|----------|-------|
| Height | `theme.spacing.xl` (24pt) |
| H-padding | `theme.spacing.m` (inside the component) |
| Spacing between items | `theme.spacing.s` |
| Back button size | `theme.spacing.xl` × `theme.spacing.xl` |
| Restart button size | `theme.spacing.xl` × `theme.spacing.xl` |
| Button bg | `theme.colors.surface` |
| Button radius | `theme.radii.button` |

**Layout pattern:** `Back | primary-info-chip | [spacer] picker [spacer] | secondary-chip + restart`

**Rules:**
- All chips inside the row must use `compact: true`.
- Pass `EmptyView()` as the picker for games where mode-switching mid-game
  is semantically wrong. Do not omit the slot — pass empty.
- `onSettings: nil` (no gear icon) unless the game has no picker slot to
  carry the settings role.
- Never exceed `theme.spacing.xl` in any child's height. Use `compact: true`
  on all sub-components.

### 3.6 End-State Banner
Shared component: `VideoModeBanner` in `Core/`.

**Layout:** centered card, always shown in both Video Mode on and off.

| Slot | Content |
|------|---------|
| Title | Win / Game Over |
| Subtitle | Elapsed time (win) or reason (loss) |
| Primary CTA | Next puzzle / Restart |
| Secondary CTA | Game-specific change (Change difficulty / Change size / Retry) |
| Tertiary | "View board" — dismisses banner so player can inspect final state |

**Rules:**
- Never use a full-screen `EndStateCard` as the primary win/loss surface.
  `VideoModeBanner` is the standard going forward.
- Primary CTA is ALWAYS a single `DKButton`. Tapping the overlay backdrop
  does NOT trigger the primary action (D-11 lock).
- Delay before showing: 1500ms for win, 500ms for game over (when
  `settingsStore.animationsEnabled && !reduceMotion`). Show immediately
  if animations are off.
- Transition: `.opacity.combined(with: .scale(scale: 0.96))`. Collapses
  to `.identity` on Reduce Motion.
- Haptics on win: `.success` (if `hapticsEnabled`).

---

## 4. Typography Rules

| Use case | Token |
|----------|-------|
| Board numbers / given values | `theme.typography.title` or `theme.typography.headline` + `.weight(.semibold)` |
| Player-placed values | `theme.typography.title` (same size — board must stay visually consistent) |
| Pencil notes / marks | `theme.typography.caption` |
| Timer (all contexts) | `theme.typography.monoNumber` full; `theme.typography.caption` compact — always `.monospacedDigit()` |
| Chip labels | `theme.typography.body` full; `theme.typography.caption` compact |
| Mode pill labels | `theme.typography.headline` full; `theme.typography.body` compact |
| Screen titles (nav bar) | Default `navigationBarTitleDisplayMode(.inline)` |
| Empty state copy | `theme.typography.body` or `.callout` |
| Loading text | `theme.typography.body` |

**Rule:** Never use a monospaced font for anything except timers and numeric
game values where digit-width jitter would be visually disruptive. Avoid
bold weights on secondary content — weight communicates hierarchy.

---

## 5. Layout Rules

### 5.1 Standard game-screen structure
Every game view uses this ZStack / VStack skeleton:

```
ZStack {
    theme.colors.background.ignoresSafeArea()       // 1. background

    VStack(spacing: theme.spacing.s) {
        gameInfoRow                                  // 2. timer + lives (if applicable)
        boardView                                    // 3. board, layoutPriority(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, theme.spacing.m)
            .layoutPriority(1)
        modePillRow                                  // 4. mode pill + action buttons
        numberPadOrControls                          // 5. number pad or extra controls (if applicable)
    }
    .padding(.bottom, theme.spacing.l)

    endStateOverlay                                  // 6. win/loss banner (conditional)
}
```

### 5.2 Info row
- Timer is always on the **left**.
- Lives chip is always on the **right**.
- `Spacer()` between them so they hug their respective edges.
- No third element between timer and lives — if a game has a score/count,
  it goes in the toolbar or a separate header row.

### 5.3 Board
- Always `layoutPriority(1)` so the board wins any height conflict with chrome.
- Always `.padding(.horizontal, theme.spacing.m)` — the board must never
  bleed to the screen edges.
- Always `.frame(maxWidth: .infinity, maxHeight: .infinity)` — fill the
  available square.
- Board cells: minimum tap target 12pt cell dimension when Video Mode is on;
  game-specific floor off-path (Minesweeper 18pt, Nonogram 14pt, Sudoku: natural).

### 5.4 Mode pill row
When a game has a mode pill, it lives in a dedicated row between the board
and the number pad (or as the bottom control if no numpad). Structure:

```
ZStack(alignment: .center) {
    modePill                                         // truly centered
    HStack {
        Spacer()
        actionButton                                 // erase or flag button, trailing
    }
    .padding(.horizontal, theme.spacing.m)
}
.frame(maxWidth: .infinity)
```

The ZStack centers the pill regardless of the action button's width.

### 5.5 Number pads
- Digits or controls span the full available width (no 10th button off-axis).
- Remove/erase actions float **outside** the pad row so the pad items can
  space evenly.
- Exhausted digits dim to `theme.colors.textSecondary` and become `.disabled`.
  Show remaining count as a sub-label to spare the player mental tracking.

---

## 6. Navigation Rules

| Element | Placement | Size | Icon |
|---------|-----------|------|------|
| Back | `topBarLeading` | 44 × 44pt hit target | `chevron.backward` 18pt semibold |
| Restart | `topBarLeading` (paired with Back) | 44 × 44pt | `arrow.counterclockwise` 18pt semibold |
| Game menu (difficulty / mode) | `topBarTrailing` | 44 × 44pt | `ellipsis.circle` or `gearshape` |

**Rules:**
- `navigationBarBackButtonHidden(true)` on every game screen — always use
  the custom back chevron (the system back button doesn't match the app chrome).
- `.navigationBarTitleDisplayMode(.inline)` — no large titles on game screens.
- The game menu at trailing handles difficulty/mode selection. Never put
  difficulty chips or mode selection inline in the nav bar title area.
- Compact (Video Mode small zone) toolbar: difficulty menu collapses to icon-only
  (`compact: true` on toolbar menus) so it fits beside the PiP corner.

---

## 7. Video Mode Rules

### 7.1 Large zones (.largeTop / .largeBottom)
- Hide the nav bar entirely (`.toolbar(.hidden, for: .navigationBar)`).
- Replace it with `VideoCompactControlRow` or a game-specific equivalent
  following the §3.5 rules exactly.
- Compact row at the edge **opposite** the PiP band.
- Key game info that would be hidden in the compact row (e.g. lives, timer)
  moves to **board corner overlays** — `topLeading` for lives, `topTrailing`
  for timer — padded inside the board's horizontal margin.
- Board overlays are always `allowsHitTesting(false)`.

### 7.2 Small zones — info chips
- Show **at most 2 chips**: lives (if applicable) + timer.
- Never show the size/difficulty chip in small zones — the board makes the
  size apparent. Strip it out.
- Pack chips to the corner **opposite** the PiP:
  - PiP on left → chips on right (trailing)
  - PiP on right → chips on left (leading)

### 7.3 Small zones — mode picker
- Full-size mode pill in top-corner small zones (player taps it frequently;
  the vertical space is available).
- Compact mode pill in bottom-corner small zones (packed in the chrome cluster,
  vertical space is tight).

### 7.4 Small zones — bottom corners
- Board fills the top area. Chrome cluster (chips + compact pill) anchors in
  the bottom corner **opposite** the PiP.
- `padding(.bottom, smallPipFootprint)` or equivalent to clear the ~192pt PiP
  height — never use `theme.spacing.xxl` (32pt), it's far too small.

### 7.5 Cell-size floor (board games)
- Off-path minimum: game-specific (Minesweeper 18pt, Nonogram 14pt).
- Video Mode on: 12pt for all board games.
- Gated on `videoModeStore.isEnabled` only — not per-zone, not per-difficulty.

### 7.6 Off-path contract
- `videoModeStore.isEnabled == false` must be byte-identical to the non-Video
  Mode layout. No size changes, no layout shifts, no chip changes.

---

## 8. Haptic Design

### 8.1 Haptics carry information, not just feeling
Each haptic pattern in the vocabulary maps to a distinct event class. A
player who has played for ten minutes can close their eyes and feel the
difference between a safe cell reveal, a wrong move, and a win. That
differentiation is intentional and must be preserved — do not reuse the
same haptic for events that have different meanings or severity.

The haptic vocabulary is a shared language across all games. "This weight
means a normal move" is a promise the app makes to the player. Breaking that
promise in one game undermines trust in the whole suite.

### 8.2 Haptic vocabulary

All haptic events are gated on `settingsStore.hapticsEnabled`. Never fire
a haptic without checking this first.

| Class | Pattern | Meaning |
|-------|---------|---------|
| Normal move | `.impact(weight: .light, intensity: 0.7)` | Standard board interaction — placing a digit, revealing a safe cell, filling a Nonogram cell |
| Secondary action | `.selection` | A distinct but lesser interaction — adding a pencil note, flagging a cell, marking a Nonogram cell |
| Milestone completion | `.impact(weight: .medium, intensity: 1.0)` | A meaningful sub-goal reached — completing a Nonogram row/column, completing a Sudoku box |
| Wrong move | `.error` | An incorrect action with a consequence — wrong digit, hitting a mine, wrong fill |
| Mode toggle | `.impact(weight: .light)` | UI state change with no board consequence — switching Reveal/Flag, Value/Notes |
| Win | `.success` | Game complete — always exactly once per win, fires before the end banner appears |

**Rules:**
- Never fire two haptics simultaneously for the same event. If an event could
  map to two patterns, use the one that best represents the consequence
  (e.g. a cell that triggers both a placement AND a row completion fires
  `.medium` for the milestone, not both).
- The trigger is always an incrementing view-model counter (`placeCount`,
  `wrongAttemptCount`, `winCount`, etc.), never a Bool toggle. Booleans miss
  rapid double-fires; counters do not.
- Attach `.sensoryFeedback` to the board view, not to individual cells or
  buttons. One attachment point per event class per game view.

### 8.3 Designing new haptics
When adding a new game interaction, answer these questions before writing code:

1. **What class does this event fall into?** (normal move, secondary, milestone,
   wrong, toggle, win) — use the existing vocabulary, don't invent new weights.
2. **Is the haptic fired once per user action, or once per event outcome?**
   (e.g. if the user places a digit that happens to complete a box, fire the
   milestone haptic, not both milestone + placement)
3. **Does the player expect physical confirmation for this action?** If yes,
   it must fire even without animation. Haptics and animations are independent
   — turning off animations must not silence haptics.
4. **Can this fire on rapid repeat?** If so, test that the counter-trigger
   approach handles it correctly and doesn't coalesce haptics.

---

## 9. Accessibility

Every interactive element must have an `.accessibilityLabel`. Every
informational view that contains multiple sub-elements should use
`.accessibilityElement(children: .ignore)` plus a single composed label.

| Component | Rule |
|-----------|------|
| Back button | `"Back to The Drawer"` |
| Restart button | `"Restart puzzle"` / `"Restart game"` (game-specific) |
| Erase button | `"Erase"` |
| Lives chip | `.accessibilityElement(children: .ignore)`, label `"X of Y lives remaining"` |
| Timer chip | label `"Time elapsed"`, value spoken as "X minutes Y seconds" |
| Mode pill segments | `.isButton` + `.isSelected` on the active segment |
| Number pad digits | `"Place N, M remaining"` |
| Board cells | Game-specific, includes cell state (empty / given / placed / flagged) |

Dynamic Type: all text views must respond to Dynamic Type scaling unless
the view is inside a fixed-height chip that would break layout. In those
cases, use `minimumScaleFactor` rather than disabling Dynamic Type entirely.

---

## 10. Animation Design

### 10.1 Animations explain causality, not just change state
An animation is not decoration. It is an explanation: "this happened,
and it led to that." The win-sweep wash says "you won." The board shake
says "that move was wrong." Confetti says "celebrate." Without these, state
changes are abrupt and cold — the banner just appears, no story.

Design animations as the visual counterpart to haptics. A wrong move is:
haptic (`.error`) + animation (shake) + visual state (lives decrement).
All three reinforce the same message. No single element carries the full
weight — they work as a layer.

### 10.2 Animation vocabulary

All animations that are not strictly functional (i.e., all animations that
exist to express delight, consequence, or mood) must be completely suppressed
when `accessibilityReduceMotion == true` OR `settingsStore.animationsEnabled == false`.
Use a Bool gate on the trigger. Hard-cutting is correct — do not substitute
a "softer" or "reduced" animation. Skip it entirely.

| Class | Animation | When | Gate |
|-------|-----------|------|------|
| Wrong move | 4-keyframe horizontal shake, 8pt magnitude, 0.1s/frame | Immediately on wrong action | `reduceMotion` + `animationsEnabled` |
| Win wash | `.phaseAnimator([0, 0.25, 0])` easeInOut `theme.motion.slow`, success tint | Immediately on win, before banner | both |
| Confetti | `ConfettiView`, `.opacity` transition, fires before banner | Win only | both |
| End-state appear | `.easeOut(duration: 0.3)` + `.opacity.combined(with: .scale(0.96))` | After win/loss pre-roll delay | `animationsEnabled` only (the overlay itself is functional) |
| Mode pill transition | Active-segment thumb slides via `matchedGeometryEffect`, `.spring(response: 0.3, dampingFraction: 0.82)` | Mode toggle | both (hard-cut to instant) |
| Chip count update | Numeric roll via `.contentTransition(.numericText(value:))` + `theme.motion.ease` | Any counter change (score, best, mines, found words) | both (hard-cut to instant) |
| Press feedback | `PressableButtonStyle` (`Core/`) — scale 0.94 (0.97 large surfaces) + slight dim, spring back on release | Finger down on pads, keyboards, Home tiles | both (dim stays; scale cuts) |
| Tile slide (Merge) | Position glide keyed by `MergeTile.id`, `.spring(response: 0.24, dampingFraction: 0.9)`; spawn scales in delayed 90ms; merged tile pops 1.15× keyframe | Every swipe | both (hard-cut to instant) |
| Placement pop | Placed value scales in (`.scale(0.55) + .opacity` transition, spring ~0.25s) — Sudoku digits, Five Letter typing (1.12× keyframe) | On placement / letter entry | both |
| Guess reveal (Five Letter) | Mark colors sweep the row left→right, `theme.motion.normal` easeInOut, 60ms/column stagger | On guess submit | both |

The shared gate idiom is `feedbackAnimation(_:value:)` (`Core/MotionGate.swift`)
— it reads both gates from the environment so props-only leaf views stay
prop-driven. Imperative `withAnimation` call sites read the same two
environment values and pass `nil` when gated.

### 10.3 Pre-roll sequencing
Significant end states have a deliberate delay before the banner appears.
This gives the animation a moment to breathe and the player a moment to
absorb what happened before being prompted to act.

| Outcome | Pre-roll | What plays during |
|---------|----------|-------------------|
| Win | 1500ms | Win wash + confetti |
| Game over | 500ms | Board settle (no wash or confetti) |

If animations are disabled, pre-roll is skipped — the banner appears
immediately. Never add a `Task.sleep` for the sole purpose of artificial
delay when animations are off.

### 10.4 Animation does not carry exclusive information
A player with animations disabled must still understand everything that
happened. Meaning must always exist in the visual state (color, icon,
text) independently of animation. Examples:
- Wrong-move shake: the lives chip already decrements and the cell may flash
  `danger` color — the shake is additional emphasis, not the only signal.
- Win wash: the end banner fully communicates the win — the wash is a mood
  layer.
- Confetti: purely celebratory — no information content.

If removing an animation would leave the player unable to understand what
happened, the animation is carrying information it shouldn't. Fix the static
visual state first, then add the animation on top.

### 10.5 Designing new animations
When adding a new game state or interaction, answer these questions:

1. **Is this a consequential state change?** (wrong move, milestone, win, loss)
   — It should have an animation. Lightweight UI state changes (mode toggle,
   press feedback) get the short micro-motions in the §10.2 vocabulary —
   never longer than ~0.3s, never blocking input. Anything beyond that
   (flourishes on simple taps) is decoration and should be cut.
2. **What does the animation communicate?** Write the sentence. "This
   animation says: ___." If you can't fill in the blank, the animation
   is decoration and should be cut.
3. **What is the Reduce Motion / animations-off fallback?** State it
   explicitly. Usually: immediate cut to the new state.
4. **Does it compound with haptics?** Map the animation to its haptic
   counterpart in §8.2 — they should fire as a unit.
5. **Does it respect the pre-roll sequence?** If it plays before the end
   banner, confirm it completes before the banner appears.

### 10.6 The compound rule
Every significant event gets a feedback triple — visual state change,
haptic, animation. Document all three when designing a new event.

| Event | Visual | Haptic | Animation |
|-------|--------|--------|-----------|
| Normal move | Cell fills / digit appears | `.light(0.7)` | Placement pop (§10.2) |
| Wrong move | Cell flashes `danger`, lives decrement | `.error` | Board shake |
| Row/box completion | Hint row/col dims or highlights | `.medium(1.0)` | Optional flash |
| Win | Board locks, end banner queues | `.success` | Wash + confetti → banner |
| Loss | Board locks, end banner queues | None (error already fired on last wrong move) | Banner only |
| Mode toggle | Pill segment activates | `.light` | Thumb slides (§10.2) |

---

## 11. Empty States and Loading

Every screen that loads data asynchronously must have an explicit loading
and empty state — no blank white rectangles, no silent spinner.

**Loading pattern:**
```swift
if viewModel.board != nil {
    boardView
} else {
    Spacer()
    Text(String(localized: "Loading puzzle…"))
        .font(theme.typography.body)
        .foregroundStyle(theme.colors.textSecondary)
    Spacer()
}
```

**Empty fallback (no content bundled):**
```
"No puzzles bundled yet"   — Nonogram / Sudoku style
"No games played yet."     — Stats screens
"No best times for Hard."  — Per-difficulty best-time cards
```

Spacer() above and below centered text, so it appears vertically centered
in the available space. Never show an empty container.

---

## 12. Game-Specific Rules

These rules capture decisions that are specific to individual games but
must remain consistent across updates, Video Mode changes, and new phases.
When in doubt, check these before changing chrome for a specific game.

### 12.1 Minesweeper
- No lives chip — Minesweeper has no lives mode; first touch is always safe.
- Mode pill: Reveal / Flag. Always present during active play; hidden on terminal state.
- Difficulty changes via toolbar menu (restartWithOverflowMenu in Video Mode).
- Cell minimum: 18pt off-path, 12pt Video Mode on.
- The MagnifyGesture / pinch-zoom stack in `MinesweeperBoardView` must never
  be touched when making Video Mode or layout changes (D-17 contract).
- First-tap safety: mine placement deferred until after first tap; tapped cell
  + 8 neighbors excluded. A first-tap loss is a P0 bug.

### 12.2 Merge
- Mode pill (Win / Infinite): shown in full off-path layout.
- **Video Mode large-zone compact row: no mode picker.** Switching Win/Infinite
  mid-game doesn't make sense — the mode picker is omitted (pass `EmptyView()`
  as the picker slot). Mode change remains accessible via the Restart overflow menu.
- No timer chip — Merge has no timed play.
- No lives chip — Merge has no lives mode.
- Swipe-driven board: the `MergeBoardView` swipe gesture stack must never be
  modified when making Video Mode or layout changes (D-MG-17 contract).

### 12.3 Nonogram
- Lives chip: `NonogramLivesChip`, hearts, only when `gameMode == .lives`.
- Small Video Mode zones: show lives + timer only — NOT the size chip.
- Large Video Mode zones: single-slot size↔lives swap in compact row slot 2
  (D-NG-01). In Free mode: size chip. In Lives mode: lives chip. Never stack
  them.
- The slide gesture / super-cell rules / hint geometry in `NonogramBoardView`
  must never be touched when making Video Mode or layout changes (D-NG-17).

### 12.4 Sudoku
- Lives chip: `SudokuLivesChip`, hearts (`heart.fill`/`heart`), only when
  `gameMode == .lives`. Identical visual treatment to `NonogramLivesChip`.
- Large Video Mode zones: lives chip overlays board **top-leading** corner;
  timer chip overlays board **top-trailing** corner. Both `compact: true`,
  both `allowsHitTesting(false)`, padded inside the board's horizontal margin.
- Mode pill: Value / Notes. Always present during active play.
- Number pad: digits span full pad width; erase floats trailing in the mode-pill
  row, NOT as a 10th pad button.
- Remaining-count badge under each digit: dims to `textSecondary` and disables
  when count reaches 0.

### 12.6 Stack
- Video Mode: adopted (15-VIDEO-MODE-ADR.md amendment 2026-07-02). `StackGameView`
  carries `.videoModeAware(minBoardHeight: 480)`. Stack's engine is pure
  normalized-coordinate — the canvas rescales per frame, so a PiP reflow cannot
  desync state (amendment rationale).
- No lives chip. No timer chip. Score chip: `StackScoreChip` (compact: true in
  Video Mode compact row slot 2, alongside `StackStreakChip`).
- Per-layer accent ramp (16-CONTEXT D-05/D-07): block color cycles through
  `accentPrimary → accentSecondary → success → …` via `StackPalette` — never
  hardcoded. Board background = `background` token (DESIGN.md §2).
- Perfect-drop celebration (16-CONTEXT D-08): color pulse/glow + light haptic tick
  + animated combo-streak counter. Gated by `hapticsEnabled` + `feedbackAnimation`.
  Reduce Motion: pulse collapses to instant fill; no glow.
- Game-over choreography (16-CONTEXT D-09): ~0.5 s slow-mo on losing final block +
  tower fade + banner. Game-over banner = `danger` token (DESIGN.md §2: danger =
  errors/game-over). Reduce Motion: instant cut to `danger`-token banner. No screen
  shake (brand rule). View-tier `@Environment(\.accessibilityReduceMotion)` only —
  engine/VM never read the accessibility flag.
- Haptic vocabulary: normal block land = `.impact(weight: .light)`; perfect drop =
  distinct `.light` tick; game over = `.error`. No per-frame haptics ever.
- Stats shape: `StackStatsCard` (Phase 18 D-08). Hero = High Score; rows = Average
  Score + Runs Played + Best Streak (Stack-only, persisted via `"perfectStreak"`
  BestScore row, 16-CONTEXT D-10/D-11).

### 12.7 Snake
- Video Mode: **exempt** (15-VIDEO-MODE-ADR.md, Accepted 2026-06-26). Pixel-derived
  grid cells + continuous steering — a PiP reflow mid-run would snap the snake to a
  different cell position and desync state. `SnakeGameView` has no `.videoModeAware`
  modifier. Snake remains exempt after the 2026-07-02 Stack amendment.
- No lives chip. No timer chip. Score chip: `SnakeScoreChip` (no compact row —
  exempt from Video Mode, no compact variant needed).
- Body ramp (17-CONTEXT D-02): head = `accentPrimary`; body segments fade toward
  `surface` via opacity steps. Food = `success` (green) or `accentPrimary` fallback.
  Board background = `background` token (DESIGN.md §2).
- Direction input (17-CONTEXT D-04): swipe gesture + optional D-pad overlay. One
  direction lock per tick — reversal rejected silently (no haptic for rejected input).
- Haptic vocabulary (17-CONTEXT D-07/D-08/D-09/D-10): valid direction = `.selection`;
  food eaten = `.impact(weight: .light)`; new high score mid-run = `.success` once
  per run (17-CONTEXT D-09); game over = `.error`. Per-frame haptics: none.
- Death + eat animations gated by `feedbackAnimation` / `hapticsEnabled`. Reduce
  Motion: death drain + eat animations cut instantly to banner/state (no screen
  shake — brand rule). View-tier `@Environment(\.accessibilityReduceMotion)` only.
- Stats shape: `SnakeStatsCard` (Phase 18 D-08). Hero = High Score; rows = Average
  Score + Runs Played. No streak row (streak is Stack-only per 16-CONTEXT D-10).

### 12.5 Future games
When adding a new game, verify against this checklist:
- [ ] Lives chip uses hearts if the game has a lives mode.
- [ ] Timer uses `VideoModeTimerChip` from `Core/`.
- [ ] Mode pill (if applicable) follows the §3.4 spec.
- [ ] End state uses `VideoModeBanner`.
- [ ] Video Mode: `videoModeAware` modifier applied; compact row uses §3.5 rules.
- [ ] Board has `layoutPriority(1)` and `m` horizontal padding.
- [ ] Wrong move fires `.error` haptic; win fires `.success`.
- [ ] All interactive elements have `accessibilityLabel`.
- [ ] Verified legible on Classic (Chrome Diner) AND at least one Loud preset
      (Voltage or Dracula) per CLAUDE.md §8.12.
- [ ] No hardcoded colors, radii, or spacing literals.

---

## 13. What Does NOT Go Here

This document governs visual and interaction design. It does not duplicate:
- Code architecture rules → `CLAUDE.md`
- Release process → `Docs/releases/`
- Phase plans → `.planning/phases/`
- Token definitions → `DesignKit`

Changes to component shapes, color semantics, or layout patterns defined
here must update this document in the same commit as the code change. Stale
design rules mislead every future session.
