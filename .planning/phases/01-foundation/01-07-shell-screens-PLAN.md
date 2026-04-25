---
phase: 01-foundation
plan: 07
type: execute
wave: 4
depends_on: [6]
files_modified:
  - gamekit/gamekit/Screens/RootTabView.swift
  - gamekit/gamekit/Screens/HomeView.swift
  - gamekit/gamekit/Screens/SettingsView.swift
  - gamekit/gamekit/Screens/StatsView.swift
  - gamekit/gamekit/Screens/ComingSoonOverlay.swift
  - gamekit/gamekit/Screens/SettingsComponents.swift
autonomous: false
requirements:
  - FOUND-03
  - SHELL-01
tags:
  - swiftui
  - tabview
  - home-screen
  - shell
  - designkit-tokens

must_haves:
  truths:
    - "RootTabView is a 3-tab TabView (Home / Stats / Settings); each tab owns its own NavigationStack"
    - "HomeView lists 9 game cards: Minesweeper enabled, plus Merge/Word Grid/Solitaire/Sudoku/Nonogram/Flow/Pattern Memory/Chess Puzzles disabled (matching PROJECT.md vision order per D-03)"
    - "Disabled cards show reduced opacity + lock SF Symbol; tapping a disabled card surfaces a token-styled ComingSoonOverlay that auto-dismisses"
    - "Tapping Minesweeper navigates inside Home tab's stack to a token-styled 'Coming in P3' placeholder destination"
    - "Settings + Stats stubs render section headers + DKCard skeletons with intentional placeholder copy (NOT empty cards)"
    - "Every visible token usage reads from theme.colors.* / theme.spacing.* / theme.radii.* — switching themes produces no hardcoded color bleedthrough"
    - "Every user-facing string uses String(localized:) or SwiftUI's LocalizedStringKey form"
    - "Each Swift file is ≤ 250 lines (well under §8.1 cap of 400)"
  artifacts:
    - path: "gamekit/gamekit/Screens/RootTabView.swift"
      provides: "3-tab TabView root, .tint(theme.colors.accentPrimary)"
      contains: "TabView"
      min_lines: 30
      max_lines: 80
    - path: "gamekit/gamekit/Screens/HomeView.swift"
      provides: "Mines enabled card + 8 disabled placeholders + ComingSoonOverlay state"
      contains: "GameCard"
      min_lines: 80
      max_lines: 250
    - path: "gamekit/gamekit/Screens/SettingsView.swift"
      provides: "Themed scaffold stub with APPEARANCE + ABOUT sections"
      contains: "settingsSectionHeader"
      min_lines: 30
      max_lines: 100
    - path: "gamekit/gamekit/Screens/StatsView.swift"
      provides: "Themed scaffold stub with HISTORY + BEST TIMES sections"
      min_lines: 30
      max_lines: 100
    - path: "gamekit/gamekit/Screens/ComingSoonOverlay.swift"
      provides: "Floating capsule overlay with sparkles SF Symbol"
      contains: "theme.radii.chip"
      min_lines: 20
      max_lines: 60
    - path: "gamekit/gamekit/Screens/SettingsComponents.swift"
      provides: "settingsSectionHeader and settingsNavRow free @ViewBuilder helpers"
      contains: "settingsSectionHeader"
      min_lines: 20
      max_lines: 80
  key_links:
    - from: "HomeView (disabled card tap)"
      to: "ComingSoonOverlay"
      via: ".overlay(alignment: .bottom)"
      pattern: "showingComingSoon"
    - from: "RootTabView"
      to: "HomeView, StatsView, SettingsView"
      via: "TabView + Label"
      pattern: "TabView"
    - from: "Every screen file"
      to: "DesignKit.theme(using:)"
      via: "@EnvironmentObject + @Environment(\\.colorScheme)"
      pattern: "themeManager.theme(using: colorScheme)"
---

<objective>
Build the navigable shell that satisfies SHELL-01 + the bulk of FOUND-03: a `TabView`-rooted `RootTabView` (Home / Stats / Settings), a `HomeView` that renders 9 game cards (1 enabled Minesweeper, 8 disabled placeholders with `ComingSoonOverlay` toast on tap), and themed-scaffold-only `SettingsView` / `StatsView` stubs. Every visible pixel reads `theme.colors.*` / `theme.spacing.*` / `theme.radii.*` per CLAUDE.md §1.

Purpose: This is the user's first usable screen. It must demonstrate that DesignKit is wired correctly (theme switches don't bleed hardcoded colors), that the 8 future-game placeholders signal long-term suite intent (D-03), and that token discipline is enforced from day 1 (the pre-commit hook from Plan 02 catches violations on commit).

What this plan does NOT include (deferred to later phases per CONTEXT D-04, D-05):
- Real Settings spine (theme picker, haptics toggle, SFX toggle, reset stats) → P5 / SHELL-02
- Real Stats data (per-difficulty rows, @Query, empty-state copy "No games played yet.") → P4 / SHELL-03
- IntroFlow (3-step first-launch) → P5 / SHELL-04
- The Minesweeper game itself (push destination is a placeholder) → P3
- Localizable.xcstrings catalog file (auto-extracted from `String(localized:)` calls in Plan 08)

Output: 6 new Swift files under `gamekit/gamekit/Screens/`; the existing `RootTabView.swift` stub from Plan 06 is replaced with the full TabView body. Project builds with `BUILD SUCCEEDED`, zero warnings under strict concurrency. Manual checkpoint verifies the home screen renders + theme switches don't break.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/01-foundation/01-CONTEXT.md
@.planning/phases/01-foundation/01-PATTERNS.md
@.planning/research/ARCHITECTURE.md
@./CLAUDE.md
@gamekit/gamekit/App/GameKitApp.swift
@gamekit/gamekit/Screens/RootTabView.swift
@../DesignKit/Sources/DesignKit/Theme/ThemeManager.swift
@../DesignKit/Sources/DesignKit/Theme/Tokens.swift

<interfaces>
<!-- Theme-injection three-line snippet (PATTERNS.md "Shared Patterns" §"Theme injection") -->
<!-- Use this in every screen file: -->

```swift
@EnvironmentObject private var themeManager: ThemeManager
@Environment(\.colorScheme) private var colorScheme
private var theme: Theme { themeManager.theme(using: colorScheme) }
```

<!-- DesignKit token vocabulary (PATTERNS.md "Token discipline") - the ONLY allowed values inside Screens/ -->

```swift
// Radii
theme.radii.card    // 16
theme.radii.button  // 14
theme.radii.chip    // 12
theme.radii.sheet   // 22

// Spacing
theme.spacing.xs    // 4
theme.spacing.s     // 8
theme.spacing.m     // 12
theme.spacing.l     // 16
theme.spacing.xl    // 24
theme.spacing.xxl   // 32

// Colors
theme.colors.background / .surface / .surfaceElevated / .border
theme.colors.textPrimary / .textSecondary / .textTertiary
theme.colors.accentPrimary / .accentSecondary / .highlight
theme.colors.success / .warning / .danger
theme.colors.fillPressed / .fillSelected / .fillDisabled
```

<!-- DKCard signature from ../DesignKit/Sources/DesignKit/Components/DKCard.swift (read this file before authoring HomeView card content) -->
```swift
public struct DKCard<Content: View>: View {
    public init(theme: Theme, @ViewBuilder content: () -> Content)
}
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Create SettingsComponents.swift, ComingSoonOverlay.swift, SettingsView.swift, StatsView.swift (the supporting screens)</name>
  <files>
    gamekit/gamekit/Screens/SettingsComponents.swift
    gamekit/gamekit/Screens/ComingSoonOverlay.swift
    gamekit/gamekit/Screens/SettingsView.swift
    gamekit/gamekit/Screens/StatsView.swift
  </files>
  <read_first>
    - .planning/phases/01-foundation/01-PATTERNS.md §"`Screens/SettingsComponents.swift`" (the verbatim helpers to copy: settingsSectionHeader + settingsNavRow)
    - .planning/phases/01-foundation/01-PATTERNS.md §"`Screens/ComingSoonOverlay.swift`" (exact view body, ~25 lines)
    - .planning/phases/01-foundation/01-PATTERNS.md §"`Screens/SettingsView.swift` (screen, request-response — STUB)" (skeletal shape — empty DKCard with placeholder copy)
    - .planning/phases/01-foundation/01-PATTERNS.md §"`Screens/StatsView.swift` (screen, request-response — STUB)" (same skeleton, HISTORY + BEST TIMES sections)
    - .planning/phases/01-foundation/01-CONTEXT.md "D-04" (themed scaffold ONLY, no content text yet) and "D-06" (sparkles SF Symbol, lock badge)
    - ../DesignKit/Sources/DesignKit/Components/DKCard.swift (confirm the `init(theme:content:)` signature)
    - ./CLAUDE.md §1 (no hardcoded colors / radii / spacing), §8.3 (every data-driven view ships with explicit empty state — even stubs need intentional placeholder copy), §8.6 (`.foregroundStyle` not `.foregroundColor`)
  </read_first>
  <action>
    Create all four files in `gamekit/gamekit/Screens/`. Each uses the theme-injection three-line snippet (see interfaces).

    **File 1 — `gamekit/gamekit/Screens/SettingsComponents.swift`** (verbatim from PATTERNS.md "SettingsComponents" excerpt):

    ```swift
    //
    //  SettingsComponents.swift
    //  gamekit
    //
    //  Local helpers for SettingsView (and StatsView) — section headers + nav rows.
    //  Free @ViewBuilder functions, not promoted to DesignKit (CLAUDE.md §2:
    //  promote only when used in 2+ games — these aren't game-specific anyway).
    //

    import SwiftUI
    import DesignKit

    @ViewBuilder
    func settingsSectionHeader(theme: Theme, _ title: String) -> some View {
        Text(title)
            .font(theme.typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(theme.colors.textTertiary)
            .tracking(1.2)
            .padding(.leading, theme.spacing.xs)
    }

    @ViewBuilder
    func settingsNavRow(theme: Theme, title: String) -> some View {
        HStack {
            Text(title)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(theme.colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    ```

    **File 2 — `gamekit/gamekit/Screens/ComingSoonOverlay.swift`** (verbatim from PATTERNS.md):

    ```swift
    //
    //  ComingSoonOverlay.swift
    //  gamekit
    //
    //  Floating capsule surfaced when a disabled game card is tapped.
    //  Per D-06: discoverability over silence.
    //  All styling via DesignKit tokens — radii.chip is the smallest existing token.
    //

    import SwiftUI
    import DesignKit

    struct ComingSoonOverlay: View {
        let title: String
        let theme: Theme

        var body: some View {
            HStack(spacing: theme.spacing.s) {
                Image(systemName: "sparkles")
                    .foregroundStyle(theme.colors.accentPrimary)
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textPrimary)
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.s)
            .background(theme.colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                    .stroke(theme.colors.border, lineWidth: 1)
            )
            .padding(.bottom, theme.spacing.l)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    ```

    Note: `lineWidth: 1` is a numeric literal but is NOT padding/cornerRadius — the pre-commit hook only flags `cornerRadius:\s*[0-9]+` and `\.padding\(\s*[0-9]+`, not stroke widths. Stroke widths are not theme-tokenized in DesignKit's current API. If a future DesignKit version adds `theme.borders.thin`, switch to that.

    **File 3 — `gamekit/gamekit/Screens/SettingsView.swift`** (themed-scaffold stub per D-04):

    ```swift
    //
    //  SettingsView.swift
    //  gamekit
    //
    //  Phase 1: themed scaffold stub.
    //  Real Settings spine (theme picker, haptics, SFX, reset stats, about)
    //  arrives at Phase 5 (SHELL-02) per D-04.
    //  Real empty state copy lands then; for now use placeholder copy
    //  (CLAUDE.md §8.3: never blank cards).
    //

    import SwiftUI
    import DesignKit

    struct SettingsView: View {
        @EnvironmentObject private var themeManager: ThemeManager
        @Environment(\.colorScheme) private var colorScheme

        private var theme: Theme { themeManager.theme(using: colorScheme) }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.l) {

                        settingsSectionHeader(theme: theme, String(localized: "APPEARANCE"))
                        DKCard(theme: theme) {
                            Text(String(localized: "Theme controls coming in a future update."))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        settingsSectionHeader(theme: theme, String(localized: "ABOUT"))
                        DKCard(theme: theme) {
                            Text(String(localized: "GameKit · v1.0"))
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(theme.spacing.l)
                }
                .background(theme.colors.background.ignoresSafeArea())
                .navigationTitle(String(localized: "Settings"))
            }
        }
    }
    ```

    **File 4 — `gamekit/gamekit/Screens/StatsView.swift`** (same skeleton, HISTORY + BEST TIMES sections):

    ```swift
    //
    //  StatsView.swift
    //  gamekit
    //
    //  Phase 1: themed scaffold stub.
    //  Real per-difficulty stats (with @Query) arrive at Phase 4 (SHELL-03)
    //  per D-04 / D-11. Empty state ("No games played yet.") lands then.
    //

    import SwiftUI
    import DesignKit

    struct StatsView: View {
        @EnvironmentObject private var themeManager: ThemeManager
        @Environment(\.colorScheme) private var colorScheme

        private var theme: Theme { themeManager.theme(using: colorScheme) }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.l) {

                        settingsSectionHeader(theme: theme, String(localized: "HISTORY"))
                        DKCard(theme: theme) {
                            Text(String(localized: "Your stats will appear here."))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        settingsSectionHeader(theme: theme, String(localized: "BEST TIMES"))
                        DKCard(theme: theme) {
                            Text(String(localized: "Your best times will appear here."))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(theme.spacing.l)
                }
                .background(theme.colors.background.ignoresSafeArea())
                .navigationTitle(String(localized: "Stats"))
            }
        }
    }
    ```

    Build the project after creating all 4 files:
    ```bash
    xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | tail -30
    ```
    Expected: `BUILD SUCCEEDED` (HomeView is still missing but RootTabView from Plan 06 just shows a `Rectangle().fill(theme.colors.background)` — neither references HomeView yet, so build is green).

    Run the pre-commit hook against the staged files: `git add gamekit/gamekit/Screens/*.swift && bash .githooks/pre-commit && echo "HOOK PASSED"`. MUST exit 0.
  </action>
  <verify>
    <automated>xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -c "BUILD SUCCEEDED"</automated>
  </verify>
  <acceptance_criteria>
    - All four files exist: `test -f` exits 0 for SettingsComponents.swift, ComingSoonOverlay.swift, SettingsView.swift, StatsView.swift under `gamekit/gamekit/Screens/`
    - SettingsComponents exports `settingsSectionHeader` and `settingsNavRow`: `grep -c "func settingsSectionHeader" gamekit/gamekit/Screens/SettingsComponents.swift` returns `1` AND same for `settingsNavRow`
    - ComingSoonOverlay uses `theme.radii.chip` (NOT `.card`/.`button`/`.sheet` — D-06 visual spec): `grep -c "theme.radii.chip" gamekit/gamekit/Screens/ComingSoonOverlay.swift` returns at least `1`
    - ComingSoonOverlay uses sparkles SF Symbol per D-06: `grep -c '"sparkles"' gamekit/gamekit/Screens/ComingSoonOverlay.swift` returns exactly `1`
    - SettingsView + StatsView use `theme(using: colorScheme)` (NOT `theme(for:)` per Note A): `grep -c "theme(using: colorScheme)" gamekit/gamekit/Screens/SettingsView.swift` returns exactly `1` AND same for StatsView.swift
    - SettingsView + StatsView use String(localized:) for all visible strings: every `Text(` call inside these two files passes `String(localized:` — verify via `grep -E 'Text\(' gamekit/gamekit/Screens/{SettingsView,StatsView}.swift | grep -vc "String(localized:" | tr -d '\n'` returns `0` (every Text uses localized form)
    - No hardcoded Color literals in any of the four files: `grep -cE 'Color\(\s*(red:|hex:|white:)|Color\.(red|blue|green|gray|orange|yellow|pink|purple|black|white)' gamekit/gamekit/Screens/SettingsComponents.swift gamekit/gamekit/Screens/ComingSoonOverlay.swift gamekit/gamekit/Screens/SettingsView.swift gamekit/gamekit/Screens/StatsView.swift` returns exactly `0`
    - No numeric cornerRadius literals: `grep -cE 'cornerRadius:\s*[0-9]+' gamekit/gamekit/Screens/SettingsComponents.swift gamekit/gamekit/Screens/ComingSoonOverlay.swift gamekit/gamekit/Screens/SettingsView.swift gamekit/gamekit/Screens/StatsView.swift` returns `0` (cornerRadius args are all `theme.radii.X` references)
    - No numeric padding integer literals: `grep -cE '\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)' gamekit/gamekit/Screens/SettingsComponents.swift gamekit/gamekit/Screens/ComingSoonOverlay.swift gamekit/gamekit/Screens/SettingsView.swift gamekit/gamekit/Screens/StatsView.swift` returns `0`
    - Use `.foregroundStyle` not `.foregroundColor` per §8.6: `grep -c "foregroundColor" gamekit/gamekit/Screens/SettingsComponents.swift gamekit/gamekit/Screens/ComingSoonOverlay.swift gamekit/gamekit/Screens/SettingsView.swift gamekit/gamekit/Screens/StatsView.swift` returns `0`
    - File size caps respected: `[ $(wc -l < gamekit/gamekit/Screens/SettingsView.swift) -le 100 ] && [ $(wc -l < gamekit/gamekit/Screens/StatsView.swift) -le 100 ] && [ $(wc -l < gamekit/gamekit/Screens/ComingSoonOverlay.swift) -le 60 ] && [ $(wc -l < gamekit/gamekit/Screens/SettingsComponents.swift) -le 80 ]` exits 0
    - Build succeeds: `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -c "BUILD SUCCEEDED"` returns at least `1`
    - Build emits zero warnings: `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -cE "warning:"` returns exactly `0`
    - Pre-commit hook passes: `git add gamekit/gamekit/Screens/SettingsComponents.swift gamekit/gamekit/Screens/ComingSoonOverlay.swift gamekit/gamekit/Screens/SettingsView.swift gamekit/gamekit/Screens/StatsView.swift && bash .githooks/pre-commit` exits 0
  </acceptance_criteria>
  <done>4 supporting screens / helpers exist; build green; hook passes; all token-discipline checks pass.</done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Create HomeView.swift with 9 game cards (Mines enabled + 8 disabled) and ComingSoonOverlay state; replace RootTabView.swift body with the 3-tab TabView</name>
  <files>
    gamekit/gamekit/Screens/HomeView.swift
    gamekit/gamekit/Screens/RootTabView.swift
  </files>
  <read_first>
    - .planning/phases/01-foundation/01-PATTERNS.md §"`Screens/HomeView.swift`" (full pattern: imports, theme-binding, ScrollView+VStack body, GameCard data model with all 9 cards in PROJECT.md vision order, DKCard visual pattern, tap behavior for enabled vs disabled)
    - .planning/phases/01-foundation/01-PATTERNS.md §"`Screens/RootTabView.swift`" (3-tab TabView body — drop FT's 5-tab version + active session overlays per D-02)
    - .planning/phases/01-foundation/01-CONTEXT.md "D-02" (TabView root, each tab owns NavigationStack), "D-03" (8 future games disabled, PROJECT.md order: Merge, Word Grid, Solitaire, Sudoku, Nonogram, Flow, Pattern Memory, Chess Puzzles), "D-06" (coming-soon overlay on tap)
    - .planning/research/ARCHITECTURE.md §"Anti-Pattern 3: NavigationStack scattered across views" (single NavigationStack inside each tab's root, NOT in RootTabView)
    - gamekit/gamekit/Screens/RootTabView.swift (the stub from Plan 06 — to be replaced)
    - gamekit/gamekit/Screens/ComingSoonOverlay.swift (just created in Task 1 — will be referenced)
    - ../DesignKit/Sources/DesignKit/Components/DKCard.swift (confirm signature)
    - ./CLAUDE.md §1, §8.1 (≤400-line views), §8.5 (≤500-line files), §8.6 (.foregroundStyle)
  </read_first>
  <action>
    **File 1 — `gamekit/gamekit/Screens/HomeView.swift`** (full implementation per PATTERNS.md):

    ```swift
    //
    //  HomeView.swift
    //  gamekit
    //
    //  Phase 1 (SHELL-01): 9 game cards in PROJECT.md long-term-vision order.
    //  Minesweeper is the only enabled card. The other 8 are disabled
    //  placeholders that surface a ComingSoonOverlay on tap (D-03, D-06).
    //
    //  Per D-02: this file owns its own NavigationStack — RootTabView
    //  does not (Anti-Pattern 3 in ARCHITECTURE.md).
    //
    //  Real Minesweeper destination ships at Phase 3 (MINES-02..07);
    //  P1 destination is a token-styled "Coming in P3" placeholder.
    //

    import SwiftUI
    import DesignKit

    struct HomeView: View {
        @EnvironmentObject private var themeManager: ThemeManager
        @Environment(\.colorScheme) private var colorScheme

        @State private var showingComingSoon: GameCard?
        @State private var navigateToMines: Bool = false

        private var theme: Theme { themeManager.theme(using: colorScheme) }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.s) {
                        ForEach(cards) { card in
                            cardRow(card)
                        }
                    }
                    .padding(.vertical, theme.spacing.l)
                    .padding(.horizontal, theme.spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(theme.colors.background.ignoresSafeArea())
                .navigationTitle(String(localized: "GameKit"))
                .navigationDestination(isPresented: $navigateToMines) {
                    minesweeperPlaceholder
                }
                .overlay(alignment: .bottom) {
                    if let card = showingComingSoon {
                        ComingSoonOverlay(
                            title: String(localized: "\(card.title) coming soon"),
                            theme: theme
                        )
                    }
                }
            }
        }

        @ViewBuilder
        private func cardRow(_ card: GameCard) -> some View {
            Button {
                handleTap(card)
            } label: {
                DKCard(theme: theme) {
                    HStack(spacing: theme.spacing.m) {
                        Image(systemName: card.symbol)
                            .font(.title2)
                            .foregroundStyle(card.isEnabled
                                ? theme.colors.accentPrimary
                                : theme.colors.textTertiary)

                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                            Text(card.title)
                                .font(theme.typography.headline)
                                .foregroundStyle(card.isEnabled
                                    ? theme.colors.textPrimary
                                    : theme.colors.textTertiary)
                            if !card.isEnabled {
                                Text(String(localized: "Coming soon"))
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colors.textTertiary)
                            }
                        }
                        Spacer()
                        Image(systemName: card.isEnabled ? "chevron.right" : "lock")
                            .foregroundStyle(theme.colors.textTertiary)
                    }
                    .opacity(card.isEnabled ? 1.0 : 0.6)
                }
            }
            .buttonStyle(.plain)
        }

        private func handleTap(_ card: GameCard) {
            if card.isEnabled {
                navigateToMines = true
            } else {
                showingComingSoon = card
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    if showingComingSoon?.id == card.id {
                        showingComingSoon = nil
                    }
                }
            }
        }

        @ViewBuilder
        private var minesweeperPlaceholder: some View {
            VStack(spacing: theme.spacing.m) {
                Image(systemName: "square.grid.4x3.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(theme.colors.accentPrimary)
                Text(String(localized: "Minesweeper coming in Phase 3"))
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(String(localized: "The board, gestures, and timer arrive next."))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(theme.spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Minesweeper"))
        }
    }

    // MARK: - GameCard model + data

    struct GameCard: Identifiable, Equatable {
        let id: String
        let title: String
        let symbol: String
        let isEnabled: Bool
    }

    private let cards: [GameCard] = [
        GameCard(id: "minesweeper",   title: String(localized: "Minesweeper"),    symbol: "square.grid.4x3.fill", isEnabled: true),
        GameCard(id: "merge",         title: String(localized: "Merge"),          symbol: "square.stack.3d.up",   isEnabled: false),
        GameCard(id: "wordGrid",      title: String(localized: "Word Grid"),      symbol: "textformat.abc",       isEnabled: false),
        GameCard(id: "solitaire",     title: String(localized: "Solitaire"),      symbol: "suit.spade",           isEnabled: false),
        GameCard(id: "sudoku",        title: String(localized: "Sudoku"),         symbol: "9.square",             isEnabled: false),
        GameCard(id: "nonogram",      title: String(localized: "Nonogram"),       symbol: "square.grid.3x3",      isEnabled: false),
        GameCard(id: "flow",          title: String(localized: "Flow"),           symbol: "scribble.variable",    isEnabled: false),
        GameCard(id: "patternMemory", title: String(localized: "Pattern Memory"), symbol: "rectangle.grid.2x2",   isEnabled: false),
        GameCard(id: "chessPuzzles",  title: String(localized: "Chess Puzzles"),  symbol: "checkmark.shield",     isEnabled: false),
    ]
    ```

    Note: the order matches PROJECT.md vision order per CONTEXT line 124: `Merge, Word Grid, Solitaire, Sudoku, Nonogram, Flow, Pattern Memory, Chess puzzles` (with Minesweeper at position 0 as the only enabled card).

    **File 2 — replace `gamekit/gamekit/Screens/RootTabView.swift`** (the Plan 06 stub) with the full 3-tab TabView per D-02:

    ```swift
    //
    //  RootTabView.swift
    //  gamekit
    //
    //  3-tab TabView root per D-02 (TabView with three tabs — Home / Stats /
    //  Settings; each tab owns its own NavigationStack inside its root view).
    //  RootTabView itself is stateless — does not hold a NavigationStack
    //  (ARCHITECTURE.md Anti-Pattern 3).
    //

    import SwiftUI
    import DesignKit

    struct RootTabView: View {
        @EnvironmentObject private var themeManager: ThemeManager
        @Environment(\.colorScheme) private var colorScheme

        @State private var selectedTab: Int = 0

        private var theme: Theme { themeManager.theme(using: colorScheme) }

        var body: some View {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label(String(localized: "Home"), systemImage: "house") }
                    .tag(0)

                StatsView()
                    .tabItem { Label(String(localized: "Stats"), systemImage: "chart.bar") }
                    .tag(1)

                SettingsView()
                    .tabItem { Label(String(localized: "Settings"), systemImage: "gearshape") }
                    .tag(2)
            }
            .tint(theme.colors.accentPrimary)
        }
    }
    ```

    Build:
    ```bash
    xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | tail -50
    ```
    Expected: `BUILD SUCCEEDED`, zero warnings.

    Run the pre-commit hook: `git add gamekit/gamekit/Screens/HomeView.swift gamekit/gamekit/Screens/RootTabView.swift && bash .githooks/pre-commit && echo "HOOK PASSED"`. MUST exit 0.
  </action>
  <verify>
    <automated>xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -c "BUILD SUCCEEDED"</automated>
  </verify>
  <acceptance_criteria>
    - HomeView.swift exists: `test -f gamekit/gamekit/Screens/HomeView.swift` exits 0
    - RootTabView.swift exists and was rewritten: `test -f gamekit/gamekit/Screens/RootTabView.swift` exits 0 AND `grep -c "TabView" gamekit/gamekit/Screens/RootTabView.swift` returns at least `1`
    - HomeView contains a `cards` array literal with exactly 9 GameCard entries: `grep -cE 'GameCard\(id:' gamekit/gamekit/Screens/HomeView.swift` returns exactly `9`
    - All 9 expected card IDs present (Minesweeper + 8 future games in PROJECT.md order): `grep -cE 'id: "(minesweeper|merge|wordGrid|solitaire|sudoku|nonogram|flow|patternMemory|chessPuzzles)"' gamekit/gamekit/Screens/HomeView.swift` returns exactly `9`
    - Exactly ONE card has `isEnabled: true`: `grep -c "isEnabled: true" gamekit/gamekit/Screens/HomeView.swift` returns exactly `1`
    - Exactly EIGHT cards have `isEnabled: false`: `grep -c "isEnabled: false" gamekit/gamekit/Screens/HomeView.swift` returns exactly `8`
    - The enabled card is Minesweeper: line containing `id: "minesweeper"` ends with `isEnabled: true)`: `grep -E 'id: "minesweeper".*isEnabled: true' gamekit/gamekit/Screens/HomeView.swift | wc -l` returns at least `1`
    - HomeView owns its own NavigationStack: `grep -c "NavigationStack" gamekit/gamekit/Screens/HomeView.swift` returns at least `1`
    - HomeView uses ComingSoonOverlay: `grep -c "ComingSoonOverlay" gamekit/gamekit/Screens/HomeView.swift` returns at least `1`
    - HomeView has lock SF Symbol for disabled cards (per D-06): `grep -c '"lock"' gamekit/gamekit/Screens/HomeView.swift` returns at least `1`
    - HomeView opacity reduces for disabled cards (per D-06): `grep -c "opacity(card.isEnabled" gamekit/gamekit/Screens/HomeView.swift` returns exactly `1`
    - RootTabView is 3 tabs, with Home/Stats/Settings tags 0/1/2: `grep -c '.tag(0)' gamekit/gamekit/Screens/RootTabView.swift` = `1` AND `.tag(1)` = `1` AND `.tag(2)` = `1`
    - RootTabView has NO NavigationStack (Anti-Pattern 3): `grep -c "NavigationStack" gamekit/gamekit/Screens/RootTabView.swift` returns exactly `0`
    - RootTabView uses .tint with accentPrimary: `grep -c ".tint(theme.colors.accentPrimary)" gamekit/gamekit/Screens/RootTabView.swift` returns exactly `1`
    - RootTabView uses theme(using:) (NOT theme(for:)): `grep -c "theme(using: colorScheme)" gamekit/gamekit/Screens/RootTabView.swift` returns exactly `1` AND `grep -c "theme(for:" gamekit/gamekit/Screens/RootTabView.swift` returns `0`
    - All tab labels use String(localized:): `grep -c 'Label(String(localized:' gamekit/gamekit/Screens/RootTabView.swift` returns exactly `3`
    - HomeView file size cap: `[ $(wc -l < gamekit/gamekit/Screens/HomeView.swift) -le 250 ]` exits 0
    - RootTabView file size cap: `[ $(wc -l < gamekit/gamekit/Screens/RootTabView.swift) -le 80 ]` exits 0
    - No hardcoded Color literals: `grep -cE 'Color\(\s*(red:|hex:|white:)|Color\.(red|blue|green|gray|orange|yellow|pink|purple|black|white)' gamekit/gamekit/Screens/HomeView.swift gamekit/gamekit/Screens/RootTabView.swift` returns exactly `0`
    - No numeric cornerRadius: `grep -cE 'cornerRadius:\s*[0-9]+' gamekit/gamekit/Screens/HomeView.swift gamekit/gamekit/Screens/RootTabView.swift` returns exactly `0`
    - No numeric padding integers: `grep -cE '\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)' gamekit/gamekit/Screens/HomeView.swift gamekit/gamekit/Screens/RootTabView.swift` returns exactly `0`
    - `.foregroundStyle` used (not `.foregroundColor`): `grep -c "foregroundColor" gamekit/gamekit/Screens/HomeView.swift gamekit/gamekit/Screens/RootTabView.swift` returns exactly `0`
    - Build succeeds: `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -c "BUILD SUCCEEDED"` returns at least `1`
    - Build emits zero warnings: `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -cE "warning:"` returns exactly `0`
    - Pre-commit hook passes: `git add gamekit/gamekit/Screens/HomeView.swift gamekit/gamekit/Screens/RootTabView.swift && bash .githooks/pre-commit` exits 0
    - No Finder dupes: `find gamekit -name "* 2.swift"` returns no results
  </acceptance_criteria>
  <done>HomeView complete with 9 cards (1 enabled / 8 disabled in vision order), RootTabView is the 3-tab root, build green, hook passes, all token-discipline checks pass.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3: User verifies the home screen renders + theme switch produces no bleedthrough</name>
  <what-built>Tasks 1 + 2 created the full P1 shell. Project builds with zero warnings under Swift 6 strict concurrency. The TabView roots Home / Stats / Settings; HomeView shows Minesweeper + 8 disabled placeholders with lock badges; tapping a disabled card surfaces a "coming soon" toast; tapping Minesweeper navigates to a token-styled "Coming in P3" placeholder.</what-built>
  <how-to-verify>
    1. **Boot the simulator and install the app:**
       ```bash
       xcrun simctl list devices | grep -E "iPhone (15|16) Pro" | head -1
       # pick a device id from the output (UUID-like string in parentheses)
       xcrun simctl boot <device-id>  # or skip if Booted
       open -a Simulator
       xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "id=<device-id>" -configuration Debug build install 2>&1 | tail -10
       xcrun simctl launch <device-id> com.lauterstar.gamekit
       ```

    2. **Visual checks on the simulator (Home tab default):**
       - The Home tab is selected. You see 9 cards stacked vertically: Minesweeper at the top (full opacity, chevron icon), then Merge / Word Grid / Solitaire / Sudoku / Nonogram / Flow / Pattern Memory / Chess Puzzles (each at 60% opacity, lock icon).
       - The tab bar at the bottom has 3 items: Home (house), Stats (chart.bar), Settings (gearshape).
       - Title bar reads "GameKit".

    3. **Tap a disabled card** (e.g. "Solitaire").
       - A floating capsule appears at the bottom of the screen with a sparkles icon and the text "Solitaire coming soon".
       - The capsule auto-dismisses after ~1.8 seconds.

    4. **Tap the enabled Minesweeper card.**
       - You navigate (push) inside the Home tab's NavigationStack to a placeholder screen titled "Minesweeper" with a large grid icon and the text "Minesweeper coming in Phase 3" / "The board, gestures, and timer arrive next."
       - The back chevron returns to Home.

    5. **Switch tabs.**
       - Stats tab: navigation title "Stats", section headers "HISTORY" + "BEST TIMES", each followed by a `DKCard` with placeholder copy ("Your stats / best times will appear here.").
       - Settings tab: navigation title "Settings", section headers "APPEARANCE" + "ABOUT", `DKCard`s with "Theme controls coming…" and "GameKit · v1.0".

    6. **Theme legibility test (the load-bearing one for FOUND-03 / SHELL-01).** This requires temporarily overriding the default preset since P1 has no Settings UI for it. Easiest path:
       - Open `gamekit/gamekit/App/GameKitApp.swift` in Xcode.
       - Add a single line just inside `init()` (or directly after `@StateObject private var themeManager = ThemeManager()` — note ThemeManager has no `init()` parameter for preset, but you can post-mutate after init using `.onAppear`):
         ```swift
         .onAppear { themeManager.preset = .voltage }   // or another Loud preset
         ```
         applied to `RootTabView()` in the body. (This is a temporary local edit for verification — DO NOT COMMIT IT.)
       - Re-run the app.
       - Walk through Home / Stats / Settings tabs.
       - **Pass criterion:** every screen still renders cleanly. No black-on-black text, no invisible borders, no white squares hardcoded into a saturated background. Numbers / icons / cards all visible. Lock icons on disabled cards visible. Coming-soon overlay still readable.
       - Switch to a Soft preset (e.g. `.cream` or `.paper` if those exist in DesignKit's `ThemePreset` enum — check `../DesignKit/Sources/DesignKit/Theme/ThemePreset.swift`). Re-walk Home + Settings + Stats. Same pass criterion.
       - Switch back to Classic (the default preset, whatever it is — try `themeManager.preset = .stone` or the first case of `ThemePreset.allCases`).
       - **Revert the temporary `.onAppear` edit before resuming.** No theme override should ship in the commit.

    7. **Confirm pre-commit hook passes on the staged set:**
       ```bash
       git add gamekit/gamekit/Screens/{SettingsComponents,ComingSoonOverlay,SettingsView,StatsView,HomeView,RootTabView}.swift
       bash .githooks/pre-commit && echo "HOOK PASSED"
       ```
       Expected: exit 0.

    **Resume signals:**
    - **"approved"** — every step above passed; no theme bleedthrough; no token violations; ready to commit.
    - **"issue: <description>"** — describe the problem (e.g. "lock icon invisible on Voltage preset", "coming-soon overlay text unreadable on Cream", "tapping Mines crashed"). The orchestrator will spawn a revision.
  </how-to-verify>
  <resume-signal>Type "approved" or "issue: <description>"</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user touch input ↔ HomeView state | User taps surface as Button actions; only state mutated is `showingComingSoon` (a transient overlay) and `navigateToMines` (a navigation flag). Both are local view-state, not persisted. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-13 | DoS | HomeView coming-soon overlay | accept | Spamming taps on a disabled card creates many `Task { sleep 1.8s }` blocks but each one early-exits if the displayed card has changed. Worst case: a brief overlay flicker. No crash, no resource exhaustion (Swift Tasks GC trivially). |
| T-01-14 | Tampering | UserDefaults (theme prefs read by ThemeManager) | accept | Same disposition as Plan 06 T-01-11 — theme prefs are non-sensitive cosmetic state. |

**N/A categories:** Spoofing, Repudiation, Information Disclosure, Elevation of Privilege — purely local rendering with no network, no auth, no user data persisted by P1's surface.
</threat_model>

<verification>
After all 3 tasks:
- `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` exits 0; zero warnings.
- All 6 Swift files exist under `gamekit/gamekit/Screens/`: `RootTabView.swift`, `HomeView.swift`, `SettingsView.swift`, `StatsView.swift`, `ComingSoonOverlay.swift`, `SettingsComponents.swift`.
- `find gamekit/gamekit -name "* 2.swift"` returns no results.
- Visual checkpoint passed: app renders Home with 9 cards, theme switches produce no bleedthrough on at least one Loud and one Soft preset.
</verification>

<success_criteria>
- All tasks' acceptance criteria pass.
- App is navigable: tabs work, disabled cards surface coming-soon overlay, Minesweeper card pushes to a placeholder.
- Theme tokens are the only styling source — no `Color(...)` literals, no numeric radii or spacing.
- File-size caps respected: every file ≤ 250 lines (well under §8.1's 400-line view cap).
- Pre-commit hook accepts the entire commit set.
- User-confirmed via checkpoint that theme switching produces no visual regression.
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-07-SUMMARY.md` per the template, including which presets were tested in Task 3 and the result.
</output>
