# Review notes

Native iPhone and iPad capture flows passed. HTML/CSS exports are checked separately by `verify.cjs`; results are in `verification.json`. Full-resolution source images were reviewed alongside both gallery contact sheets. Raw image hashes are preserved through rendering.

Corrections during review:

- Removed unsupported Connections from the replacement listing.
- Verified 6,000 bundled Sudoku puzzles: 1,500 in each of four difficulty collections.
- Corrected the old 34-theme claim to 35: GameDrawer enables its Classic slot, so DesignKit supplies six core entries plus 29 other presets. FitnessTracker disables the Classic slot; its count should not be copied here.
- Restarted the capture-only Five Letter round before entering a guess, avoiding repeated demonstration guesses across capture runs.
- Scrolled the native iPad Video Mode picker for a complete preview. Scrolling is normal sheet behavior; the artwork must not imply everything is visible at once.
- Used the actual resumed FreeCell board as the resume illustration.

Additional product observation: the FreeCell resume dialog identifies the saved deal correctly, but the dimmed background still shows the newly initialized deal number until Continue is tapped. `FreeCellViewModel.checkAndLoadOrRestoreState()` sets a pending save; `restoreState()` then replaces the board and deal number. Continue restores correctly. This is a nonblocking presentation issue for a future polish pass, not evidence of lost progress; the raw resume captures preserve the finding.

Self-evaluation: accuracy 4/5 (claims checked against source and captures; live device PiP remains outside this evidence), completeness 4/5 (all requested copy and device artwork delivered; market results require publication and traffic), clarity 4/5 (ordered gallery and individual text fields; dense game roster remains in the long description), actionability 4/5 (ready-to-upload PNGs and metadata; final ASC previews still need checking), conciseness 4/5 (short campaign messages; provenance is intentionally detailed). Overall 4.0/5. Next improvements: complete device release checks, inspect ASC upload previews, then evaluate aggregate visibility and download data. These are evidence limits Gabe can inspect, not claims that the campaign has already improved conversion.


## Ten-image revision

Gabe requested visual proof of Video Mode with a large reserved space and a rounded example video window. Added a native Merge large-top capture after a real swipe, then composed a labeled illustrative PiP window within the empty reserved band. App pixels remain unchanged. The image leads in position 2, ahead of the hints screen. The tenth image shows the real Stats dashboard with seeded demonstration wins, times and scores; these are personal sample records, not user-count or popularity claims. Filenames and gallery order now agree across all ten images per device.

The illustration demonstrates spatial coexistence. It does not close the separate physical-device test of a live third-party PiP session.

Revision verification: native Video Mode + Stats flow passed on iPhone and iPad (one test each); all 20 RGB PNGs passed dimensions, two-line headline, headline/device separation, illustrative-window clearance, source hash preservation, and gallery checks at 375, 768 and 1440 pixels. Visual review caught and shortened the initial stats headline before delivery. Self-evaluation remains 4/5 across the five axes: the requested ten-image package is complete; the remaining evidence limit is live external PiP on physical hardware.
