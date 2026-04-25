---
phase: 01-foundation
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json
  - gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png
  - gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-dark.png
  - gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-tinted.png
autonomous: false
requirements:
  - FOUND-06
tags:
  - assets
  - app-icon
  - placeholder

must_haves:
  truths:
    - "AppIcon.appiconset has three populated PNG slots: universal/light, dark, tinted"
    - "Contents.json declares filenames for all three idiom slots"
    - "Launch screen and home screen show the placeholder icon, not '?'"
  artifacts:
    - path: "gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json"
      provides: "AppIcon manifest referencing 3 PNGs"
      contains: "icon-light.png"
    - path: "gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png"
      provides: "1024x1024 placeholder icon (universal)"
    - path: "gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-dark.png"
      provides: "1024x1024 placeholder icon (dark luminosity)"
    - path: "gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-tinted.png"
      provides: "1024x1024 placeholder icon (tinted luminosity)"
  key_links:
    - from: "gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json"
      to: "Xcode asset compiler"
      via: "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon"
      pattern: "filename"
---

<objective>
Ship the placeholder app icon required by FOUND-06: a flat DesignKit-color square at 1024x1024 in three appearance slots (universal, dark, tinted) so the launch screen and home screen never show "?". Real icon ships at P7 (Pitfall 11).

Purpose: FOUND-06 is the only Foundation requirement that needs a baked binary asset. The icon is intentionally an unmistakable placeholder — the goal is "not a question mark," not "looks final." Per CONTEXT line 46 (Claude's Discretion), colors are baked into PNGs at design time; icons are NOT theme-responsive (they are static bundle assets resolved at install time).

Output: Three 1024×1024 PNGs and a `Contents.json` that declares them. This plan contains a `checkpoint:human-action` because PNG generation requires either (a) a design tool the user opens manually, or (b) a CLI image generator that may not be installed (`sips` / `ImageMagick` may produce acceptable solid-color squares — Claude attempts CLI first and falls back to checkpoint if neither is available).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/01-foundation/01-CONTEXT.md
@.planning/phases/01-foundation/01-PATTERNS.md
@./CLAUDE.md
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Generate three 1024x1024 placeholder PNGs (CLI-first, checkpoint fallback)</name>
  <files>
    gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png
    gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-dark.png
    gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-tinted.png
  </files>
  <read_first>
    - .planning/phases/01-foundation/01-PATTERNS.md §"Assets.xcassets/AppIcon.appiconset/Contents.json + placeholder PNGs (modified)" (the placeholder rationale + filename convention)
    - .planning/phases/01-foundation/01-CONTEXT.md "Claude's Discretion" line 46 (flat DesignKit-color icon, baked at design time)
    - .planning/research/PITFALLS.md §"Pitfall 11" (icon ships placeholder at v1, real at P7)
    - gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json (current default — no filename keys yet)
  </read_first>
  <action>
    Generate three 1024×1024 solid-color PNGs at exact paths listed in `<files>`. Use these exact colors (chosen to be distinct from each other and unmistakably placeholder, while echoing DesignKit's Classic palette):

    | File | Background hex | Notes |
    |------|----------------|-------|
    | icon-light.png   | `#3B5BDB` (indigo) | Universal (light) appearance |
    | icon-dark.png    | `#1A1A2E` (deep navy) | Dark luminosity |
    | icon-tinted.png  | `#9CA3AF` (mid grey) | Tinted luminosity (system tints this monochrome) |

    **Try CLI generators in this order, stop when one succeeds:**

    1. **macOS `sips`** (preinstalled on every Mac):
       ```bash
       # sips cannot create images from scratch — but it CAN convert. Use a 1×1 source then upscale.
       # Actually sips lacks fill-color generation. Skip to step 2.
       ```
       (Skipping sips — it cannot synthesize a solid-color image from nothing.)

    2. **Swift one-liner via `swift run`** — fastest reliable path, no extra deps:
       Create a temporary helper script `scripts/_make-icon.swift` (delete after use) that takes hex + output path and emits a 1024×1024 PNG using `CGContext` + `CGImageDestinationCreateWithURL`. Pseudocode:
       ```swift
       import AppKit
       let args = CommandLine.arguments
       let hex = args[1]; let out = args[2]
       let r = CGFloat(Int(hex.dropFirst(0).prefix(2), radix: 16)!) / 255 // parse hex
       // ... create NSImage / NSBitmapImageRep at 1024x1024, fill, write PNG
       ```
       Run: `swift scripts/_make-icon.swift 3B5BDB gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png` (and dark, tinted).
       Delete `scripts/_make-icon.swift` after the three PNGs are generated.

    3. **Python `Pillow`** (fallback if Swift one-liner balks): `python3 -c "from PIL import Image; Image.new('RGB',(1024,1024),'#3B5BDB').save('PATH')"`. Pillow is usually present on dev machines; install via `pip3 install Pillow` only if you can do so without sudo.

    4. **ImageMagick** (final CLI fallback): `magick -size 1024x1024 xc:'#3B5BDB' PATH` or `convert -size 1024x1024 xc:'#3B5BDB' PATH`.

    **If none of 2/3/4 work**, escalate to the `checkpoint:human-action` task below — do not commit empty PNG files.

    **Verify each PNG is exactly 1024×1024 and is a real PNG** (not a 0-byte file or HTML error page) using `file` and `sips -g pixelWidth -g pixelHeight`:
    ```bash
    file gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png
    # Expected: "PNG image data, 1024 x 1024"
    sips -g pixelWidth -g pixelHeight gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png
    # Expected: pixelWidth: 1024, pixelHeight: 1024
    ```

    Repeat for dark and tinted PNGs.
  </action>
  <verify>
    <automated>file gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-dark.png gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-tinted.png | grep -c "PNG image data, 1024 x 1024"</automated>
  </verify>
  <acceptance_criteria>
    - All three PNG files exist: `test -f` exits 0 for `icon-light.png`, `icon-dark.png`, `icon-tinted.png` under `gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/`
    - `file gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png | grep -c "PNG image data, 1024 x 1024"` returns `1`
    - `file gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-dark.png | grep -c "PNG image data, 1024 x 1024"` returns `1`
    - `file gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-tinted.png | grep -c "PNG image data, 1024 x 1024"` returns `1`
    - Each PNG is at least 200 bytes (sanity check — solid-color 1024×1024 PNG is typically ~2-5 KB; reject 0-byte files): `[ $(stat -f%z gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png) -gt 200 ]` exits 0; same for dark and tinted
    - No leftover helper script: `find scripts -name "_make-icon.swift"` returns no results
  </acceptance_criteria>
  <done>Three 1024×1024 PNGs in place, all verified as real PNG data via `file`. No helper-script leakage.</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Checkpoint (fallback only): User generates the three PNGs manually</name>
  <activation>Only invoked if Task 1's CLI generators ALL failed (Swift, Python, ImageMagick). Skip this checkpoint entirely if Task 1 succeeded — verify by running the acceptance criteria for Task 1; if all three PNGs exist and are valid 1024×1024 PNGs, mark this task as `not-needed` and proceed to Task 3.</activation>
  <what-built>Task 1 attempted to generate 3 placeholder PNGs via CLI and failed at every fallback path.</what-built>
  <how-to-verify>
    1. Open Preview.app or any image editor.
    2. Create a new 1024×1024 image. Fill with `#3B5BDB` (indigo). Export as `icon-light.png`.
    3. Repeat with `#1A1A2E` (deep navy) → `icon-dark.png`.
    4. Repeat with `#9CA3AF` (mid grey) → `icon-tinted.png`.
    5. Save all three files into `gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/`.
    6. Confirm via `file gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/icon-light.png` showing `"PNG image data, 1024 x 1024"`.
  </how-to-verify>
  <resume-signal>Type "icons-ready" or "icons-failed" with which CLI step worked / what fallback you used</resume-signal>
</task>

<task type="auto" tdd="false">
  <name>Task 3: Update AppIcon Contents.json to reference the three PNGs</name>
  <files>gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json</files>
  <read_first>
    - gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json (current default — has 3 entries with no `filename` keys)
    - .planning/phases/01-foundation/01-PATTERNS.md §"Assets.xcassets/AppIcon.appiconset/Contents.json + placeholder PNGs (modified)" (the exact target JSON shape)
  </read_first>
  <action>
    Replace `gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json` entirely with EXACTLY this content (preserves the 3-slot structure, adds `filename` keys):

    ```json
    {
      "images" : [
        {
          "filename" : "icon-light.png",
          "idiom" : "universal",
          "platform" : "ios",
          "size" : "1024x1024"
        },
        {
          "appearances" : [
            {
              "appearance" : "luminosity",
              "value" : "dark"
            }
          ],
          "filename" : "icon-dark.png",
          "idiom" : "universal",
          "platform" : "ios",
          "size" : "1024x1024"
        },
        {
          "appearances" : [
            {
              "appearance" : "luminosity",
              "value" : "tinted"
            }
          ],
          "filename" : "icon-tinted.png",
          "idiom" : "universal",
          "platform" : "ios",
          "size" : "1024x1024"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    ```

    Validate the JSON parses: `python3 -c "import json; json.load(open('gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json'))"` exits 0.
  </action>
  <verify>
    <automated>python3 -c "import json; d=json.load(open('gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json')); assert len(d['images'])==3; assert all('filename' in i for i in d['images'])"</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "import json; json.load(open('gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json'))"` exits 0 (valid JSON)
    - File contains exactly 3 image entries: `python3 -c "import json; print(len(json.load(open('gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json'))['images']))"` outputs `3`
    - All three entries have `filename` keys: `grep -c '"filename"' gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json` returns exactly `3`
    - All three filenames are present in the JSON: `grep -c "icon-light.png" gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json` = `1`, same for `icon-dark.png` and `icon-tinted.png`
    - Two appearance entries (`dark`, `tinted`): `grep -c '"appearance" : "luminosity"' gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json` returns exactly `2`
    - All sizes are `1024x1024`: `grep -c '"size" : "1024x1024"' gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json` returns exactly `3`
  </acceptance_criteria>
  <done>Contents.json validates as JSON, declares 3 entries each pointing at a corresponding `.png` file in the same directory.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none in P1) | This plan only adds static asset files (PNG + JSON manifest) to the bundle. No code execution path, no runtime behavior surface. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-06 | Tampering | AppIcon.appiconset/*.png | accept | PNG assets ship as part of the signed app bundle; Xcode signing covers integrity. Placeholder colors, no embedded data. |
| T-01-07 | Information Disclosure | AppIcon Contents.json | accept | Static manifest with placeholder filenames; no secrets, no PII, public-by-design (the icon is the first thing every user sees). |

**N/A categories:** Spoofing, Repudiation, DoS, Elevation of Privilege — pure static asset additions, zero attack surface introduced.
</threat_model>

<verification>
After all tasks complete:
- `ls gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/` shows `Contents.json`, `icon-light.png`, `icon-dark.png`, `icon-tinted.png`.
- `find gamekit/gamekit/Assets.xcassets/AppIcon.appiconset -name "*.png" | wc -l` returns `3`.
- (Optional, runs only if Xcode CLT is installed): `xcrun actool gamekit/gamekit/Assets.xcassets --output-format human-readable-text --notices --warnings 2>&1 | grep -c "error:"` returns `0`.
</verification>

<success_criteria>
- All Task 1 acceptance criteria met (3 valid 1024×1024 PNGs).
- All Task 3 acceptance criteria met (Contents.json validates, references 3 PNGs).
- Real icon ships at P7 (Pitfall 11) — placeholder is intentionally unfinished-looking, NOT a polish target.
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-03-SUMMARY.md` per the template.
</output>
