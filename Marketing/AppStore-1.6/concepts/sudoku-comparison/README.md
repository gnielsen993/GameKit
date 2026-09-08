# Sudoku: Video Mode off vs. on

[Open this alternate concept](index.html) · [All current concepts](../../index.html)

The comparison makes the problem visible before presenting the benefit. Use the same Sudoku puzzle and the same illustrative video size/position on both sides. With Video Mode off, the video covers cells; with the actual large-top layout on, the full board, number pad and controls remain visible. No competing app is depicted and no gameplay UI was redrawn.

Recommended candidate for the early Video Mode slot. It explains the difference more directly than the single Merge example, at the cost of smaller individual screens. This is an editorial recommendation, not a measured conversion result. The existing ten-slide set, including Merge gameplay, the position picker and stats, remains untouched. This alternate is outside the upload folders; select it as a replacement if desired rather than uploading eleven images.

## Files and evidence

- `iphone-sudoku-comparison.png`: 1320 × 2868, opaque RGB.
- `ipad-sudoku-comparison.png`: 2064 × 2752, opaque RGB.
- `raw/`: four native captures of the same saved Sudoku puzzle, GameDrawer 1.6 build 3, Classic/light, iOS 26.2.
- `capture-manifest.json`: capture provenance and raw hashes.
- `manifest.json`: output hashes, matched video window geometry, left-side cell overlap and right-side control clearance.
- `review/`: native capture results, responsive gallery checks and previews.

Operator flow: `AppStoreMarketingCapture/testCaptureSudokuVideoComparison`. Open the saved Easy/Free Sudoku, capture with Video Mode off, relaunch with large-top Video Mode, restore the same puzzle, and capture again. The saved numbers match visually. Timers may differ slightly between launches; no screenshot pixels were altered to disguise this.

The video windows are identical within each device pair, authored in HTML/CSS and explicitly labeled illustrative in the export. The test does not claim live external PiP playback. Existing physical-device release verification remains separate.

Reproduce with Node, Playwright and Chrome:

```sh
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node Marketing/AppStore-1.6/concepts/sudoku-comparison/render.cjs
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node Marketing/AppStore-1.6/concepts/sudoku-comparison/verify.cjs
```

The renderer checks identical window size and placement, a visible overlap with the left board, and clearance above all right-side gameplay controls using conservative bounds measured on the captures. Visual review confirms the intended meaning and all 81 right-side squares remain visible. The verifier checks all 20 prior export hashes, the two new RGB images, local links, gallery overflow and navigation back to the original set at 375, 768 and 1440 pixels.

Self-evaluation: accuracy 4/5 (real paired layouts, illustrative video remains a disclosed limitation); completeness 4/5 (both device concepts and all prior exports available, selection remains open); clarity 4/5 (difference visible in one image, individual boards are smaller); actionability 4/5 (two upload-size exports and a linked gallery, final slot choice still open); conciseness 4/5 (short headline, supporting labels repeat the benefit for thumbnail viewing). Overall 4.0/5. Next useful step is choosing between this alternate and the existing Merge image, then checking the selected image in the store preview.
