---
phase: 07-release
plan: 02
type: summary
status: complete
completed: 2026-04-27
commit: a7f6f1f
files_created:
  - assets/icon/AI_PROVENANCE.md
  - assets/icon/source/light.png
  - assets/icon/source/dark.png
  - assets/icon/source/tinted.png
files_modified:
  - gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png
  - gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-dark.png
  - gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-tinted.png
sc_closed:
  - SC1-A (real arcade-machine app icon shipped — light/dark/tinted)
discretion_resolved:
  - "Discretion #4: master path = raster (clean PNG line-art at 1024² gains nothing from vectorization)"
  - "Discretion #5: AI service = ChatGPT image generation (DALL·E 3), 2026-04-27"
---

# 07-02 Summary — Real Arcade-Machine App Icon

**What shipped:** Three 1024×1024 PNG variants of an outline-stencil arcade-cabinet icon (boxy parallel-oblique projection) replace the P1 placeholders in `AppIcon.appiconset/`. Single atomic commit `a7f6f1f`. SC1-A closed.

## Style

- **Outline stencil** — thick uniform strokes, hollow interior, no fill (NOT silhouette).
- **Boxy parallel-oblique** — left side panel visible at ~20° turn, parallel lines only, no vanishing point. Reads as flat 2D with subtle depth, not photorealistic 3D.
- **Sharp 90° corners** — no rounded edges on the cabinet itself; iOS handles canvas corner rounding.
- **Same cabinet retoned per appearance** (D-02 verbatim) — NOT three different scenes.

## Variants

| Slot | Background | Strokes | Source |
|------|------------|---------|--------|
| Light | `#0F766E` (Forest light family) | White | DALL·E 3 1254² → sips downscaled 1024² |
| Dark | `#0A0F0D` near-black | `#0F766E` deep teal | DALL·E 3 1254² → sips downscaled 1024² |
| Tinted | Fully transparent (alpha-zero verified) | White | DALL·E 3 1024² as-shipped |

## Tinted background — false alarm resolved

Initial Preview/chat render appeared to have a black background. Pillow corner-pixel sampling proved the file is actually a proper RGBA PNG with `(0,0,0,0)` alpha-zero corners — Preview was rendering RGBA-zero against its default dark canvas, not the file's content. **No alpha-mask step needed.** No v1.0.1 punt logged for this.

## Acceptance

All 5 plan tasks PASS:
- T1 candidate staging — verified dims + provenance file (`old school arcade machine` subject lock + AI service named).
- T2 [BLOCKING] checkpoint — user approved, raster-master path chosen.
- T3 promote to masters — sips downscale (1254→1024), tinted RGBA preserved, candidates removed, provenance updated with `Master path chosen (Discretion #4): raster`.
- T4 export to AppIconset — 3 PNGs at exact 1024² each, no Finder dupes, `Contents.json` untouched.
- T5 atomic commit — 7-file commit (3 masters + provenance + 3 appiconset PNGs); commit message names CLAUDE.md §8.10; pre-existing dirty paths (05-04/05-05-PLAN.md, xcuserstate, 07-PLANs, etc.) left unstaged per anti-bundle rule.

## Lessons Learned

**Verify file alpha before alpha-masking.**
DALL·E 3 actually delivered a properly-transparent tinted PNG; the apparent "black background" was Preview's RGBA-zero render canvas. A 5-second Pillow `getpixel((0,0))` corner sample saved a 30-second alpha-mask step AND a false v1.0.1 tech-debt entry. Pattern locks: when the AI image preview looks wrong but `sips -g hasAlpha` reports `yes`, sample the actual alpha values before assuming the BG is opaque.

**1024² is non-negotiable.**
DALL·E 3 returned 1254² for the light + dark candidates despite the prompt explicitly saying `1024×1024 pixels`. Apple App Store rejects sub-1024 OR over-1024 icons. `sips -z 1024 1024` is the cleanest fix — preserves sRGB, no perceptible quality loss at icon-size renders.

**Save the prompt.**
Final prompts archived in `AI_PROVENANCE.md` so v1.0.x re-exports (color tweaks, stroke weight changes, etc.) reproduce the same cabinet without prompt-archaeology. Pattern locks: any AI-generated asset commits its prompt alongside the asset.

**Style iteration via constraint stacking, not prose.**
First attempt = solid silhouette. User pivot 1: "boxier, more stencil, more outline" → swap silhouette to outline-stencil (thick strokes, hollow). User pivot 2: "still should be turned to side, depth lost" → add `parallel oblique projection — parallel lines only, no vanishing point`. Each pivot landed cleanly because the prompt added a CONSTRAINT (parallel lines, hollow interior, sharp 90° corners) rather than rewording the description. Pattern: when AI output drifts, name the constraint that rules out the drift, don't add adjectives.

**ChatGPT/DALL·E 3 ignored:** "1024×1024 pixels" twice (delivered 1254²), partial transparency request first time (delivered transparent on 3rd attempt for tinted). Both worked around with post-processing rather than re-prompting.
