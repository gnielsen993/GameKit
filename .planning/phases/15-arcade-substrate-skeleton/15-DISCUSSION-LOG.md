# Phase 15: Arcade Substrate + Skeleton - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-26
**Phase:** 15-arcade-substrate-skeleton
**Areas discussed:** Placeholder screen, Tile copy & accent, Pause-safety proof, Video Mode ADR timing

---

## Placeholder screen

| Option | Description | Selected |
|--------|-------------|----------|
| Live substrate harness | Throwaway view driven by the real `.arcadeLoop` (oscillating dot / tick readout); proves substrate end-to-end and enables the manual pause test; deleted when real game lands | ✓ |
| Static themed card | DKCard with name + icon + "Coming soon"; tidy but leaves substrate unexercised this phase | |
| Bare "Coming soon" text | Minimal centered Text; lowest effort, nothing runs the loop | |

**User's choice:** Live substrate harness
**Notes:** Chosen so the substrate is exercised before any game depends on it and so criterion #3's manual notification-banner test has a running surface.

---

## Pause-safety proof

| Option | Description | Selected |
|--------|-------------|----------|
| Unit test + manual banner test | Locked unit tests (onTick gating + spiral clamp) AND on-device notification-banner test on the live harness | ✓ |
| Unit tests only | Automated clamp/gating tests only; defer manual banner check to Phase 16 | |

**User's choice:** Unit test + manual banner test
**Notes:** Satisfies success criterion #3 within Phase 15; only feasible because the placeholder is a live harness.

---

## Tile copy & accent

| Option | Description | Selected |
|--------|-------------|----------|
| Final copy + locked colors now | "Tap to play" caption + researched accents (Stack orange 0.961/0.498/0.122, Snake green 0.176/0.741/0.490) in slot9/slot10, legible-verified | ✓ |
| "Coming soon" caption now | Signal not-yet-playable during dev, swap later; touches descriptor twice | |
| Final copy, defer colors | "Tap to play" now, neutral accents, pick colors in Phase 18 | |

**User's choice:** Final copy + locked colors now
**Notes:** Descriptor written once; tiles only ever ship in final playable state, so no rework. §8.12 legibility pass on Classic + one Loud preset required.

---

## Video Mode ADR timing

| Option | Description | Selected |
|--------|-------------|----------|
| Write ADR now (Phase 15) | Rationale fully known; code decision lands in this phase's HomeView edit; prevents re-litigation in 16/17; Phase 18 just closes ARCADE-08 | ✓ |
| Keep ADR in Phase 18 | Follow current requirements mapping; artifact committed in final polish phase | |

**User's choice:** Write ADR now (Phase 15)
**Notes:** Pulls ARCADE-08's ADR artifact earlier than the ROADMAP/REQUIREMENTS mapping; planner should note the deliverable is satisfied in Phase 15.

---

## Claude's Discretion

- Fixed-timestep accumulator placement (driver vs VM vs engine)
- Whether the dt-clamp constant is parameterized
- Exact harness visual and precise SF Symbol per tile
- `SeedableRNG` placement (deferred — no RNG until gameplay)

## Deferred Ideas

- Stack/Snake gameplay, engines, save-state, Canvas-vs-LazyVGrid → Phases 16/17
- Score-based Stats screen shape / ARCADE-07 → Phase 18
- Snake wrap-vs-wall default, Reduce Motion §12 entries, speed-ramp constants → owning game phases
- `SeedableRNG` struct → with first engine; promote to Core/ only if shared
