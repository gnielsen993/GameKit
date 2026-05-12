---
phase: 08-video-mode-design
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Docs/screenshots/v1.2-design/README.md
  - Docs/screenshots/v1.2-design/mines-easy-classic.png
  - Docs/screenshots/v1.2-design/mines-easy-dracula.png
  - Docs/screenshots/v1.2-design/mines-medium-classic.png
  - Docs/screenshots/v1.2-design/mines-medium-dracula.png
  - Docs/screenshots/v1.2-design/mines-hard-classic.png
  - Docs/screenshots/v1.2-design/mines-hard-dracula.png
  - Docs/screenshots/v1.2-design/merge-classic.png
  - Docs/screenshots/v1.2-design/merge-dracula.png
  - Docs/screenshots/v1.2-design/nonogram-classic.png
  - Docs/screenshots/v1.2-design/nonogram-dracula.png
autonomous: false
requirements: []
user_setup: []

must_haves:
  truths:
    - "Ten fresh game-screen screenshots exist under Docs/screenshots/v1.2-design/ (Mines E/M/H + Merge + Nonogram x Classic + Dracula)"
    - "Every screenshot is iPhone 17 Pro Max (per D-04)"
    - "Each screenshot shows a real in-progress game state, not a Home or Settings screen"
    - "Filenames follow the locked convention {game}-{difficulty?}-{preset}.png so 08-04 can ingest them deterministically"
  artifacts:
    - path: "Docs/screenshots/v1.2-design/README.md"
      provides: "Capture provenance: device, OS, preset, app version, game state notes"
      contains: "iPhone 17 Pro Max"
    - path: "Docs/screenshots/v1.2-design/mines-hard-classic.png"
      provides: "Hard 16x30 Classic screenshot — the squeeze case that drives the Hard-Mines ADR in 08-05"
    - path: "Docs/screenshots/v1.2-design/mines-hard-dracula.png"
      provides: "Hard 16x30 Dracula screenshot — Loud preset legibility check for the Hard squeeze"
  key_links:
    - from: "Docs/screenshots/v1.2-design/*.png"
      to: ".planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md"
      via: "08-04 ingests these screenshots and overlays 6 PiP zones on each"
      pattern: "Docs/screenshots/v1\\.2-design/.*\\.png"
    - from: "Docs/screenshots/v1.2-design/mines-hard-*.png"
      to: ".planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md"
      via: "08-05 sketch variants reference these screenshots as the baseline squeeze case"
      pattern: "mines-hard-(classic|dracula)\\.png"
---

<objective>
Capture the ten fresh game-screen screenshots that every other Phase 8 plan consumes.
Mines Easy / Medium / Hard, Merge, and Nonogram — each on Classic preset AND Dracula
preset — captured on iPhone 17 Pro Max simulator per CONTEXT D-02, D-03, D-04.

Purpose: Phase 8 is screenshot-driven (CONTEXT §domain, plan-doc §Design phase required).
The existing `Docs/screenshots/asc/` set is App Store marketing material with partial
coverage — missing Easy / Medium / Nonogram and 6-corner annotations (per CONTEXT D-02).
Layout overlay (08-04) and Hard-Mines ADR (08-05) cannot run without these baseline images.

Output: 10 PNG files + README.md capture log, all under `Docs/screenshots/v1.2-design/`.
No `gamekit/` code is touched (SC5).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/08-video-mode-design/08-CONTEXT.md
@Docs/GameDrawer-v1.2-Video-Mode-Plan.md
@CLAUDE.md
</context>

<tasks>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 1: Capture 10 screenshots in simulator</name>
  <read_first>
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (D-02, D-03, D-04 lock the capture rules)
    - Docs/GameDrawer-v1.2-Video-Mode-Plan.md (§Game-specific notes — Mines E/M/H, Merge, Nonogram)
    - CLAUDE.md §8.12 (Classic + one Loud preset audit rule — Dracula is the Loud preset)
    - ../DesignKit/Sources/DesignKit/Theme/PresetCatalog.swift (confirm Classic + Dracula are valid preset identifiers — Gabe selects them in Settings)
  </read_first>
  <what-built>This is a human-action checkpoint — Claude cannot drive the simulator to play through a real game state. Gabe captures the 10 screenshots manually.</what-built>
  <how-to-verify>
    Required device: iPhone 17 Pro Max simulator (CONTEXT D-04).
    Required app build: current `main` (v1.0 with Merge + Nonogram graduated, per STATE.md).
    Required presets: Classic (default) AND Dracula (Settings → More themes → Dracula).

    Per-screenshot recipe (10 total — 5 games x 2 presets):

    1. Mines Easy + Classic:
       - Home → Minesweeper → difficulty "Easy" → tap a cell to enter play state → screenshot
       - File: `Docs/screenshots/v1.2-design/mines-easy-classic.png`
    2. Mines Easy + Dracula:
       - Settings → switch preset to Dracula → return to Mines Easy mid-game → screenshot
       - File: `Docs/screenshots/v1.2-design/mines-easy-dracula.png`
    3. Mines Medium + Classic: switch difficulty to Medium (16x16), enter play state, screenshot
       - File: `mines-medium-classic.png`
    4. Mines Medium + Dracula:
       - File: `mines-medium-dracula.png`
    5. Mines Hard + Classic: difficulty Hard (16x30), enter play state, screenshot
       - File: `mines-hard-classic.png` — CRITICAL: this is the squeeze case for 08-05
    6. Mines Hard + Dracula:
       - File: `mines-hard-dracula.png` — CRITICAL: same squeeze on Loud preset
    7. Merge + Classic: Home → Merge → play state with a few tiles on board → screenshot
       - File: `merge-classic.png`
    8. Merge + Dracula:
       - File: `merge-dracula.png`
    9. Nonogram + Classic: Home → Nonogram → 10x10 play state with a few cells filled → screenshot
       - File: `nonogram-classic.png`
    10. Nonogram + Dracula:
        - File: `nonogram-dracula.png`

    Save all 10 PNGs into `Docs/screenshots/v1.2-design/` (Claude creates the directory at task start).

    Quick verification commands Claude runs after Gabe says "captured":
      - `ls Docs/screenshots/v1.2-design/*.png | wc -l` must equal 10
      - `file Docs/screenshots/v1.2-design/*.png` every line must contain "PNG image data"
      - `identify Docs/screenshots/v1.2-design/mines-hard-classic.png` (if ImageMagick installed) should show 1290x2868 or 1320x2868 (iPhone 17 Pro Max @3x); if `identify` not available, skip this check.
  </how-to-verify>
  <action>
    Claude actions before checkpoint:
    1. `mkdir -p Docs/screenshots/v1.2-design/`
    2. Print the 10-screenshot recipe above to the chat verbatim, with the exact filenames.
    3. Wait for Gabe's "captured" signal.

    Claude actions after checkpoint:
    4. Run `ls Docs/screenshots/v1.2-design/*.png | wc -l` — must return 10.
    5. If count != 10, list which expected filenames are missing and re-prompt Gabe.
  </action>
  <verify>
    <automated>test "$(ls Docs/screenshots/v1.2-design/*.png 2>/dev/null | wc -l | tr -d ' ')" = "10"</automated>
  </verify>
  <done>All 10 expected PNG filenames exist under Docs/screenshots/v1.2-design/. None are zero-byte.</done>
  <resume-signal>Gabe types "captured" or describes which screenshots are still missing.</resume-signal>
</task>

<task type="auto">
  <name>Task 2: Write capture-log README</name>
  <read_first>
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (D-02, D-03, D-04)
    - Docs/screenshots/v1.2-design/ (verify all 10 PNGs landed from Task 1)
  </read_first>
  <action>
    Create `Docs/screenshots/v1.2-design/README.md` with the exact sections below (markdown):

    ```
    # Phase 8 Design Screenshots

    Captured: {YYYY-MM-DD}
    Device: iPhone 17 Pro Max simulator (per CONTEXT D-04)
    App build: GameDrawer main @ {short-sha} (Merge + Nonogram graduated)
    Presets: Classic + Dracula (per CONTEXT D-03, mirrors CLAUDE.md §8.12)

    ## Files

    | Game | Difficulty | Preset | File |
    |------|------------|--------|------|
    | Minesweeper | Easy | Classic | mines-easy-classic.png |
    | Minesweeper | Easy | Dracula | mines-easy-dracula.png |
    | Minesweeper | Medium | Classic | mines-medium-classic.png |
    | Minesweeper | Medium | Dracula | mines-medium-dracula.png |
    | Minesweeper | Hard | Classic | mines-hard-classic.png |
    | Minesweeper | Hard | Dracula | mines-hard-dracula.png |
    | Merge | — | Classic | merge-classic.png |
    | Merge | — | Dracula | merge-dracula.png |
    | Nonogram | — | Classic | nonogram-classic.png |
    | Nonogram | — | Dracula | nonogram-dracula.png |

    ## Consumers

    - `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` (Plan 08-04) overlays 6 PiP zones on every screenshot.
    - `.planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md` (Plan 08-05) uses the two `mines-hard-*` images as the baseline-squeeze evidence.

    ## Provenance

    These are NOT the ASC marketing screenshots in `Docs/screenshots/asc/` —
    those have partial coverage (missing Easy / Medium / Nonogram, no 6-corner
    overlays). Per CONTEXT D-02, Phase 8 captures fresh.
    ```

    Replace `{YYYY-MM-DD}` with today's date (2026-05-12 or later — use `date +%Y-%m-%d`).
    Replace `{short-sha}` with `git rev-parse --short HEAD`.
  </action>
  <acceptance_criteria>
    - test -f Docs/screenshots/v1.2-design/README.md
    - grep -q "iPhone 17 Pro Max" Docs/screenshots/v1.2-design/README.md
    - grep -q "Classic + Dracula" Docs/screenshots/v1.2-design/README.md
    - grep -c "mines-easy-classic.png\|mines-easy-dracula.png\|mines-medium-classic.png\|mines-medium-dracula.png\|mines-hard-classic.png\|mines-hard-dracula.png\|merge-classic.png\|merge-dracula.png\|nonogram-classic.png\|nonogram-dracula.png" Docs/screenshots/v1.2-design/README.md — must return >= 10
  </acceptance_criteria>
  <verify>
    <automated>test -f Docs/screenshots/v1.2-design/README.md && grep -q "iPhone 17 Pro Max" Docs/screenshots/v1.2-design/README.md && grep -q "Classic + Dracula" Docs/screenshots/v1.2-design/README.md</automated>
  </verify>
  <done>README.md exists, names every PNG, locks device + presets + consumers.</done>
</task>

</tasks>

<verification>
- All 10 PNGs present and non-empty.
- README.md documents device, presets, file list, downstream consumers.
- No file under `gamekit/` modified (SC5).
</verification>

<success_criteria>
- `ls Docs/screenshots/v1.2-design/*.png | wc -l` returns 10
- README.md contains "iPhone 17 Pro Max" and "Classic + Dracula"
- `git diff --name-only HEAD~1 -- gamekit/` returns empty (no app code touched)
</success_criteria>

<output>
After completion, create `.planning/phases/08-video-mode-design/08-01-SUMMARY.md`.
</output>
