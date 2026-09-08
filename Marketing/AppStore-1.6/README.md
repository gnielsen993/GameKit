# GameDrawer 1.6 App Store submission artwork

[Open the selected App Store sequence](index.html). Upload the ten numbered PNGs from the matching device folder in filename order. The gallery includes a swipe preview of slots 2 and 3.

## Selected order

1. Favorites without ads.
2. Video in the way? Sudoku with Video Mode off; the example video covers cells.
3. Make room to play. The same Sudoku and video, with Video Mode on.
4. Useful hints.
5. Math Crossword.
6. Five Letter.
7. Resume FreeCell.
8. Offline play.
9. Themes.
10. Personal bests.

**Slots 2 and 3 are two separate App Store screenshots.** Each shows one large device and a complete sentence. They are not one wide canvas, and no headline or game screen crosses the App Store gutter. This preserves readability while showing the problem and its solution in consecutive slots. The previous Merge video and position-picker slides have moved to alternates so the selected set stays at ten.

- [iPhone upload images](exports/iphone): ten 1320 × 2868 opaque RGB PNGs.
- [iPad upload images](exports/ipad): ten 2064 × 2752 opaque RGB PNGs.
- [Paste-ready metadata](metadata/README.md).
- [Previous ten-slide concepts](concepts/previous-ten-slide-set/index.html), including Merge video and the position picker. Every previous export is preserved byte for byte.
- [Single-image side-by-side concept](concepts/sudoku-comparison/index.html), preserved for reference.

## Capture and composition

The method follows FitnessTracker's release playbook: benefits backed by actual product screens, uniform scaling and deterministic HTML/CSS composition. Native screenshots are immutable. Regular app captures use Classic/light; themes use separate Classic, Dracula and Voltage captures. Fonts are covered by the included SIL Open Font License.

The Sudoku pair uses the same saved puzzle, captured natively on iPhone 17 Pro and iPad mini A17 Pro, iOS 26.2, GameDrawer 1.6 build 3. Its paired capture tests passed on both devices. Identical illustrative video windows sit at the same size and position within each device pair. The actual Video Mode layout changes the board and control positions. The added window is disclosed in the artwork and does not claim live external PiP playback.

`capture-manifest.json` records native sources. `manifest.json` records source/output hashes and which image has Video Mode off or on. The unused historical `raw/*/stats.png` is a Profile-menu capture; the selected stats slide uses `stats-dashboard.png`.

## Reproduction and verification

```sh
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node Marketing/AppStore-1.6/render.cjs
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node Marketing/AppStore-1.6/verify.cjs
```

The renderer checks image decoding, boundaries, two-line headings, text/device separation and source preservation. The verifier checks PNG dimensions, metadata limits, archived export hashes, two-image preview order, and the gallery at 375, 768 and 1440 pixels. Native capture evidence remains in the comparison concept's `review/` folder. The renderer removes superseded numbered exports from the current upload folders; it does not touch archived concepts.

These are the selected assets for App Store upload, not a published listing or a measured conversion result. Upload alongside 1.6 only after its remaining physical-device release checks. Verify the actual App Store Connect previews before submitting. Current free/ad-free claims are not perpetual promises. No App Store Connect or live website changes were made.
