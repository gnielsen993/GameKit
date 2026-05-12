# Phase 8: Video Mode Design - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `08-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-12
**Phase:** 08-video-mode-design
**Areas discussed:** Design medium + screenshot source, Compact picker tokens, Win/loss banner placement

---

## Gray Area Selection

Four candidate gray areas presented. User selected three; declined "Hard Mines strategy (ADR)".

| Option | Description | Selected |
|--------|-------------|----------|
| Hard Mines strategy (ADR) | 4 candidates (smaller cells / scroll-pan / pinch-zoom / warning+compromise); must lock here; interacts with A11Y-05 | |
| Design medium + screenshot source | HTML sketch vs SwiftUI Preview vs Figma vs paper; fresh vs reused screenshots | ✓ |
| Compact picker tokens | Pill height / radius / hit-target floor; per-game slot mapping | ✓ |
| Win/loss banner placement rule | Per-PiP-zone placement system; primary action; confetti+haptics+SFX gating | ✓ |

**Note on the unpicked area:** Hard Mines strategy decision is still required at phase exit (SC2 of ROADMAP §Phase 8). The user opted to defer the choice to design-execution sketch work rather than pre-commit here. Captured as D-13 in CONTEXT.md.

---

## Design Medium + Screenshot Source

### Q1: Design medium for Phase 8 sketches

| Option | Description | Selected |
|--------|-------------|----------|
| HTML sketches (gsd-sketch) | Fastest iteration; multi-variant; throwaway; no app target | ✓ |
| SwiftUI Preview throwaways | Closer to ship surface; risks production-code drift; Phase 8 SC5 forbids ship code | |
| Figma / external tool | Highest fidelity; external dep + export friction | |
| Paper + photos | Lowest-fi; less reviewable | |

**Notes:** Lives under `.planning/sketches/`. Does NOT ship in `gamekit` target.

### Q2: Screenshot source for the annotated layout doc

| Option | Description | Selected |
|--------|-------------|----------|
| Capture fresh (sim) | Plan doc explicitly mandates Gabe's screenshots; existing set is partial | ✓ |
| Reuse existing May-2 ASC shots | Faster but missing Easy / Medium / Nonogram | |
| Mix — reuse + capture gaps | Pragmatic blend | |

### Q3: Screenshot preset coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Classic + one Loud (Dracula) | Every downstream phase needs Classic + Loud (CLAUDE.md §8.12) | ✓ |
| Classic only | Defers Loud-preset legibility check | |
| Classic + Dracula + Voltage | Maximum; probably overkill at design phase | |

### Q4: Device coverage

| Option | Description | Selected |
|--------|-------------|----------|
| iPhone smallest + iPhone 17 Pro Max | Captures Hard-Mines squeeze gradient | |
| iPhone 17 Pro Max only | Fastest; matches existing ASC dir | ✓ |
| Pro Max + iPad 13-inch | If iPad is a real target | |

**Notes on Q4:** User picked Pro Max only despite Pro Max being the comfortable case. CONTEXT.md captures this as D-04 with the explicit follow-up that Hard-Mines design pass should still manually verify against smallest iPhone width even though screenshot capture is Pro-Max-only.

---

## Compact Picker Tokens

### Q1: Picker pill corner-radius anchor

| Option | Description | Selected |
|--------|-------------|----------|
| radii.button | Matches existing Reveal/Flag FAB; distinct from info chips | ✓ |
| radii.chip | Same family as info chips; flattens prominence | |
| New radii.pill anchor | Premature DesignKit promotion; defer | |

### Q2: Picker pill height token anchor

| Option | Description | Selected |
|--------|-------------|----------|
| spacing.xl | Between info-chip height (spacing.l) and full button height | ✓ |
| spacing.l | Same as info chips; loses prominence contract | |
| 44pt fixed (a11y floor) | iOS HIG; not token-discipline-friendly | |

### Q3: Row inter-item spacing

| Option | Description | Selected |
|--------|-------------|----------|
| spacing.s | Compact + tappable; matches existing Mines header gap | ✓ |
| spacing.m | More breathing room; risks pushing settings off Hard layout | |
| spacing.xs | Max-compact; fat-finger risk on adjacent items | |

### Q4: Per-game label mapping

| Option | Description | Selected |
|--------|-------------|----------|
| Plan-doc verbatim | Mines/Merge/Nonogram slots from `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §Compact control row | ✓ |
| Revise during design | Open the mapping per-game during sketch work | |

---

## Win/Loss Banner Placement

### Q1: Banner anchor rule

| Option | Description | Selected |
|--------|-------------|----------|
| Opposite-of-PiP rule | Deterministic; one rule six outcomes | ✓ |
| Always docked to compact control row | Two layouts; ignores Small-corner zones | |
| Center overlay w/ PiP-zone padding | Hardest to make non-board-covering on Hard Mines | |

### Q2: Banner shape

| Option | Description | Selected |
|--------|-------------|----------|
| Pill (compact, full-width-minus-margins) | Spans safe edge; small vertical footprint; reads as chrome | ✓ |
| Card (taller, stacked content + action) | Info-dense; risks board-coverage | |
| Full-width bar (edge-to-edge) | Max prominence; slightly modal | |

### Q3: Primary-action surface

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit DKButton inside banner | Visible affordance; VoiceOver-friendly; one tap | ✓ |
| Entire banner is tappable | One tap but less discoverable; conflicts w/ A11Y | |
| Action behind expand | Forbidden by VIDEO-11 SC2 | |

### Q4: Reduce-Motion handling

| Option | Description | Selected |
|--------|-------------|----------|
| Dampen to identity (no motion) | Mirrors v1.0 05-06 D-04 lock | ✓ |
| Reduce intensity (shorter durations) | Weaker than plan-doc's "near-zero" phrase | |
| Decide per-effect during design | Risks inconsistency across games | |

---

## Claude's Discretion

- Sketch HTML structure / styling within `.planning/sketches/`
- Sketch variant count per artifact
- Filename convention inside `.planning/sketches/08-video-mode-design/`

## Deferred Ideas

- Hard Mines strategy choice — deferred to design execution + ADR at phase exit (D-13)
- PiP-location persistence: global vs per-game — Phase 9 decides
- Small-PiP simpler top/bottom-only mode — v1.3+ candidate
- Vertical / portrait PiP — explicit Out of Scope
- Sudoku slot mapping — game not built
- Per-game compact-picker variants — forbidden by VIDEO-04
- `radii.pill` DesignKit token — defer until 2+ consumers
- Auto-detect of another app's PiP frame — no public iOS API
