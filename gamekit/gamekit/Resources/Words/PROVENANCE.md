# Word Resources Provenance

GameDrawer v1.4 word-game resources are structured for a SCOWL / English
Speller Database derived pipeline. The bundled seed lists in this repo are
small, curated English word samples used to support the first local-only
implementation and test fixtures.

Source target for expanded lists:
- English Speller Database / SCOWL: https://github.com/en-wl/wordlist
- License notes from upstream: BSD-compatible sources, combined MIT-like
  license; retain upstream copyright/license text when importing a generated
  production-sized list.

Filtering policy:
- Uppercase A-Z only.
- Five Letter answer list: common, non-offensive, recognizable five-letter
  words.
- Five Letter guess list: answer list plus broader five-letter valid words.
- Word Grid list: 3+ letter words appropriate for general-audience gameplay.
