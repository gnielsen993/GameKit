# Phase 17: Snake - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-03
**Phase:** 17-snake
**Areas discussed:** Visual identity, Controls layout, Eat & death moments, Wall-mode toggle placement (all delegated)

---

## Session note

The user initially invoked discuss-phase for Phase 14 (Home Screen Overhaul);
inspection showed that phase's plan was already fully implemented and shipped
(commit `d3019ab`). On clarification the user meant **Snake → Phase 17** and
re-ran against it.

Four gray areas were presented (Snake's visual identity, controls layout,
eat & death feedback moments, wall-mode toggle placement). The user responded:

> "I actually dont want to discuss any of this, I think you as the model may
> have the best opinions to go off of"

All four areas were therefore resolved at Claude's discretion, grounded in the
Stack precedent (16-CONTEXT.md D-05..D-11), DESIGN.md §2/§3.0/§8/§10, and the
same-session app-wide smoothness/style passes.

---

## Visual identity

| Option | Description | Selected |
|--------|-------------|----------|
| Continuous rounded body + palette ramp | Google-Snake-style joined path, Stack-sibling accent gradient along the length, eye dots on head, clean field (no grid lines), smooth glide with RM jump-cut | ✓ (Claude) |
| Blocky per-cell segments | Classic retro cells; rejected — clashes with the app's soft-rounded modern language and the Classic "restomod" policy (modern execution) | |

## Controls layout

| Option | Description | Selected |
|--------|-------------|----------|
| Swipe-on-board + bottom-center D-pad cross | D-pad in the §5.1 mode-pill/numpad slot, component-dictionary styling, always visible | ✓ (Claude) |
| Corner-anchored floating D-pad over board | Rejected — occludes the board and drifts from the shared layout skeleton | |

## Eat & death moments

| Option | Description | Selected |
|--------|-------------|----------|
| Mirror Stack's language | Eat = light impact + head pulse + numeric-roll score; once-per-run high-score medium tick; death = danger flash → desaturate → banner after 500ms pre-roll, `.error` haptic, no shake | ✓ (Claude) |
| Bespoke Snake celebration set | Rejected — DESIGN.md §8.1 requires one shared haptic vocabulary across games | |

## Wall-mode toggle placement

| Option | Description | Selected |
|--------|-------------|----------|
| In-game toolbar menu + abandon alert | Keeps the Home tile modeless per ARCADE-09; mirrors Five Letter's strict-mode toggle + Merge's requestModeChange pattern; persists `snake.wallMode` | ✓ (Claude) |
| Home detail panel mode chips | Rejected — reverses the ARCADE-09 modeless-tile decision | |

## Claude's Discretion

All four areas (user delegated explicitly). Tuning constants (grid size,
speed-ramp curve, ramp cycle length, Canvas-vs-LazyVGrid) left to planner/
research per roadmap flags.

## Deferred Ideas

- Full stats screen shape, DESIGN.md §12 entries, ADR finalization — Phase 18
- Daily seed / trend charts / SFX — out of v1.5 scope
