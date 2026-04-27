# Release Checklist (Summary)

**Canonical artifact:** [`.planning/phases/07-release/07-CHECKLIST.md`](../.planning/phases/07-release/07-CHECKLIST.md)

**Manual SC1-SC5 verification:** [`.planning/phases/07-release/07-VERIFICATION.md`](../.planning/phases/07-release/07-VERIFICATION.md)

---

This file is a one-page summary pointing at the canonical phase-local
release checklist. Phase-local lives at the path above (per
Discretion #3 + SC5 "or equivalent" — phase-local survives milestone
archive better than a top-level `Docs/` artifact).

## What the canonical checklist covers

- **SC1** — Real app icon, CloudKit Production schema deploy, container ID + bundle ID stability, capabilities verified, entitlements diffed
- **SC2** — Privacy nutrition label "Data Not Collected" with verbatim D-12 reasoning matching the binary
- **SC3** — Sign in with Apple verified in Production via TestFlight, 2-device CloudKit sync sweep
- **SC4** — Theme-matrix legibility audit (6 DesignKit categories × play+loss) + warm-accent flag-vs-mine (Forest / Ember / Voltage / Maroon)
- **SC5** — TestFlight Internal-only build uploaded, Internal Tester(s) invited, App Review submission decision

## How to use during a release

1. Open the canonical checklist linked above.
2. Tick rows top-to-bottom: Pre-flight → SC1 → SC2 → SC3 → SC4 → SC5.
3. Run the corresponding test instructions in `07-VERIFICATION.md` for each SC.
4. Capture evidence (screenshots, grep transcripts, photos) into `.planning/phases/07-release/screenshots/`.
5. Sign off in the per-SC sign-off table at the bottom of `07-VERIFICATION.md`.
6. When all 5 SCs PASS or DEFERRED-WITH-REASON-DOCUMENTED → submit to App Review.

## Related docs

- [`../CLAUDE.md`](../CLAUDE.md) — project constitution, §1 stack/data-safety constraints, §8.7 Finder-dupe hygiene, §8.8 do-not-hand-patch-pbxproj, §8.10 atomic commits, §8.12 theme matrix legibility
- [`./derived-data-hygiene.md`](./derived-data-hygiene.md) — sibling lightweight Docs entry; recurring-clean ritual
- [`../.planning/research/PITFALLS.md`](../.planning/research/PITFALLS.md) — Pitfall 11 (App Store / TestFlight gotchas) drives several SC1/SC2 sign-off rows
- [`../.planning/PROJECT.md`](../.planning/PROJECT.md) — non-negotiables: no ads, no analytics, no required accounts
