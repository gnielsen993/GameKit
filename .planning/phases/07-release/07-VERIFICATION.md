---
phase: 07-release
type: verification
sc_count: 5
status: pending  # pending | in_progress | complete | blocked
signed_off_by: ""
signed_off_date: ""
fallback_used:    # set if 2-sim TestFlight fallback used for SC3 (Pitfall C)
---

# Phase 7 — Manual SC1-SC5 Verification Checklist

> Per CONTEXT D-18 + ROADMAP Phase 7 SC1-SC5: this template proves
> the v1.0 binary, the App Store Connect metadata, the CloudKit
> Production schema, and the TestFlight Internal-only build
> satisfy SC1-SC5. Filled in by Plan 07-06 after the manual sweep.
>
> Mirrors 06-VERIFICATION.md shape: verbatim copy locks, evidence
> fields, gap log with severity scale, sign-off table.

---

## Pre-flight

- [ ] Plan 07-01 (doc-drift cleanup) signed off — STATE.md = Phase 7 in progress
- [ ] Plan 07-02 (icon production) signed off — `feat(07-02): real arcade-machine app icon` in git log
- [ ] Plan 07-03 (CloudKit Production schema deploy) signed off — `chore(07-03): record CloudKit Production schema deploy` in git log
- [ ] Plan 07-04 (App Store metadata + privacy + screenshots) signed off — `feat(07-04): privacy policy + theme-matrix + warm-accent screenshots` in git log
- [ ] Plan 07-05 (this checklist + verification template) signed off — `docs(07-05): release checklist + SC1-SC5 verification template` in git log
- [ ] CloudKit Dashboard Production env shows `CD_GameRecord` + `CD_BestTime` record types (verification rung 1, screenshot exists)
- [ ] App Store Connect metadata draft saved (NOT submitted)
- [ ] GitHub Pages live at the privacy URL captured in 07-CHECKLIST.md PF-05
- [ ] Apple Developer Program membership active

**Test environment**:
- Real iCloud account confirmed accessible: ☐ yes / ☐ no — fallback: 2-TestFlight-device with ≤60s lag
- 2 real devices on same iCloud account: ☐ yes / ☐ no
- iPhone test device(s) iOS version: _____________
- TestFlight Internal-only build number: _____________

---

## SC1 — Real app icon + CloudKit schema promoted + container ID stable

**Verbatim from ROADMAP (do NOT paraphrase):**

> Real app icon (replacing the placeholder from FOUND-06) ships in `Assets.xcassets`; CloudKit schema has been promoted from Development to Production in CloudKit Dashboard (verified by toggling environment); `iCloud.com.lauterstar.gamekit` container ID is identical to P1's lock and unchanged in `Info.plist` / entitlements.

**Test instructions:**
1. Confirm the TestFlight build's Home Screen icon shows the real arcade-machine art (light, dark, tinted appearances) — NOT the P1 placeholder.
2. Open `https://icloud.developer.apple.com/dashboard/` → container `iCloud.com.lauterstar.gamekit` → Schema → toggle Environment to Production. Confirm `CD_GameRecord` + `CD_BestTime` appear with same indexes as Development.
3. From the repo: `grep -F "iCloud.com.lauterstar.gamekit" gamekit/gamekit/gamekit.entitlements` — expect at least one match.
4. From the repo: `grep -F "iCloud.com.lauterstar.gamekit" gamekit.xcodeproj/project.pbxproj` — expect at least one match.
5. From the repo: `grep -E "PRODUCT_BUNDLE_IDENTIFIER = com\.lauterstar\.gamekit" gamekit.xcodeproj/project.pbxproj` — expect at least one match (typically one per build configuration).
6. From Xcode → Targets → gamekit → Signing & Capabilities pane: confirm capabilities listed are: Sign in with Apple ✓, iCloud / CloudKit ✓ (with container `iCloud.com.lauterstar.gamekit`), Background Modes (Remote notifications) ✓.

**Expected:** All 6 steps pass. Icon is the real arcade-machine art; container ID + bundle ID intact; capabilities present.

**Evidence:**
- [ ] Step 1 Home Screen icon photo (light + dark + tinted accents): __________
- [ ] Step 2 Production schema screenshot (cross-references `dashboard-production-recordtypes.png`): __________
- [ ] Step 3 grep transcript: __________
- [ ] Step 4 grep transcript: __________
- [ ] Step 5 grep transcript: __________
- [ ] Step 6 capabilities pane screenshot: __________

**Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED-WITH-REASON

**Observed gaps:** _______________________________________________

---

## SC2 — Privacy nutrition label "Data Not Collected" with verbatim reasoning

**Verbatim from ROADMAP (do NOT paraphrase):**

> Privacy nutrition label is answered "Data Not Collected" with documented reasoning ("CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit acceptable") and matches the binary; the label was decided in advance, not in a 2-minute submission rush.

**Verbatim D-12 reasoning (must match the App Store Connect rationale):**

> CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit not integrated → Data Not Collected

**Test instructions:**
1. Open `https://appstoreconnect.apple.com/apps` → select the app → **App Privacy** tab.
2. Confirm the panel header reads **Data Not Collected**.
3. From the repo: `grep -ri "FIRApp\|Sentry\|Bugsnag\|Mixpanel\|GoogleAnalytics" gamekit/` — expect ZERO matches (no analytics SDKs in the binary).
4. From the repo: `grep -ri "MetricKit\|MXMetricManager" gamekit/` — expect ZERO matches (Discretion #6 — MetricKit not integrated v1.0).
5. Confirm the App Store Connect privacy URL field resolves the GitHub Pages markdown — open in a fresh browser tab, confirm the policy renders, confirm the verbatim reasoning string appears in the markdown.
6. Read the privacy policy markdown at `docs/privacy.md` and confirm the verbatim reasoning string appears: `grep -F "CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit not integrated → Data Not Collected" docs/privacy.md`.

**Expected:** All 6 steps pass. Privacy label matches the binary (which collects nothing).

**Evidence:**
- [ ] Step 2 ASC App Privacy screenshot: __________
- [ ] Step 3 grep transcript (no analytics SDKs): __________
- [ ] Step 4 grep transcript (no MetricKit): __________
- [ ] Step 5 privacy URL screenshot from browser: __________
- [ ] Step 6 markdown grep transcript: __________

**Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED-WITH-REASON

**Observed gaps:** _______________________________________________

---

## SC3 — SIWA verified in Production via TestFlight + 2-device sync sweep

**Verbatim from ROADMAP (do NOT paraphrase):**

> Sign in with Apple is verified working in the **production** environment via TestFlight (not just dev sandbox); CloudKit sync is verified working in TestFlight by signing in on two TestFlight devices and watching stats sync.

**Test setup (Pitfall C lookbacks):**
- **Preferred:** 2 real devices, both on TestFlight, on the same iCloud account.
- **Fallback (acceptable):** 2 simulators with TestFlight builds installed via Xcode → same iCloud sign-in; expect ≤60s lag; mark `fallback_used: 2-sim` in frontmatter.

**Test instructions:**
1. Install the TestFlight Internal build on Device A.
2. Open the app → dismiss Intro → play 10 quick games (any difficulty/state). Confirm Stats screen shows 10 games played.
3. Settings → SYNC → Sign in with Apple → complete SIWA flow → Restart prompt appears (P6 D-04 verbatim copy).
4. Tap **Quit GameKit** → swipe up to terminate → relaunch.
5. Confirm SettingsView SYNC row 1 reads `"Signed in to iCloud"` and row 2 transitions through `"Syncing…"` → `"Synced just now"` within 10–60 seconds.
6. Install the TestFlight Internal build on Device B (same iCloud account; if Device B is the same physical device as A, delete + reinstall first to clear Keychain).
7. Sign in on Device B via Settings → SIWA → tap Quit → relaunch.
8. Wait up to 60s for CloudKit import.
9. On Device B: open Stats. Confirm all 10 games from Device A appear (counts + best times match within last-writer-wins margin).
10. Play a new game on Device A → wait 30s → verify it appears on Device B's Stats screen.
11. **Production environment confirmation:** while signed in on Device A, open `https://icloud.developer.apple.com/dashboard/` → toggle to Production env → Records browser → confirm `CD_GameRecord` records exist for the test Apple ID. (This proves the writes hit Production, not Dev sandbox.)

**Expected:** SIWA succeeds against Production; sync converges across both devices within 60s; Records browser shows the writes in Production.

**Evidence:**
- [ ] Device A SIWA completion screenshot: __________
- [ ] Device A `Synced just now` screenshot: __________
- [ ] Device B Stats screenshot (post-sync, 10 games visible): __________
- [ ] Cross-device-sync timestamp screenshot (Device A new game → Device B): __________
- [ ] CloudKit Dashboard Production Records screenshot showing test writes: __________
- [ ] If 2-sim fallback used, document observed lag in seconds: __________

**Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED-WITH-REASON

**Observed gaps:** _______________________________________________

---

## SC4 — Theme-matrix legibility audit + warm-accent flag-vs-mine

**Verbatim from ROADMAP (do NOT paraphrase):**

> Final theme-matrix legibility audit passes: a Hard board sample renders correctly on at least one preset from each DesignKit category for play state AND loss state; flag color verified distinct from mine indicator on warm-accent presets (Forest / Ember / Voltage / Maroon).

**Test instructions:**
1. On the TestFlight build (Device A, REAL hardware — not just simulator), open Settings → APPEARANCE → More themes & custom colors.
2. For each of 6 categories, select one preset and load a Hard game:
   - Classic / Forest
   - Sweet / Bubblegum
   - Bright / Voltage
   - Soft / (the Soft preset chosen in 07-04 Task 3)
   - Moody / Dracula
   - Loud / Maroon
3. For each preset:
   - Play state — confirm mines, numbers (1-8), flags, unrevealed cells are all legible.
   - Loss state — tap-mine for instant loss; confirm revealed mine indicator + remaining flags + numbers are all legible.
4. **Warm-accent flag-vs-mine specific check** (D-14): for Forest, Ember, Voltage, Maroon — place at least one flag on a Hard board, then tap-mine. Confirm in the loss frame: the flag glyph is visually distinct from the revealed mine indicator (different color OR different shape, ideally both).
5. Cross-reference the static screenshots in `.planning/phases/07-release/screenshots/themes/` and `.planning/phases/07-release/screenshots/warm-accent/` for any preset where real hardware diverges from simulator output.

**Expected:** All 6 categories legible; all 4 warm-accent presets have flag-vs-mine distinct.

**Evidence:**
- [ ] Real-hardware photo for each of 6 presets (play + loss): __________
- [ ] Real-hardware photo for warm-accent flag-vs-mine on Forest: __________
- [ ] Real-hardware photo for warm-accent flag-vs-mine on Ember: __________
- [ ] Real-hardware photo for warm-accent flag-vs-mine on Voltage: __________
- [ ] Real-hardware photo for warm-accent flag-vs-mine on Maroon: __________
- [ ] Any preset where real hardware diverges from simulator (note + photo): __________

**Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED-WITH-REASON

**Observed gaps:** _______________________________________________

---

## SC5 — Release checklist documented + TestFlight build uploaded + Internal Testers invited

**Verbatim from ROADMAP (do NOT paraphrase):**

> Release checklist documented in `.planning/Docs/` (or equivalent) covering every step: capabilities verified, entitlements diffed, schema promoted, container ID stable, label completed, SIWA tested in production. TestFlight build is uploaded, internal testers invited.

**Test instructions:**
1. Confirm `.planning/phases/07-release/07-CHECKLIST.md` exists and has rows for every release-gate invariant ("phase-local equivalent" per Discretion #10 — SC5 says "or equivalent").
2. Confirm Pre-flight rows PF-01..PF-09 ticked.
3. Confirm SC1-SC4 sign-off rows ticked.
4. From the repo: `grep -E "MARKETING_VERSION = 1\.0" gamekit.xcodeproj/project.pbxproj` (Discretion #7 — set via Xcode UI; CLAUDE.md §8.8 forbids hand-patch).
5. From the repo: `grep -E "CURRENT_PROJECT_VERSION = 1" gamekit.xcodeproj/project.pbxproj` (Discretion #7).
6. Open App Store Connect → TestFlight → Internal Testing tab → confirm a build appears with `Build = 1` (or whichever incremented value) and Internal Tester(s) are invited (D-15).
7. Open Xcode → Window → Organizer → Crashes tab → confirm zero crash reports during the 1-day-to-1-week soak window (D-16 adaptive).
8. DECISION GATE — if SC1-SC5 are all PASS or DEFERRED-WITH-REASON-DOCUMENTED and Organizer shows zero crashes → submit to App Review. Record the decision in 07-CHECKLIST.md SC5-I.

**Expected:** All 8 steps pass. SC5 closes with the App Review submission decision.

**Evidence:**
- [ ] Step 1 — `ls .planning/phases/07-release/07-CHECKLIST.md` output: __________
- [ ] Step 2-3 — 07-CHECKLIST.md screenshot showing all rows ticked: __________
- [ ] Step 4 grep transcript: __________
- [ ] Step 5 grep transcript: __________
- [ ] Step 6 ASC TestFlight Internal Testing screenshot: __________
- [ ] Step 7 Xcode Organizer Crashes tab screenshot (zero crashes): __________
- [ ] Step 8 App Review submission timestamp: __________

**Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED-WITH-REASON

**Observed gaps:** _______________________________________________

---

## Gap Log

Record any failures here. Each gap = a candidate plan for `/gsd-plan-phase 07 --gaps`.

| Gap ID | SC | Severity | Description | Remediation | Status |
|--------|----|----------|-------------|-------------|--------|
| (blank — no gaps yet) |    |          |             |             |        |

Severity scale:
- **Critical** (P0): blocks ROADMAP P7 close. Examples: SC1 container ID drifted; SC2 privacy label mismatches binary; SC3 SIWA fails in Production.
- **Major** (P1): functional regression. Examples: SC4 a preset is illegible at Hard board; SC5 TestFlight build won't upload.
- **Minor** (P2): cosmetic / polish. Examples: warm-accent flag color is barely-distinct (works but uncomfortable); ASC subtitle has a typo.

---

## Sign-off

| Criterion | Verifier | Date | Status |
|-----------|----------|------|--------|
| SC1 — Icon + schema + container ID |          |      | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC2 — Privacy nutrition label |          |      | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC3 — SIWA + 2-device sync in Production |          |      | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC4 — Theme-matrix + warm-accent legibility |          |      | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC5 — Checklist + TestFlight + Internal Testers |          |      | ☐ PASS / ☐ FAIL / ☐ DEFERRED |

Phase 7 close criteria:
- [ ] All 5 SCs PASS or DEFERRED-WITH-REASON-DOCUMENTED
- [ ] No Critical gaps open
- [ ] Major gaps converted to a P7 gap-closure plan via `/gsd-plan-phase 07 --gaps` OR explicitly accepted as v1.0.1 polish items

---

## Phase-Close Updates (after sign-off)

After ALL SCs PASS or DEFERRED:

- [ ] Update `.planning/ROADMAP.md` — Phase 7 row: status `In progress` → `Complete`; date filled
- [ ] Update `.planning/STATE.md` — `current_position` advances to "v1.0 shipped"; `progress.completed_phases` = 7
- [ ] Atomic commit `docs(07-06): SC1-SC5 verification checkpoint signed off — Phase 7 complete` per CLAUDE.md §8.10
- [ ] App Review submission decision recorded
