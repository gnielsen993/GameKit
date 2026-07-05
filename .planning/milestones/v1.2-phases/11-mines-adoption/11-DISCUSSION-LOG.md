# Phase 11: Minesweeper Adoption - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-13
**Phase:** 11-mines-adoption
**Areas discussed:** Layout switch + HeaderBar fate, Slot wiring (Restart, Settings, NavBar title), Hard cell-size floor, Manual recipe doc shape + location

---

## Layout switch + HeaderBar fate

| Option | Description | Selected |
|--------|-------------|----------|
| Large=compact row, Small=reposition | Large zones hide HeaderBar + ModePill + nav-toolbar; render VideoCompactControlRow on opposite edge. Small zones keep existing layout; only reposition individual nav-toolbar items per SlotRouter. | ✓ |
| Always compact row when isEnabled | Every PiP zone replaces existing layout with compact row. | |
| Keep all existing UI, only reflow via slot anchors | No layout switch; SlotRouter only nudges item positions. | |

**User's choice:** Large=compact row, Small=reposition (Recommended)
**Notes:** Matches plan-doc Mines Easy/Medium/Hard slot tables + P10 VERIFICATION SC1 split.

| Option | Description | Selected |
|--------|-------------|----------|
| Extract shared chip subviews | Pull `MinesRemainingChip` + `TimerChip` into sibling files. HeaderBar + compact row share them. | ✓ |
| Inline-render chips in compact row | Compact row builds its own chips inline. | |
| Hide HeaderBar but reuse it as data source | HeaderBar in tree but hidden. | |

**User's choice:** Extract shared chip subviews (Recommended)
**Notes:** Single source of truth for chip rendering + theming.

---

## Slot wiring (Restart, Settings, NavBar title)

| Option | Description | Selected |
|--------|-------------|----------|
| Fold Restart into Settings overflow ⋯ | Single slot, Restart + Difficulty + App Settings inside. | |
| Keep nav-toolbar Restart visible, hide other nav items | Restart in nav-bar, other 4 slots in compact row. | |
| End-state card only (no in-flight restart) | Drop Restart from in-flight UI. | |
| Restart in the compact row (user freeform) | Dedicated slot inside compact row — most-tapped action. | ✓ |

**User's choice:** "In the compact row it deserves a spot because it is a button often used"
**Notes:** Required reconciling with the 5-slot VideoCompactControlRow contract.

| Option | Description | Selected |
|--------|-------------|----------|
| Overflow menu: Restart + Difficulty + App Settings | Combined menu in Settings slot. | |
| Only Change difficulty (current ToolbarMenu shape) | Settings slot = current MinesweeperToolbarMenu (difficulty radio). | ✓ |
| Push to global SettingsView | Settings slot navigates to app-wide Settings. | |

**User's choice:** Only Change difficulty (current MinesweeperToolbarMenu shape)
**Notes:** Keeps slot scoped to in-flight game control.

| Option | Description | Selected |
|--------|-------------|----------|
| Hide nav-bar entirely when isEnabled | `.toolbar(.hidden)` whenever Video Mode On. | |
| Keep title visible, hide only nav-bar items | Title bar stays; items hidden via `.toolbarVisibility(.hidden)`. | ✓ |
| Hide on Large zones only, keep on Small zones | Split per location. | |

**User's choice:** Keep title visible, hide only nav-bar items
**Notes:** Reconciled with Area 1 split — items hidden on Large zones; on Small zones items stay but reposition per SlotRouter (D-09).

### Slot order reconciliation (5-slot contract preserved)

| Option | Description | Selected |
|--------|-------------|----------|
| Extend component to 6 slots, Restart between Time and Settings | VideoCompactControlRow grows to 6 slots; v1.2 contract change. | |
| Replace 'Time' slot with Restart when in-flight | Compact row stays 5-slot; Time chip becomes Restart icon mid-game. | |
| Mines-local Restart adjacent to row | Restart pill outside component. | |
| Restart replaces 'Settings' slot | Settings moves to Back-area overflow. | |
| Combine Flags + Time chips into one stacked slot (user freeform) | Slot 2 becomes vertical stack of two chips; frees a slot for Restart. | ✓ |

**User's choice:** "Since flags and time are small what if we combine them, stack them, so same piece"
**Notes:** Clever compromise — 5-slot contract preserved; slot 2 just renders a stacked sub-view in Mines. Merge + Nonogram unaffected.

| Option | Description | Selected |
|--------|-------------|----------|
| Mines on top, Time below | Matches HeaderBar reading order. | ✓ |
| Time on top, Mines below | Timer top (dynamic chip emphasis). | |
| Inline horizontal mini-chip | Horizontal pill, no stack. | |

**User's choice:** Mines on top, Time below (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| `Back \| Flags⊥Time \| Picker \| Restart \| Settings` | Restart 4th, Settings 5th. | |
| Swap Restart and Picker | `Back \| chip \| Restart \| Picker \| Settings`. | |
| Restart leftmost, Back second | `Restart \| Back \| chip \| Picker \| Settings`. | |
| Swap Settings and Restart, Restart rightmost (user freeform) | `Back \| Flags⊥Time \| Picker \| Settings \| Restart`. | ✓ |

**User's choice:** "swap settings and restart, restart right most"
**Notes:** Locked slot order for Mines: `Back | [Mines⊥Time] | Reveal/Flag picker | Settings | Restart`.

---

## Hard cell-size floor

| Option | Description | Selected |
|--------|-------------|----------|
| Defer exact value to plan task | Plan-time Dracula + Voltage audit at 10/11/12/13pt candidates. | ✓ |
| Lock 12pt now | Take ADR working number; skip audit. | |
| Lock 14pt | Conservative shrink; less fat-finger risk. | |

**User's choice:** Defer exact value to plan task (Recommended)
**Notes:** Working number per ADR ≈12pt; locked after SC4 §8.12 audit.

| Option | Description | Selected |
|--------|-------------|----------|
| Just `store.isEnabled` per ADR | Universal gate; auto-scale naturally leaves Easy/Medium alone. | ✓ |
| Gate on `store.isEnabled && location.isLarge` | Floor only when Large band active. | |
| Gate on `store.isEnabled && difficulty == .hard` | Floor only on Hard. | |

**User's choice:** Just `store.isEnabled` per ADR (Recommended)
**Notes:** Matches ADR §How-it-composes verbatim. One gate, smallest test surface.

---

## Manual recipe doc shape + location

| Option | Description | Selected |
|--------|-------------|----------|
| Phase dir `11-VIDEO-MANUAL-CHECK.md` | Co-located with phase artifacts. | ✓ |
| `Docs/v1.2-video-mode-manual-check.md` | Lives in `Docs/` as user-facing QA. | |
| Both — mirror to `Docs/` after phase ships | Drift risk. | |

**User's choice:** Phase dir `11-VIDEO-MANUAL-CHECK.md` (Recommended)
**Notes:** Mirrors `07-CHECKLIST.md` pattern.

| Option | Description | Selected |
|--------|-------------|----------|
| Single matrix doc, 18 rows | 3 difficulties × 6 zones in one table. | ✓ |
| Per-difficulty sub-docs | Three files. | |
| Per-zone sub-docs (6 files) | Easier per-session execution; 6 files. | |

**User's choice:** Single matrix doc, 3 difficulties × 6 zones = 18 rows (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Living — SC1 authors, SC3 fills Hard rows | One doc serves SC1 quick-check + SC3 Hard validation. | ✓ |
| One-shot — SC1 only; SC3 evidence separate | Split evidence trail. | |

**User's choice:** Living — SC1 authors, SC3 fills Hard rows with screenshot refs (Recommended)

---

## Claude's Discretion

- Names of extracted chip subviews — `MinesRemainingChip` / `TimerChip` working.
- Name of the lowered-floor static helper — `minCellSizeVideoMode` working.
- Exact `theme.spacing.*` token for stacked-chip vertical gap.
- `.collapsedSettings` overflow mechanism on Restart (`contextMenu` vs `Menu` w/ primary action).
- Net-new localization keys — likely zero; plan-task confirms.

## Deferred Ideas

- End-state overlay redesign → Phase 13.
- Banner copy for Hard Video Mode → ADR chose smaller-cells, not warning+compromise.
- Merge + Nonogram compact-row Restart → P12-specific decision.
- Promote chip subviews to DesignKit → wait for 2+ consumers.
- Promote stacked-slot-2 pattern to component API → wait for second adopter.
- Auto-detection of another app's PiP → permanently deferred (no public iOS API).
- Vertical / portrait PiP + large-left/right zones → v1.3+.
