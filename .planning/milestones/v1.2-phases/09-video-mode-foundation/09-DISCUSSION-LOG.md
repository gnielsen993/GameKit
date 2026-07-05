# Phase 9: Video Mode Foundation - Discussion Log

**Discussion date:** 2026-05-12
**Discussion mode:** discuss (interactive)
**Note:** Human audit trail of the Q&A. NOT consumed by downstream agents
(researcher, planner, executor) — those read `09-CONTEXT.md`.

---

## Area selection

**Q:** Which gray areas to discuss for Phase 9?

**Options presented (multiSelect):**
1. Settings entry shape (Recommended)
2. 6-option picker UX
3. Defaults when toggled On
4. Stub call site for compact row

**Gabe selected:** All 4 areas.

---

## Area 1: Settings entry shape

**Q:** How does Video Mode appear in Settings?

**Options presented:**
1. Toggle inline + NavigationLink to picker (Recommended) — main Settings shows Off/On toggle + 'Video location: <current>' NavigationLink to sub-screen
2. Toggle + picker both inline on main Settings — 6 picker rows expand under VIDEO MODE card
3. Everything nested under one NavigationLink — main shows 'Video Mode: Off' row; sub-screen has toggle + picker

**Gabe's initial selection:** Option 2 (toggle + picker inline).
**Gabe revised verbatim:** "Actually, I think it might be good to go into a nav view which has a iphone outline if like 'Your video will go here'"

**Final decision:** Compromise — toggle stays inline on main Settings (option 1's strength: compact off-state), picker moves to NavigationLink sub-screen rendered as iPhone-outline visual diagram (Gabe's revision). This locks BOTH Area 1 AND Area 2 in one move.

**Recorded as:**
- D-01 (entry shape): Toggle inline on main Settings + NavigationLink to picker sub-screen when On
- D-02 (picker UX): iPhone outline w/ 6 tappable zones, selected zone shows "Your video will go here"

---

## Area 2: 6-option picker UX

**Resolved by Area 1 revision** — visual iPhone-outline picker, not a radio list.
See D-02 above.

---

## Area 3: Default when first toggled On

**Q:** When Video Mode is first toggled On, which location is preselected?

**Options presented:**
1. Small BR (least intrusive, Recommended) — corner PiP, minimum impact on board / controls
2. Large bottom (most common iOS PiP) — mirrors iOS native PiP dock convention
3. Force user to pick (no default) — opens picker sub-screen w/ nothing preselected

**Gabe selected:** Option 2 (Large bottom).

**Recorded as:** D-03 — default location = `largeBottom`. Rationale: matches iOS native PiP dock + exercises the Hard-Mines smaller-cells worst-case path on first toggle rather than hiding behind a corner PiP.

---

## Area 4: Stub call site for VideoCompactControlRow

**Q:** Where does VideoCompactControlRow get its first compiling consumer (SC4)?

**Options presented:**
1. SwiftUI #Preview only (Recommended) — `#Preview { VideoCompactControlRow(...) }` showing all 3 game slot mappings
2. Debug-only ComponentGallery screen — hidden gallery screen gated by DEBUG
3. Wire into HomeView as dev preview — HomeView gets a 'Video Mode preview' card gated by DEBUG

**Gabe selected:** Option 1 (#Preview only).

**Recorded as:** D-04 — stub = single `#Preview` block at bottom of `VideoCompactControlRow.swift` showing Mines / Merge / Nonogram slot mappings. No DEBUG-only screen, no HomeView dev preview.

---

## Summary

4 user-driven decisions captured (D-01..D-04). 11 additional decisions
(D-05..D-15) are inherited from prior phases or follow directly from the
4 user picks — these are pre-locked context, not new user choices, and live
in `09-CONTEXT.md` for downstream agents.

Discussion total: 5 AskUserQuestion turns (1 area selection + 4 area
questions, with Area 1 + Area 2 collapsed by Gabe's revision).

No scope creep flagged. No deferred ideas added during discussion
(deferred items in CONTEXT.md are inherited from PROJECT.md v1.2 Out of
Scope list).
