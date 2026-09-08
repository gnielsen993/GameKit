# GameDrawer 1.6 App Store package

Open [the review gallery](index.html). Recommended order: collection, hints, Math Crossword, words, resume, offline, Video Mode, themes. The first three images carry the main download proposition. This is a release draft, not a published listing or a measured conversion winner.

- [Paste-ready metadata](metadata/README.md): name, subtitle, description, promotional text, keywords and What's New.
- [iPhone exports](exports/iphone): eight 1320 × 2868 PNGs.
- [iPad exports](exports/ipad): eight 2064 × 2752 PNGs.
- [Positioning and rollout](../Strategy/POSITIONING.md).
- [Sources](../Strategy/SOURCES.md), [matching website copy](../Strategy/WEBSITE-COPY.md).

## Production method

Adapted from FitnessTracker's Marketing/ReleasePlaybook: benefit-first copy, real product proof, immutable native captures, deterministic HTML/CSS composition, straight-on frames, uniform image scaling, and an explicit measurement plan. No app UI was generated, repainted, retouched, or stretched. Backgrounds and typography belong to the marketing canvas. Barlow Condensed is redistributed under the included SIL Open Font License.

Native captures come from GameDrawer 1.6 (build 3), iOS 26.2: iPhone 17 Pro (1206 × 2622) and iPad mini A17 Pro (1488 × 2266). Capture suites run only on isolated simulators named `GameDrawer Marketing …`; demonstration stats and saves are seeded there. The operator test is `gamekitUITests/AppStoreMarketingCapture.swift`. Existing everyday simulator data is not the source. Classic/light is used for regular screens; the theme panel combines separate Classic, Dracula and Voltage captures.

`raw/` contains unchanged source PNGs. `capture-manifest.json` records native capture provenance; `manifest.json` records source and output SHA-256 hashes. The theme composition layers three real captures; it does not represent three simultaneous app windows. Video Mode shows its position picker, not a fabricated video session. Physical-device PiP release verification remains outstanding in the 1.6 closure report.

## Reproduce

With Node, Playwright and Chrome installed:

```sh
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node Marketing/AppStore-1.6/render.cjs
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node Marketing/AppStore-1.6/verify.cjs
```

The renderer verifies text/frame boundaries, image decoding, and preservation of source hashes. `verify.cjs` checks metadata limits, PNG dimensions, responsive gallery overflow, device switching, and every full-resolution image link. Native capture flows exercise the real app separately.

## Release handoff

Upload each numbered set to its matching App Store device slot in order, alongside the metadata, only when 1.6 is ready for release. Keep the current free and ad-free claims accurate; they are not perpetual promises. Do not publish Math Crossword copy against the old 1.5 binary. Review the final App Store Connect previews, collect a 28-day aggregate baseline, and follow the measurement plan. Live website and App Store Connect were not modified by this preparation.
