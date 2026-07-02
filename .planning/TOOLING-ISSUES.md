# Tooling Issues

Local agent/toolchain issues that affect development sessions but are outside
the GameDrawer app release scope.

## Open

- [ ] 2026-06-24 — Invalid Claude cowork schedule skill metadata
  - Symptom: session startup reports `Skipped loading 1 skill(s) due to invalid SKILL.md files.`
  - Path: `/Users/gabrielnielsen/.codex/plugins/cache/claude-cowork/anthropic-skills/1.0.0/skills/schedule/SKILL.md`
  - Error: invalid YAML, `did not find expected key at line 2 column 110, while parsing a block mapping`
  - Impact: the `schedule` skill is unavailable until the cached plugin skill file is fixed or refreshed.
  - App impact: none known; this is local agent tooling, not GameKit code.

