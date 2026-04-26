# Audio Asset Provenance — GameKit Phase 5

All `.caf` files in this folder are 16-bit 44.1 kHz mono per CONTEXT D-08 + Specifics.
Encoded via `afconvert -f caff -d LEI16@44100 -c 1 input.wav output.caf`.

| File | Source | License | Notes |
|------|--------|---------|-------|
| tap.caf | (TBD — fill in at Task 3 checkpoint) | (TBD) | Cell-reveal cue, ~30KB target, CONTEXT D-08 |
| win.caf | (TBD) | (TBD) | Win chime, ~50KB target, CONTEXT D-08 |
| loss.caf | (TBD) | (TBD) | Loss thud, ~40KB target, CONTEXT D-08 |

## Recording / Sourcing Constraints

- **License:** must be CC0 / Public Domain OR hand-recorded by the project author. No CC-BY (attribution requirement complicates v1 ABOUT screen).
- **Format:** CAF (Core Audio Format), 16-bit, 44.1 kHz, mono.
- **Length:** tap < 200 ms; win 0.4–0.8 s; loss 0.4–0.8 s.
- **Loudness:** peak normalized to -3 dBFS to leave headroom under user music (per AVAudioSession.ambient mix posture, D-09).
- **Vibe (per PROJECT.md "calm + premium"):** subtle, not jarring. tap = soft click; win = single soft chime; loss = low muted thud (no harsh sfx).

## Suggested CC0 sources

- https://freesound.org/ — filter by CC0 license
- https://opengameart.org/ — filter by Public Domain
- Hand-record via Voice Memos → export WAV → `afconvert` to CAF.

## Update history

- 2026-04-26 (Plan 05-02): scaffold created; tap/win/loss to be filled at Task 3 checkpoint.
