# Icon Provenance (P7 Plan 07-02)

AI service used: ChatGPT image generation (DALL·E 3), 2026-04-27
Generation date: 2026-04-27
Subject (verbatim from CONTEXT D-01): "old school arcade machine"
Variants generated: light (warm cabinet) / dark (neon-glow) / tinted (monochrome silhouette)

## Approval (2026-04-27)

User approved candidates via Task 2 [BLOCKING] CHECKPOINT.

Master path chosen (Discretion #4): raster

Final masters live at `assets/icon/source/{light,dark,tinted}.png` (1024×1024 sRGB).
Candidate staging files removed after promotion.

Light + dark candidates were generated at 1254×1254 and downscaled to 1024×1024 via
`sips -z 1024 1024` (preserves sRGB; no quality loss perceptible at the icon-size
scales the AppIcon slot is rendered at).

Tinted candidate was generated already at 1024×1024 with a proper alpha channel —
fully transparent background, opaque white outline strokes. Verified via Pillow
corner-pixel sampling: all four corners read `(0, 0, 0, 0)` (alpha-zero). No
alpha-masking step was needed despite the candidate appearing to have a dark
background in Preview/chat (Preview renders RGBA-zero against its default dark
canvas, not the actual file content).

## Final renders

`gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png` — light slot
`gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-dark.png` — luminosity-dark slot
`gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-tinted.png` — tinted slot

`Assets.xcassets/AppIcon.appiconset/Contents.json` was UNCHANGED (P1 wiring already
correct for the 3-slot layout).

## Final prompts (saved for v1.0.x re-export reproducibility)

> **Revision 2026-04-29:** prompts updated from outline-stencil aesthetic to
> filled colorful cabinet on solid black bg (red body, yellow marquee, red
> bulb joystick, multicolor buttons, CRT shows "GameKit" + "PRESS START"
> retro start screen). Same boxy cabinet shape locked: rectangular body +
> flat marquee + square CRT + horizontal control panel slab w/ joystick ball
> + 3 button circles + flat base, parallel oblique ~20° left side, sharp 90°
> corners. Tinted variant kept as outline stencil (system tinting requires
> single-tone alpha). Original v1 prompts archived below revision block.

### Light variant

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

### Dark variant

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

### Tinted variant

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

## Archived v1 prompts (2026-04-27, outline-stencil aesthetic)

Kept for diff reference only. Not the current direction — see Revision 2026-04-29 above.

### Light variant (v1)

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

### Dark variant (v1)

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
