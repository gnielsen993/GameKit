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

## `five-letter-answers.txt` — Five Letter secret-answer pool

1,033 common, fair five-letter words used as the secret answer for Daily /
Unlimited. Intentionally smaller and more common than the guess list so
answers stay recognizable and solvable.

- Sources: `first20hours/google-10000-english` (`-no-swears`, MIT,
  frequency-ranked) ∩ `dwyl/english-words` (Unlicense), unioned with the
  curated built-in pool in `WordLexicon.swift`.
- Build: take google's top-10k words that are 5 letters and are valid
  real words; drop true plurals/3rd-person forms (word ends in `S` and its
  4-letter stem is itself a real word, e.g. BANKS→BANK) for fairness; keep
  genuine `-S` words (CHESS, GLASS, FOCUS); union the 40 curated answers.
- `WordLexicon.fiveLetterAnswers` unions this with the curated pool, so it
  is always a superset; sorted for deterministic seeded selection.

## `word-grid-words.txt` — Word Grid validation dictionary

148,736 words (3–8 letters) used to validate traced words in Word Grid
(`isValidGridWord`). Broad on purpose so any real word a player traces is
accepted.

- Source: `dwyl/english-words` (Unlicense), 3–8 letters, uppercase A–Z,
  deduplicated, unioned with the curated generation words.
- Board *generation* does NOT use this list — it uses the small curated
  `wordGridGenerationWords` in `WordLexicon.swift` (drives prefix pruning
  and DFS depth), so generated boards stay built around common words and
  generation stays fast.

Future expansion target for higher-quality curation:
- English Speller Database / SCOWL: https://github.com/en-wl/wordlist
  (BSD-compatible / MIT-like — retain upstream license text on import).

Filtering policy:
- Uppercase A-Z only.
- Five Letter answer list: common, fair, non-offensive five-letter words.
- Five Letter guess list: broad set of valid five-letter words.
- Word Grid list: 3+ letter words appropriate for general-audience gameplay.
