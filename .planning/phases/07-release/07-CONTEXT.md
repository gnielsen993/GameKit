# Phase 7: Release - Context

**Gathered:** 2026-04-27
**Status:** Ready for research/planning

<domain>
## Phase Boundary

P7 ships **the pre-submission gate**: replace the P1 placeholder app icon with a real one, promote the CloudKit schema from Development to Production, author the full App Store metadata package, run the manual SC1–SC5 sweep, upload an Internal-only TestFlight build, and submit to App Review. Code is shipped-quality after P6; this phase is checklist work + assets + manual verification, not new feature surface.

**P7 ships:**
- `assets/icon/` — NEW directory at repo root holding the SVG vector master(s) for the AI-generated arcade-machine icon (light / dark / tinted retones), checked into git.
- `gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/{icon-light,icon-dark,icon-tinted}.png` — replace the P1 placeholders with 1024² PNG renders exported from the SVG master(s). Contents.json wiring already exists from P1.
- `.planning/phases/07-release/07-CHECKLIST.md` — the master release checklist. Capabilities verified, entitlements diff-ed, container ID stable, schema deployed to Production, privacy nutrition label answered with reasoning, SIWA tested in Production via TestFlight, theme matrix verified, metadata authored. Sign-off rows mapped to SC1–SC5 + Pitfall 11.
- `.planning/phases/07-release/07-VERIFICATION.md` — manual SC1–SC5 verification template (mirrors P6-09 shape: verbatim copy locks, gap log, sign-off table).
- `.planning/phases/07-release/screenshots/` — minimum 12 manual screenshots (6 DesignKit categories × play state + loss state) + 4 warm-accent flag-vs-mine shots (Forest / Ember / Voltage / Maroon, loss state). Doubles as App Store screenshot source where compositions overlap.
- `Docs/release-checklist.md` (or sibling) — short discoverable summary that points to the canonical phase-local checklist. Optional, planner discretion.
- App Store Connect submission package — description, subtitle (≤30 char), keywords (100 char limit), promotional text, support URL, marketing URL, privacy policy URL, screenshots (5 minimum for 6.7"+ iPhone). Authored entirely in P7.
- Privacy policy markdown + GitHub Pages enable on the GameKit repo (`/docs/privacy.md` or equivalent). Stopgap host until a future `GameKitWebsite` repo lands.
- ROADMAP.md / REQUIREMENTS.md / STATE.md / 06-VERIFICATION.md doc-drift cleanup — refreshed in the FIRST P7 plan (per D-17), not bundled with the metadata or icon plans.
- `project.pbxproj` edits — `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` (first TestFlight upload). Bumped per subsequent upload. CloudKit container ID + bundle ID re-verified unchanged.
- TestFlight Internal-only build uploaded; user invited as Internal Tester; SC1–SC5 manual sweep run on hardware against the Production CloudKit environment.

**Out of scope for P7** (owned by other phases or v1.x):
- P5 G-1 CAF audio (`tap.caf` / `win.caf` / `loss.caf`) — punted to v1.0.1 polish per D-16. Silent fallback is acceptable v1 ship state per P5 D-12 contract; SFX is off by default per SC2 verbatim.
- External TestFlight beta + public link — defer to post-launch (D-14).
- MetricKit integration — explicitly NOT shipping v1.0 (Discretion #6).
- `GameKitWebsite` repo + privacy URL redirect — separate project; future state, not P7.
- Per-game alt-icon variants, App Shortcuts, second-game scaffolding — PROJECT.md out-of-scope reminder.
- Live `ModelContainer` hot-swap — already deferred at P6 (CONTEXT D-07).
- New code features — P7 is checklist + assets, not engineering.

**v1 ROADMAP P7 success criteria carried forward as locked specs (no re-asking):**
- SC1 — Real app icon ships in `Assets.xcassets`; CloudKit schema promoted Dev → Production (verified via Dashboard env toggle); `iCloud.com.lauterstar.gamekit` container ID identical to P1's lock and unchanged in `Info.plist` / entitlements.
- SC2 — Privacy nutrition label answered "Data Not Collected" with documented reasoning ("CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit acceptable") matching the binary; decided in advance, not in a 2-minute submission rush.
- SC3 — SIWA verified working in the **Production** environment via TestFlight (not just dev sandbox); CloudKit sync verified working in TestFlight by signing in on two TestFlight devices and watching stats sync.
- SC4 — Final theme-matrix legibility audit passes: Hard-board sample renders correctly on at least one preset from each DesignKit category for play state AND loss state; flag color verified distinct from mine indicator on warm-accent presets (Forest / Ember / Voltage / Maroon).
- SC5 — Release checklist documented in `.planning/Docs/` (or equivalent — phase-local accepted per literal "or equivalent") covering capabilities verified, entitlements diffed, schema promoted, container ID stable, label completed, SIWA tested in production. TestFlight build uploaded, internal testers invited.

</domain>

<decisions>
## Implementation Decisions

### App Icon Production (SC1)
- **D-01:** **Concept = AI-generated old-school arcade machine.** Subject is a stylized vintage arcade cabinet — user-authored direction, not "abstract logo" or "letter mark." AI service (Midjourney / DALL-E / Sora / etc.) is planner discretion based on availability + output quality; user reviews and approves the chosen render before vectorization.
- **D-02:** **Three variants ship in v1.0: light + dark + tinted.** All 1024² PNG, same arcade-machine subject retoned per appearance — light = warm cabinet, dark = neon-glow cabinet, tinted = monochrome silhouette. AppIcon.appiconset Contents.json already wired for all three slots from P1.
- **D-03:** **SVG vector master committed to repo at `assets/icon/`** (sibling to `gamekit/`). One master per variant (`light.svg`, `dark.svg`, `tinted.svg`) — re-exportable, diffable in PRs, future-proof. PNG renders ship at `gamekit/Assets.xcassets/AppIcon.appiconset/`. If the AI raster output is high-quality enough that vectorization adds no value, ship the raster as the master under `assets/icon/source/` and document that decision in the icon plan — planner discretion (Discretion #4).

### CloudKit Production Schema Deploy (SC1 + SC3 + Pitfall 11)
- **D-04:** **Method = CloudKit Dashboard "Deploy to Production" button.** Apple-blessed path. One-click promotion of all Development record types + indexes. Reversible per record-type until the first Production write. Planner does NOT call `initializeCloudKitSchema()` against the Production environment (riskier — creates types in user-visible env via app code).
- **D-05:** **Timing = BEFORE the first TestFlight upload.** Sequence: real icon → schema promote → archive → TestFlight upload → Internal Tester invite → SC3 2-device sweep. Production schema must exist before any TestFlight tester signs in, or SC3 fails on missing record types.
- **D-06:** **Verification has three rungs:** (1) toggle Dashboard env to Production, visually confirm `CD_GameRecord` + `CD_BestTime` record types exist with the same indexes as Development; (2) confirm container ID `iCloud.com.lauterstar.gamekit` is unchanged (P1 D-10 lock); (3) the SC3 2-device TestFlight sign-in sweep proves data actually flows. All three captured in 07-VERIFICATION.md.

### App Store Metadata + Submission Package (SC1 + SC2 + SC5)
- **D-07:** **All metadata authored in P7** — description, subtitle (≤30 char), keywords (100 char), promotional text, support URL, marketing URL, privacy policy URL, screenshots. No deferred fields. Submission-ready when the metadata plan ships.
- **D-08:** **Privacy policy hosted on GitHub Pages of the GameKit repo as a stopgap.** Enable Pages on the `main` branch (or `gh-pages`), publish `/docs/privacy.md` (or root `privacy.md` per Pages config), capture the resulting `https://<user>.github.io/GameKit/privacy.html` (or equivalent) URL in App Store Connect. Future state: a separate `GameKitWebsite` repo will own the public site and the privacy path will redirect there. App Store URL update at that point is a one-line metadata edit, no resubmit needed.
- **D-09:** **Screenshots = simulator captures with theme-matrix mix.** iPhone 15 Pro Max simulator (or whichever 6.7"+ slot Apple currently requires). Minimum 5 shots, mixing presets across categories so the App Store page itself sells the differentiator (theme system). Planner picks the specific blend (recommend: Classic Forest / Sweet Bubblegum / Bright Voltage / Moody Dracula / Loud Maroon — one per category; final blend is Discretion #2). Shots reusable as the SC4 audit artifact where compositions overlap.
- **D-10:** **Marketing URL pattern = `(name).lauterstar.com`** — the public app name is **TBD**. The repo name "GameKit" is a working title; the App Store name may differ. Planner picks the public name during the metadata-authoring plan (Discretion #1) and the Marketing URL field is populated with the resolved subdomain.
- **D-11:** **Description / subtitle / keywords / promotional text = planner-authored, user-reviewed before submission.** Promo copy honors PROJECT.md "Calm, premium, fully theme-customizable gameplay with zero friction — no ads, no coins, no pushy subscriptions, no required accounts" verbatim positioning. The differentiator IS the marketing.
- **D-12:** **Privacy nutrition label answered "Data Not Collected"** (SC2 verbatim) with reasoning text captured in 07-CHECKLIST.md: *"CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit not integrated → Data Not Collected"* (Pitfall 11 mitigation). Reasoning recorded in advance, not in a 2-minute submission rush.

### Theme-Matrix Audit Method (SC4)
- **D-13:** **Manual screenshots saved as artifact at `.planning/phases/07-release/screenshots/`.** Minimum 12 (6 DesignKit categories × play state + loss state). Screenshots are eye-only verification with a checklist tick in 07-CHECKLIST.md per row. P7 does NOT ship XCTest snapshot infrastructure — automated snapshot harness is a v1.x concern when there's a 2nd game to amortize the setup cost across.
- **D-14:** **Warm-accent flag-vs-mine check = separate manual shots on Forest + Ember + Voltage + Maroon, loss state**, recorded in 07-CHECKLIST.md with an explicit "flag color distinct from mine indicator" tick per preset. SC4 explicitly singles out the warm-accent risk; surface separately rather than fold into the main matrix.

### TestFlight Rollout (SC5)
- **D-15:** **Internal-only TestFlight (no External Beta, no Public Link).** Internal testers (you + up to 99 invitees) auto-approved by App Store Connect — no Beta App Review wait. Personal-first product. Honors SC5 verbatim. External Beta + Public Link deferred to v1.x or post-launch.
- **D-16:** **Soak duration = adaptive 1 day to 1 week, depending on test results.** Submit to App Review when the SC1–SC5 sweep is clean and no Xcode Organizer crash reports surface from real-world play sessions. No quantitative crash-free-session gate (would require analytics; PROJECT.md non-negotiable says no).

### Pre-Submission Tech Debt (from v1.0-MILESTONE-AUDIT.md)
- **D-17:** **P5 G-1 (CAF audio files missing) = punt to v1.0.1 polish.** Silent fallback is acceptable v1 ship state per P5 D-12 contract; SFX is off by default per SC2 verbatim. Adding CAFs in P7 expands scope into asset sourcing + audible verification. v1.0.1 picks them up as a tiny dot-release.
- **D-18:** **Doc-drift cleanup = FIRST plan of P7, before icon work.** Refresh ROADMAP.md plan-completion counts (P3 → 4/4, P4 → 6/6, P5 → Complete, P6 → 9/9 Complete), sync REQUIREMENTS.md checkboxes (35/35 marked validated where verification has actually shipped), mark 06-VERIFICATION.md status from `pending` → `complete` (06-UAT.md already shows 6/6 SC pass + 06-VALIDATION.md signed off 2026-04-27), advance STATE.md current_position from "06-09 Task 1 complete; Task 2 BLOCKING checkpoint awaiting human verification" to Phase 7 with a fresh timestamp. Single docs-only commit at the start of the phase.

### Claude's Discretion
The user did not lock the following — planner has flexibility but should align with research / CLAUDE.md / ARCHITECTURE.md:

1. **Public app name** (D-10) — TBD. Planner picks during the metadata-authoring plan, surfaces the candidate to the user before App Store Connect entry. Constraints: must be available on App Store Connect, must work as `<name>.lauterstar.com` subdomain, should signal the "calm classic games" posture.
2. **Specific 5-preset blend for screenshots** (D-09) — recommend Classic Forest + Sweet Bubblegum + Bright Voltage + Moody Dracula + Loud Maroon (one per non-Soft category, plus Classic) — final blend is planner's call based on which compositions render best at marketing-screenshot scale. Soft category may be substituted if Bubblegum overlaps Bright too closely.
3. **Release checklist file location** — recommend `.planning/phases/07-release/07-CHECKLIST.md` as the canonical artifact (phase-local survives milestone archive) + optional summary stub at `Docs/release-checklist.md` pointing into it for repo-root discoverability. SC5 says ".planning/Docs/ (or equivalent)" — phase-local qualifies as equivalent.
4. **Vectorize the AI raster output by hand vs ship raster as master** — depends on AI output quality. If clean, vectorize via Affinity Designer / Inkscape into proper SVGs at `assets/icon/`. If the raster is good enough that vectorization adds no fidelity, ship the high-res PNG as the master under `assets/icon/source/` and the appiconset PNGs as derived exports — document the decision in the icon plan.
5. **AI service for icon generation** — Midjourney / DALL-E / Sora / Ideogram / etc. Planner picks based on availability + output quality. User reviews + approves the chosen render before SVG vectorization or PNG export.
6. **MetricKit integration in v1.0** — Pitfall 11 reasoning text notes "MetricKit acceptable" as part of the privacy posture, but actually integrating it adds runtime surface and a tiny posture risk. Recommend: do **NOT** ship MetricKit in v1.0; revisit if crash data is needed post-launch. The privacy reasoning explicitly says "MetricKit not integrated" (D-12) — keep it that way unless decided otherwise.
7. **Version + build numbering** — recommend `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` for the first TestFlight upload; bump `CURRENT_PROJECT_VERSION` (build number) on each subsequent TestFlight upload, leave `MARKETING_VERSION` at `1.0` until a feature-bearing dot-release.
8. **GitHub Pages enable mechanics** — Pages can ship from `main /docs`, `main /` root, or `gh-pages` branch. Planner picks; recommend `main /docs/` so privacy policy lives alongside `Docs/derived-data-hygiene.md`. Resolved URL captured exactly in App Store Connect.
9. **Plan ordering inside P7** — recommend: (1) doc-drift cleanup (D-18), (2) icon production (D-01..D-03), (3) Production schema deploy (D-04..D-06), (4) metadata authoring (D-07..D-12) + privacy policy + screenshots, (5) checklist authoring (07-CHECKLIST.md) + 07-VERIFICATION.md template, (6) TestFlight upload + manual SC1–SC5 sweep, (7) submit to App Review. Wave-3 closing plan blocks on user sign-off.
10. **Whether `.planning/Docs/` directory should exist** — SC5 mentions it explicitly. Recommend NOT creating an empty `.planning/Docs/` just to satisfy the literal — the phase-local checklist + the optional `Docs/release-checklist.md` summary already qualify as "or equivalent" per SC5's literal wording.

### Folded Todos
None — todo system not queried; user has not raised pending todos relevant to release scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project rules + invariants
- `CLAUDE.md` — Project constitution (§1 stack/data-safety/no-Color/no-account-required, §2 DesignKit conventions, §8.7 Finder-dupe hygiene, §8.8 do-not-hand-patch-pbxproj, §8.10 atomic commits, §8.12 theme matrix legibility = ship blocker)
- `AGENTS.md` — Mirror of CLAUDE.md
- `.planning/PROJECT.md` — Vision + non-negotiables (CloudKit container ID `iCloud.com.lauterstar.gamekit`; "no analytics", "no required accounts", "Apple-native only" posture; bundle prefix `com.lauterstar.*`)
- `.planning/REQUIREMENTS.md` — All 35 v1 requirements; v2 deferred list (alt-icons + App Shortcuts in DIST-V2-01/02 — confirms P7 ships single AppIcon set)
- `.planning/ROADMAP.md` — Phase 7 entry: goal, SC1–SC5, "no new REQ-IDs — ship gate that verifies cross-cutting invariants from earlier phases"
- `.planning/v1.0-MILESTONE-AUDIT.md` — Tech-debt inventory feeding D-17 (G-1 CAF audio) and D-18 (ROADMAP/REQUIREMENTS/STATE/06-VERIFICATION drift)

### Architecture + research
- `.planning/research/PITFALLS.md` Pitfall 11 (App Store / TestFlight gotchas — load-bearing for D-04 Dashboard method, D-08 privacy reasoning verbatim, D-12 nutrition label answer, D-15 internal-only posture)
- `.planning/research/PITFALLS.md` Pitfall 3 (silent CloudKit sync failures — D-04 / D-06 Production schema deploy verification)
- `.planning/research/PITFALLS.md` Pitfall 4 (anonymous-to-signed-in promotion — confirms P7 schema promote does not migrate user data; existing local rows mirror up automatically per P6 D-08)
- `.planning/research/STACK.md` (build versioning, MARKETING_VERSION / CURRENT_PROJECT_VERSION conventions)
- `.planning/research/ARCHITECTURE.md` Pattern 5 (Conditional CloudKit via ModelConfiguration Swap at App Boot — confirms P7 introduces no live container reconfig; CloudKit promote is a Dashboard op, app code unchanged)

### Prior phase decisions (consumed, do NOT modify)
- `.planning/phases/01-foundation/01-CONTEXT.md` — Bundle ID `com.lauterstar.gamekit` lock, container ID `iCloud.com.lauterstar.gamekit` lock, capabilities baseline, AppIcon.appiconset 3-slot Contents.json (P1 ships placeholders that P7 replaces)
- `.planning/phases/04-stats-persistence/04-CONTEXT.md` — D-08 ModelConfiguration cloudKitDatabase reads `cloudSyncEnabled`; P7 promotes the schema that this configuration points at, no code change in P7
- `.planning/phases/05-polish/05-CONTEXT.md` — D-12 SFX silent-fallback contract (D-17 punt rationale); D-21 IntroFlow SIWA placeholder context (already wired in P6)
- `.planning/phases/06-cloudkit-siwa/06-CONTEXT.md` — D-04..D-06 Restart-prompt copy verbatim, D-09 Settings SYNC section structure, D-10 sync-status row labels (SC4 verifies these render correctly under Production CloudKit), Discretion #7 (Schema deploy timing — P6 used Development, P7 promotes to Production)
- `.planning/phases/06-cloudkit-siwa/06-VERIFICATION.md` — Template format precedent for `07-VERIFICATION.md` (verbatim copy locks, gap log, sign-off table)

### Existing source files (referenced, mostly unchanged in P7)
- `gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/Contents.json` — 3-slot wiring (light universal, dark luminosity, tinted) already correct from P1; P7 swaps the 3 PNG files only
- `gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/{icon-light,icon-dark,icon-tinted}.png` — placeholders to be replaced
- `gamekit/gamekit.entitlements` — `com.apple.developer.applesignin` (P5 + P6); SC1 verifies unchanged at submission
- `gamekit.xcodeproj/project.pbxproj` — `PRODUCT_BUNDLE_IDENTIFIER = com.lauterstar.gamekit` (P1 lock), CloudKit container ID, MARKETING_VERSION, CURRENT_PROJECT_VERSION fields. SC1 + Pitfall 11 verify no drift; pre-commit hook from P1 already flags PRODUCT_BUNDLE_IDENTIFIER changes
- `Docs/derived-data-hygiene.md` — sibling for the optional `Docs/release-checklist.md` summary stub

### NEW artifacts (P7 ships)
- `assets/icon/{light,dark,tinted}.svg` (or `assets/icon/source/*.png` if Discretion #4 ships raster master) — vector / raster master for the arcade-machine icon
- `gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/{icon-light,icon-dark,icon-tinted}.png` — re-exported from masters, 1024² each
- `.planning/phases/07-release/07-CHECKLIST.md` — release master checklist
- `.planning/phases/07-release/07-VERIFICATION.md` — manual SC1–SC5 verification template
- `.planning/phases/07-release/screenshots/` — 12+ theme-matrix shots + 4 warm-accent flag shots
- `Docs/release-checklist.md` (optional summary stub, Discretion #3)
- `docs/privacy.md` (or repo-root `privacy.md`, depending on GitHub Pages config — Discretion #8) — privacy policy text matching the "Data Not Collected" reasoning verbatim
- App Store Connect entries — description, subtitle, keywords, promo text, support URL, marketing URL, privacy URL, screenshots (external system; not a file in the repo, captured by reference in 07-CHECKLIST.md)

### Apple frameworks + external systems
- App Store Connect — submission portal; metadata + screenshots + privacy nutrition label live here
- TestFlight — Internal Testing tab (auto-approval, no Beta App Review)
- CloudKit Dashboard — Schema → Deploy to Production button (D-04); Production environment Records browser for SC1 record-type verification
- Xcode Organizer — crash reports during soak (D-16); no analytics SDK, so this is the only crash data source
- GitHub Pages — privacy policy hosting (D-08)
- Apple "User Privacy and Data Use" guidance — referenced when filling the App Privacy questionnaire (Pitfall 11)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`AppIcon.appiconset/Contents.json`** (P1) — 3-slot wiring (universal light, luminosity-dark, tinted) is already correct. P7 swaps only the 3 PNG files; no JSON edit needed.
- **06-VERIFICATION.md template** (P6, 237 lines) — direct precedent for `07-VERIFICATION.md` shape: verbatim copy locks, fallback-used frontmatter, gap log with Critical/Major/Minor severity, sign-off table mapped to SC1–SCN.
- **`gamekit.entitlements`** (P5 + P6) — already declares `com.apple.developer.applesignin`. SC1 + Pitfall 11 verification = read this file + diff against the project.pbxproj capabilities block; no edit in P7.
- **`Docs/derived-data-hygiene.md`** (P1) — repo-root doc precedent. Optional `Docs/release-checklist.md` summary stub (Discretion #3) follows the same shape.

### Established Patterns
- **Wave-3 closing plan format** (P3-04, P5-07, P6-09) — checklist-style with verbatim copy locks, gap log, sign-off table mapped to SC1–SCN. P7's checklist + verification plans inherit this shape directly.
- **Manual checkpoint plan** — P3-04 / P5-07 / P6-09 each block on user-driven verification on real hardware. P7 inherits the same model: SC1–SC5 sweep is human-run, not agent-run.
- **Atomic commits per CLAUDE.md §8.10** — doc-drift cleanup (D-18), icon swap, schema promote (no code change, just a checklist tick), metadata authoring, checklist authoring, screenshot capture each ship as separate commits.
- **Same on-disk store across schema environments** (P4 D-08 + Pitfall 4 + ARCHITECTURE Pattern 5) — promoting Dev → Production in CloudKit Dashboard does NOT touch local SQLite; existing local rows mirror up to Production once the user is signed in. Confirms P7 schema promote is asset-only, not code.

### Integration Points
- **`Assets.xcassets/AppIcon.appiconset/`** — drop the 3 new PNG files in place of the placeholders; Xcode 16 synchronized root group auto-registers (CLAUDE.md §8.8). Verify via Xcode preview before committing.
- **CloudKit Dashboard** — external system; Production tab → Schema → Deploy. No code change in the repo, but the action is captured as a checklist row + a screenshot in `.planning/phases/07-release/screenshots/dashboard-deploy.png`.
- **App Store Connect** — external system; metadata fields populated manually. 07-CHECKLIST.md captures each field's exact value as a sign-off row so a future re-submission can replicate.
- **TestFlight tab → Internal Testing → Add Testers** — invite list captured in 07-CHECKLIST.md (NOT in the repo for privacy).
- **`project.pbxproj` MARKETING_VERSION / CURRENT_PROJECT_VERSION** — bumped via Xcode UI, NOT hand-patched per CLAUDE.md §8.8. CI hook from P1 already validates `PRODUCT_BUNDLE_IDENTIFIER` is unchanged.
- **GitHub Pages settings** — Repo → Settings → Pages → Source = `main /docs` (Discretion #8 recommendation). Privacy policy markdown committed to `docs/privacy.md`; resolved URL captured in 07-CHECKLIST.md + App Store Connect.

</code_context>

<specifics>
## Specific Ideas

- Icon concept verbatim: **"old school arcade machine"** — vintage cabinet aesthetic. AI-generated, then optionally vectorized per Discretion #4.
- Icon master path: `assets/icon/` at repo root. Three files (`light.svg` / `dark.svg` / `tinted.svg`) or three rasters under `source/` — planner discretion based on AI output.
- Icon variant rule: **same arcade-machine subject, retoned per appearance** (light = warm cabinet, dark = neon-glow, tinted = monochrome silhouette). NOT three different scenes/angles.
- AppIcon target paths: `gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/{icon-light.png, icon-dark.png, icon-tinted.png}` — placeholders replaced in place.
- CloudKit Production deploy method: **Dashboard "Deploy to Production" button** (NOT `initializeCloudKitSchema()` against Production).
- CloudKit Production deploy timing: **before the first TestFlight upload**.
- CloudKit Production deploy verification triple: Dashboard env toggle to Production + visual `CD_GameRecord` + `CD_BestTime` record-type confirmation + SC3 2-device TestFlight sweep.
- Privacy nutrition label answer: **"Data Not Collected"** (verbatim).
- Privacy reasoning text (verbatim, captured in 07-CHECKLIST.md): *"CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit not integrated → Data Not Collected"*.
- Privacy URL host (stopgap): **GitHub Pages on the GameKit repo** at `<user>.github.io/GameKit/privacy.html` (or equivalent per Pages config).
- Privacy URL host (future): GameKitWebsite repo will own the public site; App Store metadata redirect = one-line edit, no resubmit needed.
- Marketing URL pattern: `(name).lauterstar.com` — public app name **TBD**, planner picks during metadata authoring.
- Public app name: NOT necessarily "GameKit" (repo working title); App Store name decided in metadata plan.
- Screenshots: **simulator captures, theme-matrix mix**, minimum 5 for the 6.7"+ iPhone slot. Recommended preset blend (Discretion #2): Classic Forest + Sweet Bubblegum + Bright Voltage + Moody Dracula + Loud Maroon.
- Screenshot artifact path: `.planning/phases/07-release/screenshots/`.
- Theme-matrix audit minimum: **12 manual screenshots** (6 categories × play state + loss state).
- Warm-accent flag-vs-mine check: **separate manual shots on Forest + Ember + Voltage + Maroon**, loss state, with explicit "flag color distinct from mine indicator" tick per preset in 07-CHECKLIST.md.
- TestFlight scope: **Internal-only** (no External Beta, no Public Link).
- TestFlight soak duration: **adaptive 1 day to 1 week**, depending on test results — submit when SC1–SC5 sweep is clean and Xcode Organizer shows no crashes.
- Version + build (Discretion #7 recommendation): `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` for first upload.
- P5 G-1 disposition: **punt to v1.0.1 polish** (silent fallback acceptable per P5 D-12).
- Doc-drift cleanup: **first plan of P7**, single docs-only commit.
- Bundle ID re-verification: `com.lauterstar.gamekit` (P1 lock) — read from `project.pbxproj`, confirm unchanged. Pre-commit hook already enforces.
- Container ID re-verification: `iCloud.com.lauterstar.gamekit` (P1 D-10 lock) — read from entitlements + project.pbxproj, confirm unchanged.

</specifics>

<deferred>
## Deferred Ideas

- **P5 G-1 CAF audio** (`tap.caf` / `win.caf` / `loss.caf`) — v1.0.1 polish point release. Silent SFX is the current ship state and acceptable.
- **External TestFlight Beta + Public Link** — v1.x or post-launch when there's a broader audience to surface to.
- **MetricKit integration** — explicitly NOT v1.0. Revisit if crash insight is needed post-launch; would require a privacy-label re-evaluation.
- **GameKitWebsite repo** — separate project. Owns the public site once it lands; privacy URL redirects from GitHub Pages stopgap to the new domain at that point.
- **Public app name lock** — TBD until planner authors the metadata plan. The repo name "GameKit" is a working title.
- **Vectorize the AI raster output** — depends on AI output quality; planner picks vector vs raster master.
- **Per-game alt-icon variants (DIST-V2-01)** — REQUIREMENTS v2; not v1.0.
- **App Shortcuts (DIST-V2-02)** — REQUIREMENTS v2.
- **Automated XCTest snapshot grid for theme matrix** — v1.x when there's a 2nd game to amortize the setup cost.
- **Crash-free-session quantitative gate** — would require analytics; PROJECT.md non-negotiable says no. Soak posture is qualitative, Xcode Organizer–driven.
- **Submission-day rollback / contingency plan** — App Review reject + schema-deploy-rollback paths are not pre-authored. If a reject happens, handle inline (typically a metadata edit + resubmit). CloudKit Production schema rollback is per-record-type via Dashboard until first Production write; once user data lands, additive-only.
- **`.planning/Docs/` directory** — SC5 names it explicitly but allows "or equivalent." Phase-local + optional repo-root `Docs/release-checklist.md` summary stub qualifies; not creating an empty `.planning/Docs/` just to satisfy the literal.
- **Crash reporting / analytics** — permanent NEVER per PROJECT.md.

</deferred>

---

*Phase: 07-release*
*Context gathered: 2026-04-27*
