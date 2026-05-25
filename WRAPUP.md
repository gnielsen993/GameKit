# WRAPUP.md
## GameDrawer — Release Wrap-Up Procedure

This document defines the full wrap-up checklist. CLAUDE.md and AGENTS.md
reference it by name; read it whenever a wrap-up fires.

---

## Firing conditions

Trigger this procedure when the user says any of:
- "wrap up" / "wrap up v1.x" / "wrap up x.x.x"
- "shipping" / "ship v1.x" / "ship it"
- "release v1.x" / "release it"
- "let's wrap" / "ready to release"

Do not fire mid-feature or mid-fix. Finish the current task first, then
run the procedure in order.

---

## Step 1 — Internal documents

1. Pull `MARKETING_VERSION` from `gamekit/gamekit.xcodeproj/project.pbxproj`.
2. Confirm `Docs/releases/v{version}.md` exists and is complete:
   - All features, fixes, and notable internals from this version are logged.
   - No placeholder bullets or unresolved TODOs in the file.
   - If the file is missing, create it from `Docs/releases/TEMPLATE.md` first.
3. If the milestone status changed (e.g. v1.x shipped → v1.y is next),
   update `.planning/STATE.md` and §0.1 of CLAUDE.md + AGENTS.md in
   the same commit per §8.13 of CLAUDE.md.

---

## Step 2 — Website (`~/Desktop/GameKitWebsite`)

Website files live at `~/Desktop/GameKitWebsite`. Always work from that
directory. Never edit these files in the GameKit repo.

### 2a. `index.html`
- Update the hero copy or feature highlights if a new game or major feature
  shipped. Match the tone of existing copy — short, specific, no adjectives.
- If the game count changed (e.g. 3 → 4 games), update every place that
  states the count.

### 2b. `about.html`
- Update the feature list or game roster if the new release adds to it.
- Keep the same formatting and voice as the existing bullets.

### 2c. `updates.html`
- Add a new entry at the top of the update log for this version.
- Format: version number, date, short paragraph or bullets — match the
  style of existing entries exactly.

### 2d. Push
After all website edits are staged and committed:
```
cd ~/Desktop/GameKitWebsite && git add -A && git commit -m "chore: update for vX.X release" && git push
```
Push is required on every wrap-up — Plesk deploys from the remote.
Confirm the push succeeded before moving to Step 3.

---

## Step 3 — App Store copy (`Docs/store/app-store-copy.md`)

This file is the single source of truth for all store metadata. Update it
every wrap-up, even if only one section changes. Never let it drift behind
the shipped version.

### 3a. Version header
Update the top two lines:
```
# App Store Copy — GameDrawer vX.X
Last updated: YYYY-MM-DD
Marketing version: X.X
```

### 3b. What's New
Write fresh copy for this version. Rules:
- **Max ~600 chars for the opening section.** Store shows a "more" truncation
  around 350 chars — lead with the most important change.
- **Human voice, not AI voice.** Avoid: "seamlessly", "effortlessly",
  "powerful", "robust", "exciting", "intuitive", "game-changing", "level up",
  "elevate", "stunning", passive constructions, and filler sentences.
- **Specifics over adjectives.** "6,000 puzzles across four difficulties"
  beats "a huge variety of challenging puzzles."
- **Active voice, present tense.** "Puzzles save automatically" not
  "Puzzle progress is now saved."
- **Structure**: Lead with the biggest change (caps heading, short paragraph).
  Then secondary changes as "ALSO IN THIS UPDATE" bullets if needed.
- Keep the full 4,000-char field in mind — don't pad to fill it.

### 3c. Description
- Update if a new game shipped or a previously-described behavior changed.
- Match the existing section structure (THE GAMES / VIDEO MODE / THEMES /
  ZERO NONSENSE).
- Add new game in the same format as existing entries — name, one-line
  summary, key mechanics in plain language.
- Do not rewrite sections that didn't change.

### 3d. Promotional Text (170 chars)
- Update only if the top-level pitch changed (e.g. game count went up).
- This field updates without a new build — it can be changed any time.

### 3e. Keywords (100 chars)
- Add a keyword for any new game or feature that users might search.
- Remove a low-value keyword if needed to stay under 100 chars.
- No spaces after commas.

---

## Step 4 — Deliver to user

After all three steps are complete, output in this order:

1. **Commit summary** — one line confirming the release notes, website push,
   and store copy are all done.
2. **What's New copy** — paste the final text from §3b verbatim, ready to
   drop into App Store Connect.
3. **Any flags** — if something is uncertain (e.g. game count in index.html
   wasn't updated because you couldn't confirm the live game list), say so
   explicitly.

Do not pad the delivery with summaries of every file touched. The user
needs the What's New copy and the confirmation — nothing more.
