# Word Resources Provenance

GameDrawer v1.4 word-game resources are derived English word lists used by
the local-only word games. Lists are bundled as plain `.txt` (one uppercase
word per line) and loaded at runtime by `WordLexicon`.

## `five-letter-guesses.txt` — production accepted-guess list

The Five Letter accepted-guess dictionary (15,921 five-letter words,
including plurals and inflected forms so common words like `BANKS` /
`WALKS` are accepted).

- Source: `dwyl/english-words` (`words_alpha.txt`):
  https://github.com/dwyl/english-words
- License: The Unlicense (public domain) — no attribution required.
- Build: `grep -E '^[a-z]{5}$' words_alpha.txt | tr '[:lower:]' '[:upper:]'
  | sort -u`. Uppercase A–Z only, deduplicated, sorted.
- `WordLexicon.fiveLetterGuesses` unions this with the curated answer pool
  and a built-in fallback, so it is always a superset of both.

## Other lists (curated seed lists)

`five-letter-answers.txt` and `word-grid-words.txt` remain small curated
seed lists; the live answer pool / Word Grid dictionary are currently the
curated arrays in `WordLexicon.swift`. Future expansion target:
- English Speller Database / SCOWL: https://github.com/en-wl/wordlist
  (BSD-compatible / MIT-like — retain upstream license text on import).

Filtering policy:
- Uppercase A-Z only.
- Five Letter answer list: common, non-offensive, recognizable five-letter
  words.
- Five Letter guess list: broad set of valid five-letter words.
- Word Grid list: 3+ letter words appropriate for general-audience gameplay.
