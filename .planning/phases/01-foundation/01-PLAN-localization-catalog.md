---
phase: 01-foundation
plan: 08
type: execute
wave: 5
depends_on: [7]
files_modified:
  - gamekit/gamekit/Resources/Localizable.xcstrings
autonomous: false
requirements:
  - FOUND-05
tags:
  - localization
  - xcstrings
  - resources

must_haves:
  truths:
    - "Localizable.xcstrings exists in gamekit/gamekit/Resources/ with English as the source language"
    - "Every String(localized:) key from Plans 06 and 07 appears in the catalog"
    - "Xcode reports zero stale entries when the catalog is opened"
    - "Building the project auto-extracts new String(localized:) keys into the catalog (SWIFT_EMIT_LOC_STRINGS = YES is already on per Plan 01 verification)"
  artifacts:
    - path: "gamekit/gamekit/Resources/Localizable.xcstrings"
      provides: "Source-of-truth catalog for all P1 user-facing strings"
      contains: "Minesweeper"
      min_lines: 10
  key_links:
    - from: "Localizable.xcstrings"
      to: "Build pipeline (SWIFT_EMIT_LOC_STRINGS)"
      via: "Xcode auto-extraction at build time"
      pattern: "sourceLanguage"
---

<objective>
Create the source-of-truth string catalog `Localizable.xcstrings` under `gamekit/gamekit/Resources/`, populate it with every `String(localized:)` key authored in Plans 06 and 07, and confirm Xcode flags zero stale entries — satisfying FOUND-05.

Purpose: FOUND-05 mandates that all user-facing strings reach the UI via `String(localized:)` with an `xcstrings` catalog populated. The build settings `SWIFT_EMIT_LOC_STRINGS = YES`, `STRING_CATALOG_GENERATE_SYMBOLS = YES`, and `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` are already on in `project.pbxproj` (verified in Plan 01 § "Settings already correct"). Once the catalog file exists, Xcode auto-extracts keys from `String(localized:)` and `Text("...")` calls at every build.

EN-only ship at v1; future locales are mechanical (PROJECT.md / RESEARCH STACK §7). Plurals (e.g. `"%lld games played"`) are deferred to P4 when stats arrive — P1 has no plural-shaped strings.

Output: One new file `gamekit/gamekit/Resources/Localizable.xcstrings` with all P1 keys present and source language set to English.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/01-foundation/01-CONTEXT.md
@.planning/phases/01-foundation/01-PATTERNS.md
@./CLAUDE.md
@gamekit/gamekit/App/GameKitApp.swift
@gamekit/gamekit/Screens/RootTabView.swift
@gamekit/gamekit/Screens/HomeView.swift
@gamekit/gamekit/Screens/SettingsView.swift
@gamekit/gamekit/Screens/StatsView.swift
@gamekit/gamekit/Screens/ComingSoonOverlay.swift
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Create gamekit/gamekit/Resources/Localizable.xcstrings with all P1 keys</name>
  <files>gamekit/gamekit/Resources/Localizable.xcstrings</files>
  <read_first>
    - .planning/phases/01-foundation/01-PATTERNS.md §"`Resources/Localizable.xcstrings` (config — string catalog)" (the target key set + EN source language)
    - .planning/phases/01-foundation/01-CONTEXT.md "Claude's Discretion" line 45 (single Localizable.xcstrings in Resources/, EN source, "Use Compiler to Extract Swift Strings" ON)
    - gamekit/gamekit/Screens/HomeView.swift (every String(localized:) call — there should be 14: 9 game card titles + "GameKit" nav title + "Coming soon" + "Minesweeper coming in Phase 3" + "The board, gestures, and timer arrive next." + the formatted "%@ coming soon" wrapper)
    - gamekit/gamekit/Screens/RootTabView.swift (3 tab labels: "Home", "Stats", "Settings")
    - gamekit/gamekit/Screens/SettingsView.swift (4 strings: "APPEARANCE", "ABOUT", "Theme controls coming in a future update.", "GameKit · v1.0", plus nav title "Settings" — duplicates with RootTabView)
    - gamekit/gamekit/Screens/StatsView.swift (4 strings: "HISTORY", "BEST TIMES", "Your stats will appear here.", "Your best times will appear here.", plus nav title "Stats" — duplicates with RootTabView)
    - gamekit/gamekit/Screens/ComingSoonOverlay.swift (no String(localized:) — title is passed in)
    - .planning/research/STACK.md §7 (every user-facing string via String(localized:) from day 1)
  </read_first>
  <action>
    Create the directory `gamekit/gamekit/Resources/` if it does not exist (Write tool will create it).

    Write `gamekit/gamekit/Resources/Localizable.xcstrings` with EXACTLY this content. The format is Apple's standard xcstrings JSON; every key from the P1 source files appears as a `strings` entry with EN source. Mark each as `state: "translated"` since EN is the source language and the value matches the key.

    ```json
    {
      "sourceLanguage" : "en",
      "strings" : {
        "%@ coming soon" : {
          "comment" : "Disabled-card overlay caption with game name interpolated",
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "%@ coming soon"
              }
            }
          }
        },
        "ABOUT" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "ABOUT"
              }
            }
          }
        },
        "APPEARANCE" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "APPEARANCE"
              }
            }
          }
        },
        "BEST TIMES" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "BEST TIMES"
              }
            }
          }
        },
        "Chess Puzzles" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Chess Puzzles"
              }
            }
          }
        },
        "Coming soon" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Coming soon"
              }
            }
          }
        },
        "Flow" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Flow"
              }
            }
          }
        },
        "GameKit" : {
          "comment" : "App / Home navigation title",
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "GameKit"
              }
            }
          }
        },
        "GameKit · v1.0" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "GameKit · v1.0"
              }
            }
          }
        },
        "HISTORY" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "HISTORY"
              }
            }
          }
        },
        "Home" : {
          "comment" : "Home tab label",
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Home"
              }
            }
          }
        },
        "Merge" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Merge"
              }
            }
          }
        },
        "Minesweeper" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Minesweeper"
              }
            }
          }
        },
        "Minesweeper coming in Phase 3" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Minesweeper coming in Phase 3"
              }
            }
          }
        },
        "Nonogram" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Nonogram"
              }
            }
          }
        },
        "Pattern Memory" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Pattern Memory"
              }
            }
          }
        },
        "Settings" : {
          "comment" : "Settings tab + nav title",
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Settings"
              }
            }
          }
        },
        "Solitaire" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Solitaire"
              }
            }
          }
        },
        "Stats" : {
          "comment" : "Stats tab + nav title",
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Stats"
              }
            }
          }
        },
        "Sudoku" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Sudoku"
              }
            }
          }
        },
        "The board, gestures, and timer arrive next." : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "The board, gestures, and timer arrive next."
              }
            }
          }
        },
        "Theme controls coming in a future update." : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Theme controls coming in a future update."
              }
            }
          }
        },
        "Word Grid" : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Word Grid"
              }
            }
          }
        },
        "Your best times will appear here." : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Your best times will appear here."
              }
            }
          }
        },
        "Your stats will appear here." : {
          "extractionState" : "manual",
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Your stats will appear here."
              }
            }
          }
        }
      },
      "version" : "1.0"
    }
    ```

    Note on the interpolated string: the catalog key `"%@ coming soon"` corresponds to `String(localized: "\(card.title) coming soon")` from HomeView. Swift's `String(localized:)` extracts string-interpolation forms with `%@` placeholders into the catalog. The catalog will accept either format key — Xcode's first build after this commit will reconcile. If the build flags it as a mismatch, switch HomeView to `String(localized: "\(card.title) coming soon", comment: "...")` (which already produces `%@ coming soon`) and rebuild.

    Validate the JSON parses: `python3 -c "import json; d=json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings')); print('OK' if d['sourceLanguage']=='en' else 'BAD')"` outputs `OK`.

    Build:
    ```bash
    xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | tail -50
    ```
    Expected: `BUILD SUCCEEDED`, zero warnings. Xcode's xcstrings tool may auto-add or reconcile the `%@ coming soon` entry as it sees the source-side interpolation; this is normal and the file may be re-touched by the build (re-stage if so).

    If the build adds extra keys via auto-extraction (Xcode discovered a String we missed listing here), that is acceptable — the catalog grows by one entry, no warnings emitted. The acceptance criteria below check for the canonical 25 keys, plus `$count >= 25` to allow extra Xcode-auto-added entries.
  </action>
  <verify>
    <automated>python3 -c "import json; d=json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings')); assert d['sourceLanguage']=='en'; assert len(d['strings']) >= 25"</automated>
  </verify>
  <acceptance_criteria>
    - File `gamekit/gamekit/Resources/Localizable.xcstrings` exists: `test -f gamekit/gamekit/Resources/Localizable.xcstrings` exits 0
    - File parses as valid JSON: `python3 -c "import json; json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings'))"` exits 0
    - Source language is `en`: `python3 -c "import json; d=json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings')); print(d['sourceLanguage'])"` outputs `en`
    - At least 25 entries in `strings` dict: `python3 -c "import json; d=json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings')); print(len(d['strings']))"` outputs a number `>= 25`
    - All 9 game card titles present: `python3 -c "import json; d=json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings'))['strings']; required=['Minesweeper','Merge','Word Grid','Solitaire','Sudoku','Nonogram','Flow','Pattern Memory','Chess Puzzles']; print(all(k in d for k in required))"` outputs `True`
    - All 3 tab labels present: `python3 -c "import json; d=json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings'))['strings']; print(all(k in d for k in ['Home','Stats','Settings']))"` outputs `True`
    - All 4 section headers present: `python3 -c "import json; d=json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings'))['strings']; print(all(k in d for k in ['APPEARANCE','ABOUT','HISTORY','BEST TIMES']))"` outputs `True`
    - All placeholder copy strings present: `python3 -c "import json; d=json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings'))['strings']; required=['Theme controls coming in a future update.','GameKit · v1.0','Your stats will appear here.','Your best times will appear here.','Coming soon','Minesweeper coming in Phase 3','The board, gestures, and timer arrive next.','GameKit']; print(all(k in d for k in required))"` outputs `True`
    - Interpolation key for coming-soon overlay: `python3 -c "import json; d=json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings'))['strings']; print('%@ coming soon' in d)"` outputs `True`
    - Every entry has an EN localization with `state: translated`: `python3 -c "import json; d=json.load(open('gamekit/gamekit/Resources/Localizable.xcstrings'))['strings']; print(all(v.get('localizations',{}).get('en',{}).get('stringUnit',{}).get('state')=='translated' for v in d.values()))"` outputs `True`
    - Build succeeds with strict warnings: `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -c "BUILD SUCCEEDED"` returns at least `1`
    - Build emits no `*.xcstrings` warnings (no stale-key flags): `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -c "stale"` returns exactly `0`
    - No leftover Finder dupes: `find gamekit -name "* 2.swift" -o -name "* 2.xcstrings"` returns no results
  </acceptance_criteria>
  <done>Localizable.xcstrings exists with all 25+ P1 keys, EN source language, every entry marked translated. Build green, zero stale entries.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: User opens the catalog in Xcode and confirms zero stale entries</name>
  <what-built>The catalog has been authored manually with all 25+ keys. Xcode's String Catalog editor surfaces stale entries as a count badge in the editor tab — this is the only reliable way to confirm "zero stale entries" required by FOUND-05 / SC-5.</what-built>
  <how-to-verify>
    1. Open `gamekit/gamekit.xcodeproj` in Xcode.
    2. In the navigator, expand `gamekit/gamekit/Resources/` and click `Localizable.xcstrings`.
    3. The String Catalog editor opens with a list of keys.
    4. **Pass criterion:** the editor shows zero "stale" entries. Stale entries appear with an exclamation-mark icon in the leftmost column. If you see any:
       - For each stale entry, decide: was the key removed from source code, or was it spelled differently? If removed, click the stale entry → press Delete. If spelling-mismatched, fix the source code in the corresponding Swift file (re-build to reconcile) — but this should NOT happen if Plan 07 was committed cleanly.
    5. Glance at the "State" column: every entry should show "Translated" (green checkmark). No "Needs Review", no "New".
    6. Build the project (`⌘B`) one more time inside Xcode. The bottom-right "Issues" navigator should show zero string-catalog warnings.

    **Resume signals:**
    - **"approved"** — zero stale entries, all rows Translated, no warnings.
    - **"issue: <description>"** — describe what showed up (e.g. "stale entry 'Foo' that wasn't in the spec", "Xcode added a key 'Bar' I didn't see in any source file"). The orchestrator will spawn a revision.
  </how-to-verify>
  <resume-signal>Type "approved" or "issue: <description>"</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none) | The xcstrings file is a static resource compiled into the app bundle. No runtime parsing of untrusted data, no user input, no network. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-15 | Tampering | Localizable.xcstrings | accept | Catalog ships in the signed app bundle; tampering would require breaking app signing. The strings themselves are user-facing copy — if compromised the user sees garbled text, not arbitrary code execution. |
| T-01-16 | Information Disclosure | Localizable.xcstrings | accept | Catalog contains UI labels — explicitly designed to be visible to users. No PII, no secrets, no internal-only debug strings. |

**N/A categories:** Spoofing, Repudiation, DoS, Elevation of Privilege — static resource file with no runtime behavior.
</threat_model>

<verification>
After both tasks:
- `gamekit/gamekit/Resources/Localizable.xcstrings` parses as valid JSON, has 25+ entries.
- Every entry has an EN localization marked `state: translated`.
- `xcodebuild` exits 0 with `BUILD SUCCEEDED`, zero warnings.
- User confirmed via checkpoint that Xcode shows zero stale entries.
</verification>

<success_criteria>
- All Task 1 acceptance criteria pass.
- User-confirmed via checkpoint that Xcode reports zero stale entries.
- Catalog is in the canonical location (`Resources/`) per CLAUDE.md §3 + ARCHITECTURE.md folder layout.
- Future EN string additions in P2-P7 will auto-extract into this catalog at build time (`SWIFT_EMIT_LOC_STRINGS = YES` from Plan 01).
- Plurals deferred to P4 (when stats arrive — "%lld games played"). P1 has no plural-shaped strings.
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-08-SUMMARY.md` per the template.
</output>
