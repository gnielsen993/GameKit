# Icon Provenance (P7 Plan 07-02)

AI service used: ChatGPT image generation (DALL·E 3)
Initial generation: 2026-04-27 (outline-stencil)
Revision 1: 2026-04-29 (filled colorful arcade cabinet, "GameKit" CRT)
Revision 2: 2026-04-30 morning (PixelParlor — Cream Hero arcade cabinet, FT-teal trim)
Revision 3: 2026-04-30 evening (PlayCore — Stack of Three Games, FT-teal box) — CURRENT
Subject lineage: "old school arcade machine" → restomod cream-hero cabinet → stack of three game boxes (away from arcade-genre signal toward calm-classic-suite signal)

## Naming history (display-name only, bundle ID unchanged throughout)

- `GameKit` — internal/repo name only, never shipped externally
- `PixelParlor` — chosen 2026-04-30 morning, rejected same day. Retro/arcade connotation conflicted with the actual product (Sudoku, Minesweeper, Solitaire — calm logic puzzles, not arcade)
- `PlayCore` — current display name as of 2026-04-30 evening. Calm, modern, neutral, doesn't lock genre

`INFOPLIST_KEY_CFBundleDisplayName = PlayCore` in Debug + Release. Bundle ID
`com.lauterstar.gamekit` and target name `gamekit` unchanged per CLAUDE §1.

## Approval (2026-04-30 evening — Revision 3 PlayCore)

User approved final PlayCore stack candidates after iterating away from
the PixelParlor arcade-cabinet direction (genre-mismatch with the logic-
puzzle product). New primary icon = three stacked board-game boxes with
parallel-oblique projection, varied widths, embossed abstract patterns
on front faces (3×3 dot grid for puzzle-grid signal, ♠ spade for cards,
2×2 mini checker for chess/strategy).

Three appearance variants placed:
- Light: stack on light cream/iOS-light bg
- Dark: stack on iOS-dark charcoal bg
- Tinted: white outline-stencil of the stack on transparent bg, with
  filled white pattern glyphs (dots, spade, half-checker) for
  recognition under iOS system tinting

Generated alongside as a marketing-only asset:
- Promo-stack-3d: grey-gradient bg with 3D-shaded glowing stack. NOT
  placed in any iOS slot — saved at `assets/icon/source/promo-stack-3d.png`
  for App Store hero / README header / marketing site use. iOS tinted
  appearance would tint-wash this colored gradient image to mush; it
  exists only as a press-kit asset.

Tinted candidate from this revision arrived as a 1024×1536 portrait PNG
with extensive soft-glow halo; center-cropped to 1024×1024 square via
Pillow before placement. All four corners verified alpha-zero post-crop.

> Earlier approvals preserved for audit:
> - 2026-04-27: outline-stencil cabinet candidates (Task 2 [BLOCKING] CHECKPOINT)
> - 2026-04-29: filled colorful arcade cabinet (in-session approval)
> - 2026-04-30 morning: PixelParlor cream-hero cabinet (placed, then superseded by stack)

Master path chosen (Discretion #4): raster

Final masters live at `assets/icon/source/{light,dark,tinted}.png` (1024×1024 sRGB).
Plus `assets/icon/source/promo-stack-3d.png` for marketing use (not an iOS slot).

PixelParlor arcade-cabinet renders preserved as alternate-icon source files at:
- `assets/icon/alternates/arcade/arcade-light.png`
- `assets/icon/alternates/arcade/arcade-dark.png`
- `assets/icon/alternates/arcade/arcade-tinted.png`

These can be wired as an alternate app icon (iOS supports alternates via
`UIApplicationAlternateIcons` + `setAlternateIconName` API) post-launch if
the arcade direction returns as a user-selectable theme.

Light + dark stack candidates were generated at 1254×1254 and downscaled to
1024×1024 via `sips -z 1024 1024` (preserves sRGB; no quality loss perceptible
at the icon-size scales the AppIcon slot is rendered at).

## Final renders

`gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png` — light slot (PlayCore stack on cream/iOS-light bg, 2026-04-30 evening)
`gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-dark.png` — luminosity-dark slot (PlayCore stack on iOS-dark charcoal bg, 2026-04-30 evening)
`gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-tinted.png` — tinted slot (PlayCore stack outline-stencil, transparent bg, white filled pattern glyphs, 2026-04-30 evening)

`Assets.xcassets/AppIcon.appiconset/Contents.json` UNCHANGED (P1 wiring already
correct for the 3-slot layout).

## Final prompts (saved for v1.0.x re-export reproducibility)

> **Revision 2026-04-30 evening (PlayCore — Stack of Three Games):**
> direction shift away from arcade-cabinet imagery (genre-mismatch with
> the actual logic-puzzle product). Display name PixelParlor → PlayCore.
> Primary icon = three stacked board-game-style boxes in parallel-oblique
> projection (~15° turn), bottom widest tapering to top narrowest, each
> with an embossed abstract pattern on the front face: 3×3 dot grid
> (puzzle/Sudoku signal), ♠ spade silhouette (cards/Solitaire signal),
> 2×2 mini checker (chess/strategy signal). Brand thread preserved from
> previous revisions: cream + FT-teal + diner-red + brushed-gunmetal trim.
> Light variant on iOS-light cream bg; dark variant on iOS-dark charcoal
> bg; tinted variant is white outline-stencil with filled white pattern
> glyphs on transparent bg. PixelParlor cabinet prompts archived below.
> Cabinet renders preserved as alternate-icon source at
> `assets/icon/alternates/arcade/`.

### Light variant

```
A flat 2D vector app icon, 1024x1024 pixels, full-bleed square, no rounded
corners on the canvas, no border.

BACKGROUND
Light mode iOS app icon background. Smooth, polished, off-white — the
kind of background you see on a system app icon in light mode on iOS 18.

COMPOSITION — PRIMARY RULE
The icon is dominated by negative space. A small stack of three board-
game boxes sits centered with generous bg space surrounding it. The
stack occupies approximately 40–50% of the canvas height. It must never
touch or approach the edges. Think: calm, balanced, premium — not
crowded.

SUBJECT
Three classic-board-game-style boxes stacked on top of each other in
a gentle parallel-oblique projection (~15-degree turn, parallel lines
only, no vanishing point, no foreshortening, no perspective
convergence). The stack tapers — bottom box is widest, top box is
narrowest. Each box rendered with three visible faces:
  - FRONT face: flat rectangle, carries the box's primary color and
    an embossed pattern (described below).
  - SIDE PANEL: parallelogram running back at the ~15-degree angle,
    filled in a darker shadow tone of the box's color. NO pattern.
  - TOP LID: thin parallelogram visible at the top of each box,
    filled in the same primary color as the front. NO pattern.

The boxes touch (stacked, no gaps). All corners sharp 90-degree angles.

STACK PROPORTIONS (bottom → top)
  1. Bottom box (widest, tallest):
       - Front: warm CREAM (#F2E8D0), side shadow cream (#D9C9A8)
       - Width ~100% of stack, height ~40% of stack
       - Pattern on front face: 3-by-3 grid of nine small filled
         DOTS in brushed gunmetal (#3A3A40). Reads as puzzle/Sudoku
         signal.
  2. Middle box (medium):
       - Front: FT teal (#14B8A6), side deep teal (#0F766E)
       - Width ~80% of stack, height ~33% of stack
       - Pattern on front face: a single SPADE silhouette (♠ shape),
         filled cream (#F2E8D0), centered, ~40% of front face area.
         Reads as cards/Solitaire signal.
  3. Top box (narrowest, smallest):
       - Front: diner-red (#C8323C), side deep oxblood (#7F1D1D)
       - Width ~60% of stack, height ~27% of stack
       - Pattern on front face: a 2-by-2 MINI CHECKERBOARD (4 cells
         only, alternating diner-red #C8323C and cream #F2E8D0).
         Reads as chess/strategy signal.

TRIM
Every box outline — front, side, top lid — uses a uniform brushed
gunmetal stroke (#3A3A40), exactly 12 pixels wide at 1024 resolution.
Consistent stroke width on every panel of every box. No tapering.

RENDERING RULES
Flat 2D vector. Boxes, patterns, and outlines are all flat — no
gradients on any of them, no soft shadows, no glow blur, no 3D
shading beyond the flat parallel-oblique side panels, no specular
highlights, no textures, no scuffs, no realistic box-photo detail,
no text, no wordmarks, no logos.

PALETTE — STRICT, no other colors on the boxes:
  Bottom box      #F2E8D0   cream (front + lid)
  Bottom shadow   #D9C9A8   shadow cream (side panel)
  Middle box      #14B8A6   FT teal (front + lid)
  Middle shadow   #0F766E   deep teal (side panel)
  Top box         #C8323C   diner-red (front + lid)
  Top shadow      #7F1D1D   deep oxblood (side panel)
  Trim/outlines   #3A3A40   brushed gunmetal (uniform 12px stroke)
  Bottom pattern  #3A3A40   gunmetal dots (3x3 grid)
  Middle pattern  #F2E8D0   cream spade
  Top pattern     #C8323C + #F2E8D0   alternating 2x2 checker

Output: 1024x1024 pixels, sharp edges, vector-clean.
```

### Dark variant

```
A flat 2D vector app icon, 1024x1024 pixels, full-bleed square, no rounded
corners on the canvas, no border.

BACKGROUND
Dark mode iOS app icon background. Smooth, polished, charcoal — the kind
of background you see on a system app icon in dark mode on iOS 18.

COMPOSITION — PRIMARY RULE
The icon is dominated by negative space. A small stack of three board-game
boxes sits centered with generous bg space surrounding it. The stack
occupies approximately 40–50% of the canvas height. It must never touch
or approach the edges. Think: calm, balanced, premium — not crowded.

SUBJECT
Three classic-board-game-style boxes stacked on top of each other in
a gentle parallel-oblique projection (~15-degree turn, parallel lines
only, no vanishing point, no foreshortening, no perspective
convergence). The stack tapers — bottom box is widest, top box is
narrowest. Each box rendered with three visible faces:
  - FRONT face: flat rectangle, carries the box's primary color and
    an embossed pattern (described below).
  - SIDE PANEL: parallelogram running back at the ~15-degree angle,
    filled in a darker shadow tone of the box's color. NO pattern.
  - TOP LID: thin parallelogram visible at the top of each box,
    filled in the same primary color as the front. NO pattern.

The boxes touch (stacked, no gaps). All corners sharp 90-degree angles.

STACK PROPORTIONS (bottom → top)
  1. Bottom box (widest, tallest):
       - Front: warm CREAM (#F2E8D0), side shadow cream (#D9C9A8)
       - Width ~100% of stack, height ~40% of stack
       - Pattern on front face: 3-by-3 grid of nine small filled
         DOTS in brushed gunmetal (#3A3A40). Reads as puzzle/Sudoku
         signal.
  2. Middle box (medium):
       - Front: FT teal (#14B8A6), side deep teal (#0F766E)
       - Width ~80% of stack, height ~33% of stack
       - Pattern on front face: a single SPADE silhouette (♠ shape),
         filled cream (#F2E8D0), centered, ~40% of front face area.
         Reads as cards/Solitaire signal.
  3. Top box (narrowest, smallest):
       - Front: diner-red (#C8323C), side deep oxblood (#7F1D1D)
       - Width ~60% of stack, height ~27% of stack
       - Pattern on front face: a 2-by-2 MINI CHECKERBOARD (4 cells
         only, alternating diner-red #C8323C and cream #F2E8D0).
         Reads as chess/strategy signal.

TRIM
Every box outline — front, side, top lid — uses a uniform brushed
gunmetal stroke (#3A3A40), exactly 12 pixels wide at 1024 resolution.
Consistent stroke width on every panel of every box. No tapering.

RENDERING RULES
Flat 2D vector. Boxes, patterns, and outlines are all flat — no
gradients on any of them, no soft shadows, no glow blur, no 3D
shading beyond the flat parallel-oblique side panels, no specular
highlights, no textures, no scuffs, no realistic box-photo detail,
no text, no wordmarks, no logos.

PALETTE — STRICT, no other colors on the boxes:
  Bottom box      #F2E8D0   cream (front + lid)
  Bottom shadow   #D9C9A8   shadow cream (side panel)
  Middle box      #14B8A6   FT teal (front + lid)
  Middle shadow   #0F766E   deep teal (side panel)
  Top box         #C8323C   diner-red (front + lid)
  Top shadow      #7F1D1D   deep oxblood (side panel)
  Trim/outlines   #3A3A40   brushed gunmetal (uniform 12px stroke)
  Bottom pattern  #3A3A40   gunmetal dots (3x3 grid)
  Middle pattern  #F2E8D0   cream spade
  Top pattern     #C8323C + #F2E8D0   alternating 2x2 checker

Output: 1024x1024 pixels, sharp edges, vector-clean.
```

### Tinted variant

```
A flat 2D vector app icon, 1024x1024 pixels, fully transparent PNG
background (no fill color anywhere). Square canvas.

CRITICAL TRANSPARENCY RULE
ONLY the white shapes (strokes and filled glyphs described below) are
opaque white. Everything else — the canvas around the stack, inside
the box outlines, behind every shape — is fully transparent
(alpha = 0). This file will be tinted by iOS based on its luminance,
so any background fill at all will produce a colored bg under iOS
tint mode and break the icon. Verify alpha = 0 in all empty regions.

COMPOSITION — PRIMARY RULE
The icon is dominated by negative (transparent) space. A small stack
of three nested-size box outlines sits centered with generous
transparent space surrounding it. The stack occupies approximately
40–50% of the canvas height. It must never touch or approach the
edges.

SUBJECT
Outline-style stencil of three stacked box silhouettes — SAME
composition as the PlayCore light and dark variants. Gentle parallel-
oblique projection (~15-degree turn, parallel lines only, no vanishing
point, no foreshortening, no perspective convergence). The stack
tapers — bottom box widest, top box narrowest. Each box rendered with
three visible faces (front rectangle, side parallelogram, top
parallelogram) — but ALL FACES are outline-only, hollow interior, no
fill.

STACK PROPORTIONS (bottom → top)
  1. Bottom box: ~100% stack width, ~40% stack height (widest, tallest)
  2. Middle box: ~80% stack width, ~33% stack height (centered)
  3. Top box: ~60% stack width, ~27% stack height (narrowest, smallest)

The three boxes touch (stacked, no gaps). All corners sharp 90-degree
angles.

STROKES
Every line — front rectangles, side parallelograms, top parallelograms,
and the patterns described below — is a uniform solid WHITE stroke
(#FFFFFF), about 24 pixels wide at 1024 resolution. No tapering, no
thinning at corners, no variation between elements.

PATTERNS ON FRONT FACES (opaque white shapes — recognition anchors)
  Bottom box front face: 3-by-3 grid of nine small SOLID FILLED WHITE
    CIRCLES (dots), centered. Filled, not outlined. Same dot size for
    all nine. Reads as puzzle/Sudoku signal.
  Middle box front face: a single SOLID FILLED WHITE SPADE silhouette
    (♠ shape), centered, ~40% of the front face area. Filled, not
    outlined. Reads as cards/Solitaire signal.
  Top box front face: 2-by-2 mini checkerboard — exactly 4 cells.
    TOP-LEFT and BOTTOM-RIGHT cells are SOLID FILLED WHITE; TOP-RIGHT
    and BOTTOM-LEFT cells are EMPTY/TRANSPARENT (just bordered by
    the surrounding box outline and a thin white internal grid line
    separating them). Reads as chess/strategy signal.

NO PATTERNS on side panels or top lids — front faces only.

RENDERING RULES
Flat 2D, single solid white tone (#FFFFFF) for every visible element.
No gradients, no soft shadows, no glow blur, no 3D shading, no
specular highlights, no textures, no scuffs, no text, no wordmarks,
no logos.

PALETTE — ABSOLUTE
  Strokes & filled glyphs:  #FFFFFF  (pure white, fully opaque)
  Everything else:          alpha = 0  (fully transparent)
NO other colors. NO grey. NO off-white. Pure white or fully
transparent — nothing in between.

FINAL CHECK
- Background fully transparent — verify alpha = 0 in every corner
  and inside all box hollow interiors (between the strokes)
- All strokes uniform 24px white
- Three boxes clearly nested with varied widths
- Three patterns (dots / spade / 2x2 checker) on front faces only
- Stack silhouette readable at small sizes (60pt home screen)
- No fills inside box bodies — only the strokes and the pattern
  glyphs are opaque
- System tinting must wash this silhouette cleanly to any color
```

---

## Archived prompts

### Revision 2026-04-30 morning — PixelParlor Cream Hero Cabinet

Same boxy arcade-cabinet shape as the 2026-04-29 prompts (below) with a
cream-hero recolor and PlayCore-family brand thread, used briefly during
the rejected PixelParlor naming phase before the stack pivot. Preserved
as the source for the future alternate "Arcade" app icon.

**Renders:** `assets/icon/alternates/arcade/arcade-{light,dark,tinted}.png`
(1024×1024, ready to wire as `UIApplicationAlternateIcons`).

**Recolor delta vs 2026-04-29 prompts:**
- Cabinet body: cream `#F2E8D0` (was crimson)
- Body trim/outline: FT teal `#14B8A6`, uniform 12px (was white/cyan)
- Marquee fill: cream `#F2E8D0` matching body (light variant: gunmetal `#3A3A40`)
- Side panel: shadow cream `#D9C9A8` (was darker red)
- Base: deep teal `#0F766E` (was deep red)
- Control panel: brushed gunmetal `#3A3A40` (light variant: cream)
- Joystick: red `#FF3B3B` (kept — diner-red brand thread)
- CRT wordmark: "PIXEL PARLOR" magenta `#EC4899`, single line or stacked
- CRT "PRESS START": amber `#F59E0B` in white pixel border
- Three buttons: teal `#14B8A6`, magenta `#EC4899`, amber `#F59E0B`

**Shape deltas vs 2026-04-29:**
- Parallel oblique angle: ~15° (was ~20°, less chunky)
- CRT aspect: ~4:3 (was ~5:3 wide letterbox)
- Base height = marquee height (visual balance)
- Framing language: "occupies 40–50% canvas height" + negative-space-as-
  subject (was "center 60% of frame" — the old phrasing produced
  oversized renders)

To regenerate: take the 2026-04-29 light/dark/tinted prompts below and
apply both delta sets.

### Revision 2026-04-29 — filled colorful cabinet, "GameKit" CRT, ~20° side

Pre-PixelParlor rebrand. Kept for diff reference.

#### Light variant

```
A flat 2D vector app icon, full-bleed square, edge-to-edge solid pure black
background (#000000), no rounded corners on the canvas, no border. Centered
filled illustration of a classic vintage arcade cabinet that POPS off the
black with bold saturated color. BOXY rectangular construction: rectangular
body filled bright cherry red (#E11D2E) with a thin white outline (about 12
pixels wide at 1024); flat rectangular marquee at top filled warm yellow
(#FFC727) with red outline (marquee is empty — no text); square CRT screen
with a black background showing a retro start screen — the word "GameKit"
in pixel-block letters, bright cyan (#22D3EE), centered upper-third of the
screen; below it a smaller pixel-block button reading "PRESS START" in
yellow (#FACC15) inside a thin white pixel border; tiny scanline texture
optional. The text "GameKit" and "PRESS START" appear ONLY inside the CRT
screen — nowhere else on the cabinet. Horizontal control panel slab in
pale cream (#F5E9D0); on the panel a glossy red bulb joystick (#FF2E2E
ball with a black stick) and three small round buttons in cyan (#22D3EE),
yellow (#FACC15), and lime (#84CC16). Flat rectangular base in deep red
(#7F1D1D). All corners sharp 90-degree angles. Subtle three-quarter angle
in parallel oblique projection — left side panel visible at ~20-degree
turn, parallel lines only, no vanishing point, no foreshortening, no
perspective convergence. Front face = flat rectangle; side panel =
parallelogram running back-left at a constant angle, filled darker red
(#9F1D24). Flat 2D, no gradients, no soft shadows, no glow blur, no 3D
shading. Generous negative space, cabinet occupies center 60% of frame.
1024x1024 pixels.
```

#### Dark variant

```
A flat 2D vector app icon, full-bleed square, edge-to-edge solid pure black
background (#000000), no rounded corners on the canvas, no border. Centered
filled illustration of the SAME boxy vintage arcade cabinet from the light
variant — SAME proportions, SAME composition, SAME parallel oblique
projection (left side panel visible at the same ~20-degree turn, parallel
lines only, no vanishing point). Cabinet body filled deeper crimson red
(#B91C1C) with a luminous neon-cyan outline (#22D3EE, about 12 pixels
wide at 1024); marquee filled warm amber (#F59E0B) with cyan outline
(marquee is empty — no text); square CRT screen with a black background
showing a retro start screen — the word "GameKit" in pixel-block letters,
neon magenta (#EC4899), centered upper-third of the screen; below it a
smaller pixel-block button reading "PRESS START" in neon cyan (#22D3EE)
inside a thin white pixel border. Text appears ONLY inside the CRT —
nowhere else on the cabinet. Control panel slab in muted cream (#E7DAB8);
glossy red bulb joystick (#FF3B3B) with black stick; three round buttons
in neon cyan (#22D3EE), neon magenta (#EC4899), and lime (#84CC16). Side
panel parallelogram filled darker oxblood (#7F1D1D). Sharp 90-degree
corners on every element. Flat 2D, no gradients, no soft shadows, no glow
blur, no 3D shading. Cabinet occupies center 60% of frame. 1024x1024
pixels.
```

#### Tinted variant

```
A flat 2D vector app icon, fully transparent PNG background (no fill color
anywhere), 1024x1024 pixels. Centered outline-style stencil icon of the
SAME boxy vintage arcade cabinet as the other two variants — thick uniform
white strokes (about 24 pixels wide), hollow interior, no fill. SAME
proportions, SAME composition, SAME parallel oblique projection (left side
panel visible at ~20-degree turn, parallel lines only, no vanishing point,
no foreshortening, no perspective convergence). Front face = flat rectangle,
side panel = parallelogram in same outline style. Joystick ball, three
button circles, and CRT frame all rendered as white outlines only — no
color, no fill, hollow interior. CRT screen is empty (no text, no scene)
— keeps the tinted slot clean for iOS system tinting. Sharp 90-degree
corners. ONLY the white outline strokes are opaque; everything else —
including inside the cabinet body and the side panel interior — is fully
transparent. Flat 2D, single solid white tone, no shadows, no gradients,
no 3D. Generous negative space around the cabinet, occupies center 60% of
frame. No text, no lettering, no logos.
```

### Revision 2026-04-27 — v1 outline-stencil aesthetic

Kept for diff reference only. Not the current direction.

#### Light variant (v1)

```
A flat 2D vector app icon, full-bleed square, edge-to-edge solid teal background
(#0F766E), no rounded corners on the canvas, no border. Centered outline-style
stencil icon of a classic vintage arcade cabinet — thick uniform white strokes
(about 24 pixels wide at 1024 resolution), hollow interior, no fill. BOXY
rectangular construction: rectangular body, flat rectangular marquee at top,
square CRT screen, horizontal control panel slab with joystick ball + three
small button circles, flat rectangular base. All corners are sharp 90-degree
angles. Subtle three-quarter angle in parallel oblique projection — the left
side panel is visible at roughly 20-degree turn, drawn with parallel lines
only (no vanishing point, no foreshortening, no perspective convergence).
The front face stays a flat rectangle; the side panel is a parallelogram
running off to the back-left at a constant angle. Isometric / axonometric flat
illustration. No shadows, no gradients, no depth shading — the side panel is
just a second flat plane in the same outline style. Generous negative space,
cabinet occupies center 60% of frame. No text, no lettering, no logos, no
fill inside the strokes. 1024x1024 pixels.
```

#### Dark variant (v1)

```
A flat 2D vector app icon, full-bleed square, edge-to-edge solid near-black
background (#0A0F0D), no rounded corners on the canvas, no border. Centered
outline-style stencil icon of the SAME boxy vintage arcade cabinet from the
light variant — thick uniform deep teal (#0F766E) strokes (about 24 pixels
wide at 1024 resolution), hollow interior, no fill. SAME proportions, SAME
composition, SAME parallel oblique projection (left side panel visible at
the same ~20-degree turn, parallel lines only, no vanishing point, no
perspective convergence). Front face = flat rectangle; side panel =
parallelogram in same outline style. Sharp 90-degree corners on every
element. Flat 2D, no shadows, no gradients, no 3D shading, no glow blur —
just flat solid deep-teal strokes on near-black. Generous negative space,
cabinet occupies center 60% of frame. No text, no lettering, no logos, no
fill inside the strokes. 1024x1024 pixels.
```

## Re-export recipe (for v1.0.x)

If colors / strokes need adjustment in a future point release, regenerate via
ChatGPT image generation with the prompts above (adjust hex codes as needed),
save candidates at `assets/icon/source/*-candidate.png`, then run:

```bash
sips -z 1024 1024 assets/icon/source/light-candidate.png --out assets/icon/source/light.png
sips -z 1024 1024 assets/icon/source/dark-candidate.png  --out assets/icon/source/dark.png
cp assets/icon/source/tinted-candidate.png assets/icon/source/tinted.png
cp assets/icon/source/{light,dark,tinted}.png gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/
# rename to icon-{light,dark,tinted}.png in the appiconset
rm assets/icon/source/*-candidate.png
```

`Contents.json` should NOT need editing — the 3-slot wiring is fixed from P1.
