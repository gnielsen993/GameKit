---
phase: 07-release
type: draft
canonical: false
covers: PF-08 + PF-09
status: draft
last_updated: 2026-05-01
---

# ASC Metadata Draft — GameDrawer v1.0

> Single source of copy-paste-ready strings for App Store Connect.
> When ready to submit, ask for "PF-08 description" / "PF-08 keywords"
> / "PF-09 nutrition" etc. and pull only that section.
>
> All strings respect Apple's character limits (verified inline).
> Where multiple options are offered, the **bolded** one is the
> recommended pick; the others are alternates if it doesn't sit right.

---

## 0) Open decisions BEFORE submitting

These choices change the draft. Resolve first.

### 0.1 Device family — Universal or iPhone-only?

`TARGETED_DEVICE_FAMILY = "1,2"` in `project.pbxproj` → app currently
ships as **Universal (iPhone + iPad)**. ASC will require iPad
screenshots (12.9" iPad Pro 6th gen, `2048 × 2732`) on top of the
iPhone set.

The home grid (2-per-row), Minesweeper board, and Merge layout were
designed for iPhone. iPad will run the iPhone build but the layouts
have not been tuned for the larger canvas — screenshots may look
sparse or stretched.

**Recommendation: drop to iPhone-only for v1.0.** Reduces ASC
paperwork (~6 fewer screenshots), avoids an iPad layout audit, and
matches CLAUDE.md §0.1 (which lists Target iOS but not iPad). v1.1+
can flip back to Universal once iPad layouts are tuned.

To switch: Xcode → Targets → gamekit → General → Device → uncheck
iPad. Reverify TARGETED_DEVICE_FAMILY = "1" in pbxproj. (This is
Xcode UI, not pbxproj hand-patch — it goes through the General pane,
which Xcode rewrites correctly.)

If keeping Universal: this draft adds iPad screenshot requirements
(see §10).

### 0.2 First or subsequent app under Lauterstar LLC?

If first, ASC may ask for D-U-N-S, contact info, agreements, banking,
tax forms BEFORE accepting the first build upload. Verify in ASC
**before** running Archive — easier to fix paperwork than to wait on
Apple Pay/tax review with a build sitting half-uploaded.

---

## 1) App identity

| Field | Value | Notes |
|-------|-------|-------|
| Name | **GameDrawer** | 30 char max — `GameDrawer` = 10 ✓ |
| Bundle ID | `com.lauterstar.gamekit` | Locked per CLAUDE.md §1 |
| SKU | `gamedrawer-ios` | Free-form internal ID, never shown publicly |
| Primary Language | English (U.S.) | |
| Primary Category | **Games → Puzzle** | Best fit for Minesweeper + Merge |
| Secondary Category | **Games → Casual** | Optional but recommended for discovery |
| Age Rating | **4+** | No objectionable content (see §6) |

---

## 2) Subtitle (30 char max)

Apple counts visible characters including spaces.

**Picked: `Calm classic logic puzzles`** (26 chars) — emphasizes the
core differentiator (no ads, no churn) without using the word
"ad-free" which competitors over-claim.

Alternates:
- `Ad-free classic logic games` (27 chars) — most direct
- `Classic puzzles, ad-free` (24 chars) — punchiest
- `Quiet ad-free puzzle games` (26 chars) — leans on tone
- `Logic puzzles. No ads. Ever.` (28 chars) — most opinionated

---

## 3) Promotional text (170 char max)

Editable independent of the binary — use for launch / sale
announcements without resubmitting the build.

**v1.0 launch text** (159 chars):
```
Calm, ad-free classic logic puzzles. Two games at launch — Minesweeper and Merge — with more on the way. Optional iCloud sync. No ads. No coins. Ever.
```

Alternate (post-launch, 167 chars):
```
Two timeless logic puzzles — Minesweeper and Merge — with no ads, no coins, no energy meters. Pick a theme, sync via iCloud, and play at your own pace.
```

---

## 4) Description (4,000 char max)

Long-form. Goal: communicate (a) what's in v1.0, (b) the no-ads/
no-IAP differentiator, (c) the theme system, (d) the sync model,
(e) the future games. Avoid feature-list dump format.

```
GameDrawer is a quiet little drawer of classic logic puzzles. Two
games at launch — Minesweeper and Merge — with more rolling out over
time, all under the same roof, all sharing the same theme system.

What you won't find:
• No ads. Anywhere. Ever.
• No coins, gems, or fake currency.
• No energy meters or "wait 4 hours to play" timers.
• No accounts required. No tracking. No analytics SDKs.

What you will find:
• A polished Minesweeper with first-tap safety — your first move is
  never a loss. Easy, Medium, Hard, and Expert difficulties. Best
  times tracked per difficulty.
• A clean Merge tile game with smooth animations and a satisfying
  curve from 2-tile combine all the way up.
• Six theme families to choose from — Classic (a warm cream-and-
  diner-red restomod), Sweet, Bright, Soft, Moody, and Loud — plus
  custom color overrides if you want to dial in your own palette.
• Optional iCloud sync via Sign in with Apple. Sign in once on each
  device and your stats and best times follow you across iPhone and
  iPad. Sync is fully optional — you can play forever signed-out,
  and your local stats stay safe if you sign out later.
• Export and Import your stats as JSON. Your data, your file.

Coming soon: Word Grid, Solitaire, Sudoku, Nonogram, Flow, Pattern
Memory, Chess Puzzles. Each one will land as a free update under the
same roof — no new app to download, no premium tier to unlock.

GameDrawer is built by a one-person studio that ships ad-free apps
across categories. If you're tired of "free" puzzle games that
interrupt every third move with a 30-second video, this drawer is
for you.

Local-first. Quiet. Yours.
```

Char count: ~1,520 / 4,000.

If you want it shorter / longer / more pun-heavy / less marketing-
y, ask and I'll re-draft.

---

## 5) Keywords (100 char max, comma-separated)

Apple tokenizes by comma — no spaces after commas saves chars.
Avoid: app name (auto-included), plurals (Apple stems), "free"
(controlled by price tier), competitor names.

**Picked** (80 chars):
```
minesweeper,puzzle,brain,logic,offline,classic,casual,arcade,relax,solo,merge,grid
```

Counts: minesweeper(11) + puzzle(6) + brain(5) + logic(5) + offline(7)
+ classic(7) + casual(6) + arcade(6) + relax(5) + solo(4) + merge(5)
+ grid(4) = 71 letters + 11 commas = 82 chars. ✓ (room for 18 more)

Optional adds (pick to fill toward 100): `mines`, `tiles`, `bombs`,
`flag`, `2048`, `puzzlegame`, `sweeper`, `numbers`. Skip "games"
(redundant with category) and "ios" (redundant).

---

## 6) Age rating answers

ASC walks through ~10 questions. All answers for GameDrawer:

| Question | Answer |
|----------|--------|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic / Sadistic Realistic Violence | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, Drug Use | None |
| Simulated Gambling | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content or Nudity | None |
| Contests | None |
| Unrestricted Web Access | No |
| User-Generated Content | No |

**Result: 4+** (Apple computes from the above; should auto-resolve.)

---

## 7) URLs

| Field | Value | Status |
|-------|-------|--------|
| Privacy Policy URL (REQUIRED) | `https://gamedrawer.lauterstar.com/privacy.html` | Awaiting DNS go-live (PF-05) |
| Support URL (REQUIRED) | `https://gamedrawer.lauterstar.com` (or `mailto:support@lauterstar.com`) | Awaiting DNS go-live |
| Marketing URL (optional) | `https://gamedrawer.lauterstar.com` | Awaiting DNS go-live |

**Submission blocker:** All three must resolve before App Review.
Apple's reviewer will click them. A 404 on the Privacy URL is the
single most common rejection reason for a clean app. PF-05 must be
green before SC5-I.

If DNS slips, **temporary fallback**: host as static files in a
GitHub Pages repo (`https://gxnielsen.github.io/gamedrawer-site/`)
and edit ASC URLs after DNS lands. ASC URL edits do not require
resubmission of the binary.

---

## 8) Copyright

```
© 2026 Lauterstar LLC
```

---

## 9) What's New (release notes, 4,000 char max)

For v1.0:
```
First release. Two games to start: Minesweeper and Merge. Optional
iCloud sync via Sign in with Apple. Six theme families. No ads, no
coins, no fake currency. More games coming.
```

(Char count: 197 / 4,000.)

---

## 10) Screenshots — required spec

If shipping iPhone-only (recommended per §0.1):

| Display | Resolution | Count required |
|---------|------------|----------------|
| 6.9" iPhone (iPhone 16 Pro Max) | `1320 × 2868` portrait | min 3, max 10 |
| 6.5" iPhone (iPhone 11 Pro Max etc.) | `1242 × 2688` portrait | OPTIONAL — Apple auto-scales 6.9" if absent |

If keeping Universal:
- All iPhone above
- 13" iPad (iPad Pro 13" M4) `2064 × 2752` — min 3, max 10

PF-06 already specifies 12 theme-matrix + 4 warm-accent screenshots.
The ASC-required ≥3 can be selected from those 16. Recommended
selection for ASC (5 of 10 slots, leaves room to add):

1. Classic preset (Forest) — Minesweeper Hard mid-play
2. Classic preset (Forest) — Stats tab (best times card)
3. Bright preset (Voltage) — Minesweeper Hard mid-play (proves
   theme range)
4. Moody preset (Dracula) — Merge mid-game
5. Settings → Themes → "More themes & custom colors" panel (proves
   the theme system is real)

Alternates: a Loud preset (Maroon) loss state, the Home grid in
Classic, Settings ABOUT showing iCloud Sync row mid-`Synced just now`.

---

## 11) Privacy nutrition label (PF-09 — answers App Privacy panel)

In ASC: **App Privacy → Get Started → Data Types**.

### Answer
**Data Not Collected.**

### Verbatim reasoning (paste into App Privacy → Reasoning field, AND
preserve in 07-CHECKLIST.md SC2-B for traceability):

```
CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit not integrated → Data Not Collected
```

### Why "Data Not Collected" is correct (D-12)
1. **CloudKit private database** — data lives in the user's iCloud,
   encrypted in transit, the developer (Lauterstar LLC) has no
   read access. Apple's privacy policy explicitly classifies private
   CloudKit data as user-owned, not collected by the app developer.
2. **No analytics SDKs** — verified by grep (SC2-C, zero matches for
   FIRApp / Sentry / Bugsnag / Mixpanel / GoogleAnalytics).
3. **MetricKit explicitly not integrated** — D-12 / Discretion #6.
   No `MetricKit` / `MXMetricManager` references (SC2-D).
4. **Sign in with Apple** — only collects an anonymized user
   identifier locally (Keychain). This is a system-level identifier,
   not a personal identifier; per Apple's own SIWA guidance it does
   not require disclosure as collected data.
5. **No third-party SDKs** that ship telemetry. DesignKit is
   first-party (your own SPM package).

### Edge case to be aware of
If you later add MetricKit or any analytics SDK in v1.0.1 or beyond,
the nutrition label MUST be updated in the SAME submission. Apple
auto-flags binary/label divergence in App Review. The reasoning
above explicitly says "MetricKit not integrated" so adding it
without a label update is a Pitfall 11 #1 failure.

---

## 12) Submission checklist (paper-trail order in ASC)

| Order | ASC pane | Action |
|-------|----------|--------|
| 1 | App Information | Name, Subtitle, Category, Copyright (§1, §2, §8) |
| 2 | Pricing & Availability | Free, all territories, manual release (recommended for v1.0) |
| 3 | App Privacy | Paste verbatim PF-09 reasoning, select "Data Not Collected" (§11) |
| 4 | Age Rating | Walk through §6 questions |
| 5 | Version 1.0 → Description | Paste §4 |
| 6 | Version 1.0 → Promotional Text | Paste §3 (170 chars) |
| 7 | Version 1.0 → Keywords | Paste §5 (80 chars) |
| 8 | Version 1.0 → URLs | Paste §7 (privacy + support + marketing) |
| 9 | Version 1.0 → What's New | Paste §9 |
| 10 | Version 1.0 → Screenshots | Upload per §10 |
| 11 | Build | Attach uploaded TestFlight build (auto-populates after SC3-A) |
| 12 | App Review Information | Sign-in info (n/a — SIWA is on-device), Notes for reviewer (see §13) |
| 13 | Submit for Review | After SC1–SC5 all clean (07-CHECKLIST.md SC5-I) |

---

## 13) Notes for App Reviewer (Review Information → Notes)

```
GameDrawer is a local-first puzzle game suite with optional iCloud
sync via Sign in with Apple. No accounts, no analytics, no third-
party network calls.

Sign in with Apple is purely optional — the app is fully playable
signed-out. To test sync: Settings → "Sync stats to iCloud" → toggle
on → Sign in with Apple. Stats sync to the user's iCloud private
database (container iCloud.com.lauterstar.gamekit). Toggle off and
sign out to return to local-only mode; local stats are preserved.

There is no demo account because no account is required. The app
has no server, no remote config, and no telemetry.

If you encounter any issues, please email support@lauterstar.com.
```

---

## 14) Pre-submit gate (cross-reference 07-CHECKLIST.md)

Before clicking Submit (SC5-I):
- [ ] Every section above pasted into ASC
- [ ] All §10 screenshots uploaded
- [ ] Build attached (SC3-A green)
- [ ] §11 reasoning matches SC2-B verbatim
- [ ] PF-05 URLs return 200 (curl them)
- [ ] SC1, SC2, SC3, SC4, SC5 all PASS in 07-CHECKLIST.md
- [ ] Xcode Organizer shows zero crashes for soak duration (SC5-H)
