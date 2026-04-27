# Phase 7: Release - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-27
**Phase:** 07-release
**Areas discussed:** App icon production, CloudKit Prod schema deploy, App Store metadata + privacy URL, Theme-matrix audit method (SC4), TestFlight rollout structure, Pre-submission tech debt

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| App icon production | Real icon to replace P1 placeholder | ✓ |
| CloudKit Prod schema deploy | Method + timing + verification | ✓ |
| App Store metadata + privacy URL | Description, screenshots, URLs | ✓ |
| Theme-matrix audit method (SC4) | Manual / automated / eye-only | ✓ |

User selected all 4 of the 4 presented. TestFlight rollout + pre-submission tech debt added in a follow-up pass.

---

## App Icon Production

### Q1: Who produces the real icon?

| Option | Description | Selected |
|--------|-------------|----------|
| You hand-design (Figma/Sketch/Affinity) | Author the master, full control | |
| AI-generated (Midjourney/DALL-E/etc) | Prompt-driven, fast, may need cleanup | ✓ (Other) |
| Contracted designer | Hire on Fiverr/Dribbble | |
| DesignKit primitives composed in Swift/SVG | Build from theme tokens | |

**User's choice:** Free text — *"I want it AI-designed, my thinking is some sort of old school arcade machine"*
**Notes:** Locks the AI route + the arcade-cabinet subject. Specific AI service is planner discretion.

### Q2: Which icon variants ship in v1.0?

| Option | Description | Selected |
|--------|-------------|----------|
| All three (light + dark + tinted) | Most polished, 3× asset work | ✓ |
| Light + dark only | Skip tinted, system fallback | |
| Universal only (1, light) | Simplest, loses tailored dark feel | |

### Q3: Where does the master asset live?

| Option | Description | Selected |
|--------|-------------|----------|
| Vector source committed to repo (.svg / .pdf) | Re-exportable, diffable, future-proof | ✓ |
| Vector source kept locally, only PNGs in repo | Less repo bloat, no re-export workflow | |
| PNG-only (no master) | Locks the icon, acceptable for personal-first | |

### Q4: Light vs dark vs tinted — same subject re-toned, or vary?

| Option | Description | Selected |
|--------|-------------|----------|
| Same arcade-machine, retoned per appearance | Most coherent, easiest to maintain | ✓ |
| Same subject, palette pulled from Classic preset | Ties icon to default DesignKit | |
| Each variant slightly different (different framing/angle) | More work, harder to keep coherent | |

### Q5: Where does the SVG master live in the repo?

| Option | Description | Selected |
|--------|-------------|----------|
| assets/icon/ at repo root | Sibling to gamekit/, industry convention | ✓ |
| Docs/icon/ | Co-located with project docs | |
| .planning/release-assets/icon/ | Treated as planning artifact | |

---

## CloudKit Production Schema Deploy

### Q1: How to promote the CloudKit schema to Production?

| Option | Description | Selected |
|--------|-------------|----------|
| Dashboard 'Deploy to Production' button (Recommended) | Apple-blessed, one-click | ✓ |
| initializeCloudKitSchema() against Production env | Riskier, app code creates types | |
| Schema export from Dev + import to Prod | Most explicit, slowest | |

### Q2: When in P7 sequence does the Production deploy happen?

| Option | Description | Selected |
|--------|-------------|----------|
| Before the first TestFlight upload (Recommended) | Schema must exist before testers sign in | ✓ |
| After first TestFlight upload, before App Review | Risk: testers hit empty schema | |
| Both (deploy twice — dry-run + final) | Highest confidence, most ceremony | |

### Q3: How is Production deploy verified?

| Option | Description | Selected |
|--------|-------------|----------|
| Dashboard env toggle + visual record-type check + SC3 2-device sweep | Three rungs, captured in 07-VERIFICATION.md | ✓ |
| SC3 2-device sweep is the only verification | Less ceremony, no early warning | |
| Dashboard check + automated XCTest hitting CKContainer | Programmatic guard, ships test code | |

---

## App Store Metadata + Privacy URL

### Q1: Where does the privacy policy live?

| Option | Description | Selected |
|--------|-------------|----------|
| GitHub Pages on the GameKit repo | Free, version-controlled, public | ✓ (Other) |
| lauterstar.com subpath | Cleaner brand URL, requires domain | |
| Notion/Gist public page | Quick to ship, less owned | |

**User's choice:** Free text — *"It will eventually live in a GameKitWebsite repo, which will have users redirected from the app, but since not there yet, it can live in GameKit"*
**Notes:** Stopgap = GitHub Pages on GameKit repo. Future = GameKitWebsite repo. Privacy URL update at migration is a one-line metadata edit, no resubmit.

### Q2: Which metadata is authored in P7 vs deferred?

| Option | Description | Selected |
|--------|-------------|----------|
| All of it in P7 (Recommended) | Submission-ready, slowest plan | ✓ |
| Text fields in P7, screenshots deferred to a sub-plan | Realistic split | |
| Minimum viable metadata, expand on first reject | Submit faster, iterate | |

### Q3: Screenshot strategy?

| Option | Description | Selected |
|--------|-------------|----------|
| Real device captures, Classic Forest preset only | Single preset, simplest | |
| Real device, mix of presets to showcase theming | Sells differentiator, more work | |
| Simulator captures with theme-matrix mix | Faster than real-device coordination | ✓ |

### Q4: Marketing URL field?

| Option | Description | Selected |
|--------|-------------|----------|
| Same as privacy URL parent (e.g., GitHub Pages root) | One domain, two paths | |
| Leave blank | Apple allows blank | |
| Dedicated landing (lauterstar.com/gamekit) | Real one-pager, overkill | |

**User's choice:** Free text — *"it will be (name).lauterstar.com, gamekit is my repo name but will likely not be the public name"*
**Notes:** Locks `(name).lauterstar.com` pattern. Public app name TBD — captured as Discretion #1 for the planner.

---

## Theme-Matrix Audit Method (SC4)

### Q1: How is the SC4 theme-matrix audit evidenced?

| Option | Description | Selected |
|--------|-------------|----------|
| Manual screenshots saved as artifact (Recommended) | 12+ shots in screenshots/ dir, eye-only verification | ✓ |
| Automated XCTest snapshot grid | Programmatic regression catch, ships test code | |
| Eye-only checklist sweep, no artifact | Fastest, no audit trail | |

### Q2: Warm-accent flag-vs-mine check (SC4 explicit)?

| Option | Description | Selected |
|--------|-------------|----------|
| Manual shots on Forest+Ember+Voltage+Maroon, recorded in checklist | Surfaces SC4 explicit risk | ✓ |
| Automated XCTest with color-distance assertion | Programmatic guard, higher upfront cost | |
| Roll into the main audit — no separate evidence | Combines, loses focus | |

---

## TestFlight Rollout Structure

### Q1: TestFlight scope: internal-only or add External Beta?

| Option | Description | Selected |
|--------|-------------|----------|
| Internal-only (SC5 verbatim, Recommended) | Auto-approved, no Beta App Review wait | ✓ |
| Internal + External Beta (close-circle) | Beta App Review required | |
| Internal + External Public Link | Public, requires compliance | |

### Q2: Soak duration before App Review submission?

| Option | Description | Selected |
|--------|-------------|----------|
| 1–2 days, until SC1–SC5 sign-off | Just the manual sweep | |
| 1 week, monitor for crashes via Xcode Organizer | Real-world soak | |
| Crash-free-session threshold (e.g., 50+ sessions) | Quantitative gate, requires analytics | |

**User's choice:** Free text — *"between 1 day and 1 week, depending how tests go"*
**Notes:** Adaptive 1d–1w window. Submit when SC1–SC5 sweep is clean and Xcode Organizer is quiet.

---

## Pre-Submission Tech Debt

### Q1: P5 G-1: CAF audio (tap.caf/win.caf/loss.caf) — resolve in P7 or punt?

| Option | Description | Selected |
|--------|-------------|----------|
| Punt to v1.0.1 (Recommended) | Silent fallback acceptable per P5 D-12 | ✓ |
| Land CAFs in P7 as a sub-plan | Honors MINES-10 fully at v1.0 | |
| Remove the SFX feature for v1.0 | Strips toggle, regresses MINES-10 | |

### Q2: Milestone-audit doc drift — fix in P7?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — first plan in P7 cleans it (Recommended) | Refresh ROADMAP/REQUIREMENTS/STATE/06-VERIFICATION | ✓ |
| Roll into the release-checklist plan | Single-shot release-prep plan | |
| Skip — planning docs aren't shipped to App Store | Internal-only drift, leave it | |

---

## Final Confirmation

### Q: All 6 areas resolved. Ready for context?

| Option | Description | Selected |
|--------|-------------|----------|
| Ready for context (Recommended) | Public app name + checklist path + version captured as Claude's discretion | ✓ |
| One more pass on those two | Lock checklist path + version explicitly | |

---

## Claude's Discretion (captured in CONTEXT.md)

Areas where the user did not lock a value and the planner has flexibility:

1. Public app name (TBD; planner picks during metadata authoring)
2. Specific 5-preset blend for screenshots
3. Release checklist file location (recommend phase-local + optional Docs/ summary stub)
4. Vectorize AI raster vs ship raster as master
5. AI service for icon generation (Midjourney / DALL-E / etc.)
6. MetricKit integration in v1.0 (recommend NO)
7. Version + build numbering (recommend 1.0 / 1)
8. GitHub Pages enable mechanics
9. Plan ordering inside P7
10. Whether to create an empty `.planning/Docs/` directory

## Deferred Ideas (mentioned during discussion, captured in CONTEXT.md `<deferred>`)

- P5 G-1 CAF audio → v1.0.1
- External TestFlight Beta + Public Link → v1.x
- MetricKit integration → not v1.0
- GameKitWebsite repo → separate project
- Public app name lock → metadata plan
- Vectorize AI raster → planner discretion
- Automated XCTest snapshot grid → v1.x
- Crash-free-session quantitative gate → never (PROJECT.md no analytics)
- Submission-day rollback / contingency plan → handle inline if it happens
- `.planning/Docs/` directory creation → not creating an empty stub
- Per-game alt-icon variants → REQUIREMENTS v2
- App Shortcuts → REQUIREMENTS v2
- Crash reporting / analytics → permanent NEVER
