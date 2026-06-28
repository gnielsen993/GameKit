# Phase 16: Stack - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-27
**Phase:** 16-stack
**Areas discussed:** Combo recovery feel, Block color treatment, Perfect & game-over feedback, Stats scope this phase

---

## Combo recovery feel

### How a near-perfect drop rewards the player

| Option | Description | Selected |
|--------|-------------|----------|
| Single perfect restores | Every near-perfect restores a fixed width amount (research's calm-brand pick) | |
| Streak expands | Width only recovers after N consecutive perfects, then expands more; broken streak gives nothing | ✓ |
| Single restore + streak bonus | Small fixed restore each perfect plus an escalating streak bonus | |

**User's choice:** Streak expands.
**Notes:** Deliberately higher skill ceiling than the research default; difficulty lives in the recovery mechanic, not twitch acceleration.

### What counts as a "perfect"

| Option | Description | Selected |
|--------|-------------|----------|
| Small tolerance band | Within a few points of dead-center counts; streaks build more often | ✓ |
| Exact alignment only | Pixel-perfect zero-overhang only; streaks of 5+ become very rare | |

**User's choice:** Small tolerance band.
**Notes:** Keeps the streak mechanic rewarding given recovery is already streak-gated. Tolerance value, streak N, and expansion amount left as tuning constants.

---

## Block color treatment

| Option | Description | Selected |
|--------|-------------|----------|
| Per-layer gradient | Each layer steps through a hue/lightness ramp from the preset accent; tower becomes a palette | ✓ |
| Flat accent | Every block the same theme accent | |
| Flat + active-block highlight | Flat tower, only the live block highlighted | |

**User's choice:** Per-layer gradient.

### Gradient behavior on tall towers

| Option | Description | Selected |
|--------|-------------|----------|
| Cycle by block index | Color fixed by position, ramp repeats; placed block never recolors | ✓ |
| Span visible window | Gradient stretches across on-screen tower; a block's color shifts as view scrolls | |

**User's choice:** Cycle by block index.
**Notes:** Stable palette bands. Lightness fallback for monochrome presets; must pass §8.12 + colorblind-safe. Cycle length is a tuning constant.

---

## Perfect & game-over feedback

### Perfect-drop feel (multi-select)

| Option | Description | Selected |
|--------|-------------|----------|
| Color pulse/glow | Block flashes/glows; instant flash under Reduce Motion | ✓ |
| Haptic tick | Light impact distinct from normal-drop impact | ✓ |
| SFX chime | Rising musical tone per perfect (off by default) | |
| Combo counter bump | Counter animates/scales on increment; instant under Reduce Motion | ✓ |

**User's choice:** Color pulse/glow + Haptic tick + Combo counter bump (no SFX).

### Game-over moment

| Option | Description | Selected |
|--------|-------------|----------|
| Slow-mo final block + drain | ~0.5s slow-mo fall + color drain, then banner; instant cut under Reduce Motion | ✓ |
| Instant cut to banner | Banner appears immediately | |
| Color drain only | Desaturate then banner, no slow-mo | |

**User's choice:** Slow-mo final block + drain.
**Notes:** Never any screen shake. Timing per DESIGN.md §10.3. Reuses VideoModeBanner.

---

## Stats scope this phase

| Option | Description | Selected |
|--------|-------------|----------|
| High score + runs + streak | Persist/show all three now; best-perfect-streak captured this phase | ✓ |
| High score + runs only | Literal SC3 bar; defer streak to Phase 18 | |

**User's choice:** High score + runs + streak.
**Notes:** Streak mechanic is core to this phase, so capture it at game-over now. Full ARCADE-07 layout polish stays in Phase 18. Flagged as a research constraint: persist best-perfect-streak CloudKit-safe without a schema bump (Phase 15 locked no new SwiftData model).

## Claude's Discretion

- Block oscillation style, starting speed, idle/tap-to-start screen, danger-zone treatment, gradient cycle length, tolerance/N/expansion tuning constants, SeedableRNG placement.
- fixedDt (1/60), accumulator-in-VM, Frame struct shape — research-confirmed defaults.

## Deferred Ideas

- Full score-based Stats shape (ARCADE-07) → Phase 18.
- SFX cues (block placement / perfect chime) → not this phase.
- Daily seed, score trend charts, run-summary micro-screen → v2+.
