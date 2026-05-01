---
phase: 07-release
type: checklist
canonical: true
sc_count: 5
status: pending  # pending | in_progress | complete | blocked
signed_off_by: ""
signed_off_date: ""
---

# Phase 7 — Release Checklist (Canonical)

> Per CONTEXT D-18 + Discretion #3: this is the master release checklist
> for the v1.0 ship gate. Phase-local artifact (survives milestone archive).
> Optional summary stub at `Docs/release-checklist.md` points here.
>
> **SC5 wording note:** SC5 says ".planning/Docs/ (or equivalent)" —
> phase-local qualifies as "equivalent" per SC5's literal wording
> (Discretion #10).
>
> Rows ticked by Plan 07-06 after manual SC1-SC5 sweep.

---

## Pre-flight (must be complete before TestFlight upload)

| # | Invariant | Source | Status | Evidence |
|---|-----------|--------|--------|----------|
| PF-01 | Doc-drift cleanup landed | Plan 07-01 | ☑ | Verified 2026-05-01 — ROADMAP plan counts, REQUIREMENTS traceability, 06-VERIFICATION.md status, STATE.md current_position all aligned. Commit `d89968e docs(07-01): advance STATE.md to Phase 7 pre-flight + log GameDrawer rename`. |
| PF-02 | Real app icon shipped (light/dark/tinted), 1024² PNGs in AppIcon.appiconset | Plan 07-02 | ☑ | Commit `d03f1fa feat(branding): rebrand to PlayCore + stack-of-games icon + ASC export compliance` — three appearance variants in `gamekit/gamekit/Assets.xcassets/AppIcon.appiconset/`; provenance in `assets/icon/AI_PROVENANCE.md`. |
| PF-03 | CloudKit Production schema deployed via Dashboard "Deploy to Production" button | Plan 07-03, D-04 | ☑ | Deployed 2026-05-01. Dev schema materialized via auto-deploy block in GameKitApp.init() (commit `36d65c6`); Dashboard "Deploy Schema to Production" button promoted Dev → Prod. Screenshot evidence (optional) → `.planning/phases/07-release/screenshots/dashboard-deploy.png`. |
| PF-04 | Production schema verified — `CD_GameRecord` + `CD_BestTime` + `CD_BestScore` exist with same indexes as Development | Plan 07-03 verification rung 1, D-06 | ☑ | Verified 2026-05-01 via Dashboard Production env. All three CD_* types present (Merge added `CD_BestScore` to the original P6 spec of two types). Screenshot evidence (optional) → `.planning/phases/07-release/screenshots/dashboard-production-recordtypes.png`. |
| PF-05 | Privacy + Terms live on website (`gamedrawer.lauterstar.com/privacy.html` + `/terms.html`); Settings ABOUT rows link to them via `AppInfo.privacyURL` / `AppInfo.termsURL` | Plan 07-04 Tasks 1+2, D-08 (revised) | ☐ | Privacy URL: `https://gamedrawer.lauterstar.com/privacy.html` (DNS go-live pending). Terms URL: `https://gamedrawer.lauterstar.com/terms.html` (same). Code-side ✅ — AppInfo + SettingsAboutSection.swift land 2026-05-01. |
| PF-06 | 12 theme-matrix screenshots + 4 warm-accent screenshots captured | Plan 07-04 Task 3, D-13 + D-14 | ☐ | `.planning/phases/07-release/screenshots/themes/` (12 files) + `.planning/phases/07-release/screenshots/warm-accent/` (4 files) |
| PF-07 | Public app name locked | Plan 07-04 Task 4, Discretion #1 | ☑ | Locked name: `GameDrawer` (2026-05-01, `INFOPLIST_KEY_CFBundleDisplayName` Debug+Release in `gamekit.xcodeproj/project.pbxproj`) |
| PF-08 | App Store Connect metadata draft saved (description / subtitle / keywords / promo / URLs / screenshots / age / category / copyright) | Plan 07-04 Task 5, D-07 | ☐ | ASC pane screenshots in `.planning/phases/07-release/screenshots/asc/` |
| PF-09 | Privacy nutrition label answered "Data Not Collected" with verbatim reasoning | Plan 07-04 Task 6, D-12 + SC2 | ☐ | Reasoning: `CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit not integrated → Data Not Collected` |

---

## SC1 — Real app icon + CloudKit schema promoted + container ID stable

**Verbatim from ROADMAP (do NOT paraphrase):**

> Real app icon (replacing the placeholder from FOUND-06) ships in `Assets.xcassets`; CloudKit schema has been promoted from Development to Production in CloudKit Dashboard (verified by toggling environment); `iCloud.com.lauterstar.gamekit` container ID is identical to P1's lock and unchanged in `Info.plist` / entitlements.

| # | Sign-off row | Status | Evidence |
|---|--------------|--------|----------|
| SC1-A | Real arcade-machine app icon shipped (light/dark/tinted) | ☐ | git log + Xcode preview screenshot from 07-02 |
| SC1-B | CloudKit schema promoted Dev → Production via Dashboard | ☑ | Deployed 2026-05-01 — Production env now has CD_GameRecord + CD_BestTime + CD_BestScore (commit `36d65c6` GameKitApp auto-deploy block landed Dev schema; Dashboard "Deploy to Production" button promoted). |
| SC1-C | Container ID `iCloud.com.lauterstar.gamekit` unchanged in `gamekit/gamekit/gamekit.entitlements` | ☐ | `grep -F "iCloud.com.lauterstar.gamekit" gamekit/gamekit/gamekit.entitlements` |
| SC1-D | Container ID `iCloud.com.lauterstar.gamekit` unchanged in `gamekit.xcodeproj/project.pbxproj` | ☐ | `grep -F "iCloud.com.lauterstar.gamekit" gamekit.xcodeproj/project.pbxproj` |
| SC1-E | Bundle ID `com.lauterstar.gamekit` unchanged in `gamekit.xcodeproj/project.pbxproj` | ☐ | `grep -E "PRODUCT_BUNDLE_IDENTIFIER = com\.lauterstar\.gamekit" gamekit.xcodeproj/project.pbxproj` |
| SC1-F | Capabilities verified in Xcode → Targets → gamekit → Signing & Capabilities: Sign in with Apple ✓; iCloud / CloudKit ✓; Background Modes (Remote notifications) ✓ | ☐ | Xcode capabilities pane screenshot |
| SC1-G | Entitlements file `gamekit/gamekit/gamekit.entitlements` declares `com.apple.developer.applesignin` | ☐ | `grep -F "com.apple.developer.applesignin" gamekit/gamekit/gamekit.entitlements` |

**Verifier:** _______________  **Date:** ___________  **Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED

---

## SC2 — Privacy nutrition label "Data Not Collected" with verbatim reasoning

**Verbatim from ROADMAP (do NOT paraphrase):**

> Privacy nutrition label is answered "Data Not Collected" with documented reasoning ("CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit acceptable") and matches the binary; the label was decided in advance, not in a 2-minute submission rush.

**Verbatim D-12 reasoning (paste in App Store Connect rationale + this row):**

> CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit not integrated → Data Not Collected

| # | Sign-off row | Status | Evidence |
|---|--------------|--------|----------|
| SC2-A | App Store Connect "App Privacy" panel shows "Data Not Collected" | ☐ | `.planning/phases/07-release/screenshots/asc/07-app-privacy-data-not-collected.png` |
| SC2-B | Reasoning recorded verbatim: `CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit not integrated → Data Not Collected` | ☐ | This row's text |
| SC2-C | Reasoning matches the binary: zero analytics SDKs in `gamekit/` | ☐ | `! grep -ri "FIRApp\|Sentry\|Bugsnag\|Mixpanel\|GoogleAnalytics" gamekit/` returns no matches |
| SC2-D | MetricKit explicitly NOT integrated (Discretion #6) | ☐ | `! grep -ri "MetricKit\|MXMetricManager" gamekit/` returns no matches |
| SC2-E | Privacy policy URL on the binary's App Store page resolves to a public URL matching the same reasoning | ☐ | URL: `https://gamedrawer.lauterstar.com/privacy.html` (D-08 revised — custom domain replaces GitHub Pages stopgap; awaiting DNS go-live). |

**Verifier:** _______________  **Date:** ___________  **Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED

---

## SC3 — SIWA verified in Production via TestFlight + 2-device sync sweep

**Verbatim from ROADMAP (do NOT paraphrase):**

> Sign in with Apple is verified working in the **production** environment via TestFlight (not just dev sandbox); CloudKit sync is verified working in TestFlight by signing in on two TestFlight devices and watching stats sync.

| # | Sign-off row | Status | Evidence |
|---|--------------|--------|----------|
| SC3-A | TestFlight Internal-only build uploaded (D-15) | ☐ | TestFlight build number: `_____` |
| SC3-B | Internal Tester(s) invited (D-15 — captured in checklist, NOT in repo for privacy) | ☐ | Tester emails: `_______________________` |
| SC3-C | SIWA flow completes successfully on TestFlight build (Production env, NOT Dev sandbox) | ☐ | Device A SIWA screenshot |
| SC3-D | Device A signed in → restart → cloud sync of stats begins | ☐ | Device A `Synced just now` screenshot |
| SC3-E | Device B signed in to same Apple ID → all Device A stats appear within 60s | ☐ | Device B Stats screenshot showing Device A's records |
| SC3-F | New gameplay on Device A propagates to Device B within 30s | ☐ | Cross-device timestamp match screenshot |

**Verifier:** _______________  **Date:** ___________  **Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED

---

## SC4 — Theme-matrix legibility audit + warm-accent flag-vs-mine

**Verbatim from ROADMAP (do NOT paraphrase):**

> Final theme-matrix legibility audit passes: a Hard board sample renders correctly on at least one preset from each DesignKit category for play state AND loss state; flag color verified distinct from mine indicator on warm-accent presets (Forest / Ember / Voltage / Maroon).

| # | Sign-off row | Status | Evidence |
|---|--------------|--------|----------|
| SC4-A | Classic preset (Forest) — play + loss legible (mines/numbers/flags readable) | ☐ | `themes/classic-forest-easy-play.png` + `themes/classic-forest-easy-loss.png` |
| SC4-B | Sweet preset (Bubblegum) — play + loss legible | ☐ | `themes/sweet-bubblegum-easy-play.png` + `themes/sweet-bubblegum-easy-loss.png` |
| SC4-C | Bright preset (Voltage) — play + loss legible | ☐ | `themes/bright-voltage-hard-play.png` + `themes/bright-voltage-hard-loss.png` |
| SC4-D | Soft preset — play + loss legible | ☐ | `themes/soft-medium-play.png` + `themes/soft-medium-loss.png` |
| SC4-E | Moody preset (Dracula) — play + loss legible | ☐ | `themes/moody-dracula-hard-play.png` + `themes/moody-dracula-hard-loss.png` |
| SC4-F | Loud preset (Maroon) — play + loss legible | ☐ | `themes/loud-maroon-hard-play.png` + `themes/loud-maroon-hard-loss.png` |
| SC4-G | Warm-accent Forest — flag color distinct from mine indicator (loss state) | ☐ | `warm-accent/forest-loss.png` + manual eye check |
| SC4-H | Warm-accent Ember — flag color distinct from mine indicator (loss state) | ☐ | `warm-accent/ember-loss.png` + manual eye check |
| SC4-I | Warm-accent Voltage — flag color distinct from mine indicator (loss state) | ☐ | `warm-accent/voltage-loss.png` + manual eye check |
| SC4-J | Warm-accent Maroon — flag color distinct from mine indicator (loss state) | ☐ | `warm-accent/maroon-loss.png` + manual eye check |
| SC4-K | Final audit run on real hardware (TestFlight build) — not just simulator | ☐ | Real-device screenshot for one Loud preset Hard board |

**Verifier:** _______________  **Date:** ___________  **Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED

---

## SC5 — Release checklist documented + TestFlight build uploaded + Internal Testers invited

**Verbatim from ROADMAP (do NOT paraphrase):**

> Release checklist documented in `.planning/Docs/` (or equivalent) covering every step: capabilities verified, entitlements diffed, schema promoted, container ID stable, label completed, SIWA tested in production. TestFlight build is uploaded, internal testers invited.

| # | Sign-off row | Status | Evidence |
|---|--------------|--------|----------|
| SC5-A | Release checklist documented at `.planning/phases/07-release/07-CHECKLIST.md` (this file — phase-local equivalent per Discretion #10) | ☐ | This file's existence |
| SC5-B | All Pre-flight rows PF-01..PF-09 ticked | ☐ | This file's Pre-flight section |
| SC5-C | All SC1-SC4 sign-off rows ticked | ☐ | SC1, SC2, SC3, SC4 sections above |
| SC5-D | `MARKETING_VERSION = 1.0` set via Xcode UI (NOT pbxproj hand-patch per CLAUDE.md §8.8 + Discretion #7) | ☐ | `grep -E "MARKETING_VERSION = 1\.0" gamekit.xcodeproj/project.pbxproj` |
| SC5-E | `CURRENT_PROJECT_VERSION = 1` set via Xcode UI (Discretion #7) | ☐ | `grep -E "CURRENT_PROJECT_VERSION = 1" gamekit.xcodeproj/project.pbxproj` |
| SC5-F | TestFlight Internal-only build uploaded (D-15 — no External Beta, no Public Link) | ☐ | TestFlight build number + upload timestamp: `_______________________` |
| SC5-G | Internal Tester(s) invited via App Store Connect → TestFlight → Internal Testing → Add Testers | ☐ | Tester emails: `_______________________` (NOT committed to repo) |
| SC5-H | Soak monitor — Xcode Organizer shows zero crash reports during 1d–1w soak (D-16 adaptive) | ☐ | Soak duration: `_____` days; Organizer crashes: `_____` |
| SC5-I | DECISION GATE — submit to App Review when SC1–SC5 clean + no Organizer crashes | ☐ | Decision date: `___________`; Submitted: ☐ yes / ☐ no |

**Verifier:** _______________  **Date:** ___________  **Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED

---

## Pitfall 11 cross-check (mitigation completeness)

Pitfall 11 lists the 4 most expensive submission-day failure modes. This table cross-references each to the SC sign-off rows that mitigate it:

| Pitfall 11 failure mode | Mitigated by | Status |
|-------------------------|--------------|--------|
| Privacy nutrition label inconsistent with binary | SC2-A + SC2-B + SC2-C + SC2-D | ☐ |
| Sign in with Apple capability missing in entitlements | SC1-G | ☐ |
| CloudKit container not provisioned for Production | SC1-B + SC3-C..F | ☑ (SC1-B 2026-05-01; SC3-C..F still pending TestFlight build) |
| Bundle ID friction (`com.lauterstar.gamekit` vs `com.lauterstar.GameKit`) | SC1-E + P1 pre-commit hook | ☐ |

---

## Sign-off

Phase 7 ships when ALL rows above are ticked or explicitly DEFERRED-WITH-REASON.

| Criterion | Verifier | Date | Status |
|-----------|----------|------|--------|
| SC1 — Icon + schema + container ID | _____ | _____ | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC2 — Privacy nutrition label | _____ | _____ | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC3 — SIWA + 2-device sync in Production | _____ | _____ | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC4 — Theme-matrix + warm-accent legibility | _____ | _____ | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC5 — Checklist + TestFlight + Internal Testers | _____ | _____ | ☐ PASS / ☐ FAIL / ☐ DEFERRED |

---

## Phase-Close Updates (after sign-off)

After ALL SCs PASS or DEFERRED-WITH-REASON-DOCUMENTED:

- [ ] Update `.planning/ROADMAP.md` — Phase 7 row: status `In progress` → `Complete`; date filled
- [ ] Update `.planning/STATE.md` — `current_position` advances to "v1.0 shipped"; `progress.completed_phases` increments to 7
- [ ] Atomic commit `docs(07-06): SC1-SC5 verification checkpoint signed off — Phase 7 complete` per CLAUDE.md §8.10
- [ ] App Review submission decision recorded (submitted / deferred / blocked)

---

## Operating Notes (per CONTEXT decisions)

These notes capture decisions that constrain how rows above are filled. Read once before running the sweep — they prevent re-deriving disposition mid-submission.

- **D-04 / SC1-B:** Schema promote uses CloudKit Dashboard "Deploy to Production" button — NOT `initializeCloudKitSchema()` against Production. Apple-blessed path; reversible per record-type until first Production write.
- **D-05 / PF-03 / PF-04:** Production schema deploy timing = BEFORE first TestFlight upload. Sequence locked: real icon → schema promote → archive → TestFlight upload → Internal Tester invite → SC3 sweep.
- **D-08 / PF-05 / SC2-E:** Privacy URL hosted on GitHub Pages of the GameKit repo as a stopgap. Future state: a separate `GameKitWebsite` repo will own the public site; App Store metadata privacy URL update at that point is a one-line edit, no resubmit needed.
- **D-12 / PF-09 / SC2-B:** Privacy reasoning is recorded VERBATIM (not paraphrased) — the exact string in PF-09 must match what is pasted into App Store Connect's reasoning field.
- **D-15 / SC3 / SC5-F / SC5-G:** Internal-only TestFlight (no External Beta, no Public Link). Internal testers auto-approved by App Store Connect — no Beta App Review wait.
- **D-16 / SC5-H:** Soak duration is adaptive 1 day to 1 week, depending on test results. Submit when SC1–SC5 sweep is clean and Xcode Organizer shows zero crash reports.
- **D-17 (PUNT):** P5 G-1 CAF audio (`tap.caf` / `win.caf` / `loss.caf`) is NOT in scope for v1.0 — punted to v1.0.1 polish point release. Silent fallback is acceptable v1 ship state per P5 D-12 contract.
- **Discretion #6 (LOCKED out of v1.0):** MetricKit explicitly NOT integrated. The privacy reasoning depends on this being absent.
- **CLAUDE.md §8.8 / SC5-D / SC5-E:** `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` set via Xcode UI — never hand-patch `project.pbxproj`.

---

## Notes / Open Issues

*(Empty until Plan 07-06 sweep records anything.)*
