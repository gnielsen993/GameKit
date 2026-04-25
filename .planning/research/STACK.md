# Stack Research — GameKit

**Domain:** iOS classic logic-games suite (MVP = Minesweeper), local-first, optional CloudKit sync, polished SwiftUI UI on top of a shared DesignKit Swift Package.
**Researched:** 2026-04-24
**Overall confidence:** HIGH on framework choices, MEDIUM on a handful of nuanced 2026-current details (called out inline).

---

## TL;DR Decision Wall

| Concern | Decision | Confidence |
|---|---|---|
| UI | SwiftUI (iOS 17+ baseline, opt-in iOS 18/26 niceties behind `if #available`) | HIGH |
| Concurrency | Swift 6, strict concurrency ON, MVVM lightweight, `@MainActor` on view models, engines = pure value types | HIGH |
| Persistence | SwiftData with `ModelConfiguration(cloudKitDatabase: .automatic)`, single `private` DB | HIGH |
| Sync | SwiftData's built-in CloudKit mirror (NOT `CKSyncEngine`), private DB only | HIGH |
| Auth | Sign in with Apple via `SignInWithAppleButton` (SwiftUI), credential state polled on launch + `ASAuthorizationAppleIDProviderCredentialRevoked` notification | HIGH |
| Grid view | `LazyVGrid` (or non-lazy `Grid` for Easy/Medium) — NOT Canvas | HIGH |
| Reveal cascade | Per-cell `withAnimation` + `.transition` driven by ViewModel state mutation, optionally staggered with `Task.sleep`. Use `phaseAnimator`/`keyframeAnimator` only for the win-board sweep & loss-shake | HIGH |
| Haptics | SwiftUI `.sensoryFeedback` modifier as the primary; CoreHaptics only for the win/loss custom pattern. DesignKit wraps both behind `DKHaptics`. | HIGH |
| SFX | `AVAudioPlayer` instances **preloaded at app launch with `prepareToPlay()`**, one per cue. NOT `AudioServicesPlaySystemSound`. | MEDIUM-HIGH |
| Localization | `String(localized:)` + `Localizable.xcstrings`, "Use Compiler to Extract Swift Strings" build setting ON | HIGH |
| Cold start | Static LaunchScreen + lazy `ModelContainer`, view-tree depth ≤ 4, no SwiftData fetches before first render | HIGH |
| Tests | Swift Testing (`@Test` / `#expect`), XCTest only if a UI test or perf measurement specifically needs it | HIGH |

---

## Recommended Stack

### Core Frameworks

| Framework | Version | Purpose | Why |
|---|---|---|---|
| Swift | **6.0+** (6.2 if available in Xcode 16.x; 6.3 in Xcode 26) | Language | Strict concurrency is non-negotiable for an MVVM/SwiftData/CloudKit boundary that must not data-race. |
| SwiftUI | iOS 17 baseline | UI | Already the app's North Star; `phaseAnimator`/`keyframeAnimator`/`sensoryFeedback` ship in 17. iOS 17 is also DesignKit's floor. |
| SwiftData | iOS 17 (use 17.4+ patterns) | Persistence + CloudKit mirror | Apple-native, pairs naturally with CloudKit, sized for richer stats without re-architecting. |
| CloudKit | private DB only | Sync | Apple-native, free for users, zero third-party backend, preserves "no servers we don't own". |
| AuthenticationServices | iOS 17 | Sign in with Apple | Required for SIWA. `SignInWithAppleButton` is a first-party SwiftUI control. |
| CoreHaptics + UIKit feedback (via SwiftUI `sensoryFeedback`) | iOS 17 | Tactile feedback | `sensoryFeedback` covers 90% of needs; CoreHaptics for 1-2 custom win/loss patterns. |
| AVFoundation (`AVAudioPlayer`) | iOS 17 | SFX | Tap/win/loss cues. Preload at launch to dodge first-play latency. |
| Swift Testing | bundled with Xcode 16+ | Engine tests | Modern, parallel, parameterized — built for pure deterministic engines. |
| XCTest | as-needed | UI / perf tests | Keep available for `XCUIApplication` + `measure` blocks if/when needed. |

### Supporting Libraries

**None.** GameKit MVP ships with zero third-party dependencies beyond DesignKit (local SPM at `../DesignKit`). This is enforced by the project constitution and the privacy posture.

If/when a need arises post-MVP, the bar to add a dependency is: "is this in Apple's stdlib? if no, do at least two ecosystem siblings need it? if yes, promote into DesignKit, not a vendor pull."

### DesignKit Consumption

| Aspect | Pattern |
|---|---|
| Distribution | Local SPM dependency at `../DesignKit`, NOT git URL, NOT vendored. |
| Swift tools version | DesignKit ships 6.0; GameKit must match. |
| Tokens used | `theme.colors.*`, `theme.spacing.*`, `theme.radii.*`, `theme.motion.{fast,normal,slow}`, `theme.typography.*` |
| Components consumed | `DKCard`, `DKButton`, `DKThemePicker`, `DKBadge`, `DKSectionHeader` |
| New abstractions to add to DesignKit | `DKHaptics` (SensoryFeedback wrapper + CoreHaptics fallback), `DKSFXPlayer` (only if a 2nd ecosystem app needs SFX — until then, keep local) |

### Development Tools

| Tool | Purpose | Notes |
|---|---|---|
| Xcode 16+ (16.4+ ideal; 26 if available) | Build, String Catalog editor, Swift Testing UI | Set "Use Compiler to Extract Swift Strings" = YES on the app target. |
| `xcodebuild test -scheme GameKit -destination ...` | CI-able test harness | Swift Testing tests run via the same `xcodebuild test` invocation. |
| `xcrun simctl uninstall ...` | Stale SwiftData store recovery | See CLAUDE.md §8.9 — known recurring trap with schema migrations. |

---

## 1) Swift 6 Strict-Concurrency Posture

Swift 6's enforced data-race safety is the most disruptive ground rule. Get it right once at the start so SwiftData and CloudKit don't fight you later.

### Rules of thumb (apply consistently)

1. **`@MainActor` on every view model.** ViewModels read SwiftData via `@MainActor`-pinned `ModelContext` (the one off `modelContainer.mainContext`). All `@Observable`/`ObservableObject` view models become `@Observable @MainActor`.
   - **Trap:** `@Observable` does NOT imply `@MainActor`. Mark explicitly. ([Hacking With Swift][hws-swiftdata-concurrency])
2. **Engines are pure value types, no actor at all.** `BoardGenerator`, `RevealEngine`, `WinDetector`, `MineLayout` — all `struct`s with `Sendable` conformance, deterministic given inputs (RNG injected). They never touch `ModelContext`, never import `SwiftUI`. This is consistent with the project's existing engine-purity rule.
3. **`ModelContainer` is `Sendable`. `ModelContext` is NOT. `PersistentIdentifier` IS.** ([Hacking With Swift][hws-swiftdata-concurrency])
   - Pass `ModelContainer` across boundaries. Pass `PersistentIdentifier` to background work. Re-fetch the model on the destination actor.
4. **Use `ModelActor` only when you actually need background writes.** For Minesweeper MVP, **you don't.** Stats are tiny (one row per game completion). Writes happen on `@MainActor` after a game ends. Skip the ModelActor complexity.
   - If you later add JSON export of long stats history, that's a candidate for a `@ModelActor` background actor. Until then, every line of ModelActor code is overhead. ([Massicotte][massicotte-modelactor])
5. **No `@unchecked Sendable` on engines.** Use proper value semantics. If you're tempted to write `@unchecked Sendable`, the engine isn't pure — fix that instead.
6. **`@Sendable` closures only where the compiler asks.** Don't sprinkle. SwiftData closures (`Query`, `predicate`) are inherently main-actor in normal use.

### `@MainActor` placement table for GameKit

| Type | Isolation |
|---|---|
| `GameKitApp` (App) | implicit `@MainActor` |
| `MinesweeperViewModel` | `@Observable @MainActor` |
| `SettingsStore`, `ThemeStore`, `GameStatsStore` | `@MainActor` (UI-bound) |
| `BoardGenerator`, `RevealEngine`, `WinDetector` | none — pure `Sendable` value types |
| `Cell`, `Board`, `Difficulty`, `GameOutcome` | none — `Sendable` value types (`struct`/`enum`) |
| `MinesweeperStat` (`@Model`) | implicit `@MainActor` when accessed via `mainContext` |
| `SignInCoordinator` | `@MainActor` (presents UI, holds `ASAuthorizationController`) |
| `CloudKitAccountObserver` | `@MainActor` (observes `NSNotification.Name.CKAccountChanged`) |

### Common `@Sendable` traps in this stack

- **Trap A: closure captures `self` in a `Task` from a non-MainActor context.** If a callback handler isn't already `@MainActor`, wrap with `await MainActor.run { ... }` or annotate the handler.
- **Trap B: SwiftData model passed to a `Task.detached`.** Models are not `Sendable`. Pass `PersistentIdentifier`, re-fetch.
- **Trap C: closure into `withAnimation { ... }` capturing a non-Sendable.** Usually harmless (UI is main-actor) but Swift 6 strict mode can complain. Hoist locals first.
- **Trap D: `ASAuthorizationController` delegate methods are not annotated.** Wrap delegate work with `MainActor.assumeIsolated { ... }` or annotate the conforming class `@MainActor`.

**Confidence:** HIGH on the placement rules; MEDIUM on Trap D (depends on Xcode version's import annotations — verify after you wire it up).

[hws-swiftdata-concurrency]: https://www.hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency
[massicotte-modelactor]: https://www.massicotte.org/model-actor/

---

## 2) SwiftData ↔ CloudKit Private-DB Integration

### The configuration (one container, one configuration)

```swift
import SwiftData

@MainActor
enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            MinesweeperStat.self,
            UserProfile.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic   // reads container ID from entitlements
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }()
}
```

### Hard constraints (these WILL bite you — verified 2025/2026)

CloudKit-mirrored SwiftData has constraints that are NOT optional and have NOT relaxed in iOS 17/18/26: ([Hacking With Swift][hws-icloud-sync], [Apple Forum 731334][apple-forum-731334])

1. **No unique constraints.** `#Unique<T>(...)` and `@Attribute(.unique)` are forbidden on any model that syncs. Compiles fine, crashes at sync. Use a `UUID` `id` field and treat uniqueness as application-level.
2. **All relationships must be optional.** A required `var profile: UserProfile` will crash at container init. Make it `var profile: UserProfile?` even if you "know" it's always set. Default empty arrays for to-many: `var stats: [MinesweeperStat]? = []`.
3. **All non-relationship attributes must be optional OR have a default.** `var difficulty: Difficulty` → either `var difficulty: Difficulty = .easy` or `var difficulty: Difficulty?`.
4. **Codable enums are fine, but provide a default.** `Difficulty.easy` as default works.
5. **No `@Attribute(.transformable)` with custom transformers** — stick to types CloudKit understands (primitives, `Data`, `Date`, `URL`, simple Codable enums).
6. **Schema migrations + CloudKit don't always coexist gracefully.** `iOS 17.4` broke a `.none` workaround for custom migrations. (See [Apple Forum 756538][apple-forum-756538].) Plan additive migrations only; if you need destructive, do it via Export/Import JSON instead of `VersionedSchema`.

### Required entitlements (Signing & Capabilities → +Capability)

- **iCloud** → check **CloudKit** → add a container `iCloud.com.lauterstar.gamekit`
- **Background Modes** → check **Remote notifications** (so silent push wakes the sync)
- **Push Notifications** capability (CloudKit subscriptions need it — Apple adds this automatically when you check Remote notifications + CloudKit)
- **Sign in with Apple** capability (separate, see §3)

### Public/shared DB?

**Out of scope.** The project rules say private DB only. `ModelConfiguration` currently can't directly target a public/shared CloudKit database scope anyway — it's `.private` by default with no scope option exposed. ([Hacking With Swift][hws-stop-sync]) If multiplayer ever happens (it won't per PROJECT.md), that's a `CKSyncEngine` rewrite, not a SwiftData add-on.

### Should we use `CKSyncEngine` instead?

**No.** `CKSyncEngine` (iOS 17+) is the right call when you need:
- Public/shared databases
- Manual conflict resolution
- Custom record formats
- Fine-grained sync timing

GameKit needs none of these. SwiftData's automatic mirror is strictly less code, fewer edge cases, and can't easily coexist with `CKSyncEngine` on the same container anyway. ([Apple Forum 731435][apple-forum-731435])

**Confidence:** HIGH on the constraints (multiply confirmed by Apple forum threads, Hacking With Swift, and Mike Tsai's WWDC25 roundup), HIGH on the recommendation to use the built-in mirror.

[hws-icloud-sync]: https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit
[apple-forum-731334]: https://developer.apple.com/forums/thread/731334
[apple-forum-731435]: https://developer.apple.com/forums/thread/731435
[apple-forum-756538]: https://developer.apple.com/forums/thread/756538
[hws-stop-sync]: https://www.hackingwithswift.com/quick-start/swiftdata/how-to-stop-swiftdata-syncing-with-cloudkit

---

## 3) Sign in with Apple (iOS 17+)

### The button

Use SwiftUI's first-party `SignInWithAppleButton` from `AuthenticationServices`. It's themable to match DesignKit reasonably well via `.signInWithAppleButtonStyle(.black | .white | .whiteOutline)`. Pick once based on `colorScheme`.

```swift
import AuthenticationServices

SignInWithAppleButton(.signIn) { request in
    request.requestedScopes = []   // GameKit needs no name/email
} onCompletion: { result in
    Task { @MainActor in
        await coordinator.handle(result)
    }
}
.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
.frame(height: 48)
.clipShape(RoundedRectangle(cornerRadius: theme.radii.button))
```

**Note:** GameKit only needs the *user identifier* (a stable Apple-issued `userID` string). It does NOT request name or email. Smaller scope = less consent friction = closer to the "no popups, no nags" posture in CLAUDE.md.

### Credential lifecycle

The Apple ID credential can be revoked from Settings → Apple ID → Sign In with Apple. Your app must handle this on every cold start AND while running:

1. **On launch (and on `scenePhase == .active`):** call `ASAuthorizationAppleIDProvider().getCredentialState(forUserID:)`.
   - `.authorized` → keep CloudKit-synced UI on
   - `.revoked` or `.notFound` → fall back to anonymous/local mode, do NOT delete local data
   - `.transferred` → re-prompt sign-in
2. **At runtime:** observe `ASAuthorizationAppleIDProvider.credentialRevokedNotification` (the `Notification.Name` is `ASAuthorizationAppleIDProviderCredentialRevoked`). On fire: tear down the CloudKit-aware container or hard-flip a flag the UI reads. ([Apple Docs][apple-aid-revoked])

### "There is no credential refresh"

Don't go looking for a token refresh API on iOS — there isn't one. The identity token returned in the authorization is short-lived and one-shot. The persistent thing is the **user identifier**, which you store in `Keychain` under your app's bundle. CloudKit handles all "is the user signed in" semantics independently — `iCloud` account presence and `SIWA` are orthogonal. The user can be signed into iCloud without ever having tapped your SIWA button, and vice versa.

### Anonymous → signed-in promotion (the actual UX)

This is the bit most apps get wrong. The pattern that works with SwiftData+CloudKit:

1. **First launch:** App creates a `UserProfile(id: UUID(), appleUserID: nil, ...)`. Stats write to the `mainContext`. SwiftData's CloudKit container is **off** — config built with `cloudKitDatabase: .none`.
   - **Trap:** if you ship `.automatic` from day 1 and the user is already iCloud-signed-in (which they probably are), SwiftData starts mirroring to their private DB whether they tapped SIWA or not. That's not what we promise. Decide which posture you want; if "no network until SIWA tap", ship with `.none` and switch on sign-in.
2. **User taps SIWA in intro/Settings:** Save `appleUserID` to Keychain. Tear down the existing `ModelContainer`. Re-create it with `cloudKitDatabase: .automatic`. SwiftData walks the local SQLite store and pushes existing rows up — **no data loss**, this is its native behavior.
3. **Subsequent launches:** Read Keychain → if `appleUserID` present and credential state `.authorized`, build container with `.automatic`. Otherwise `.none`.
4. **User revokes on a different device:** `credentialRevokedNotification` fires. Container teardown + rebuild with `.none`. Local rows stay. CloudKit rows on the server stay (don't delete them — re-sign-in restores them).

**Critical caveat / honest hedge:** Container teardown + recreate with a different config inside a running app is supported but has historically been touchy. If issues appear in testing, the alternative is "decide at launch only, require app restart for the toggle to take effect." Not graceful, but bulletproof. **Confidence on hot-swap: MEDIUM. Confidence on launch-only swap: HIGH.**

[apple-aid-revoked]: https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidprovider/credentialstate/revoked

---

## 4) Animation Tools — picking the right one for the right effect

The MVP needs four named effects: **reveal cascade**, **flag spring**, **win-board sweep**, **loss-shake**. None of these need Canvas. Mines is a 16×30 grid of views — modest by SwiftUI standards.

### Decision matrix

| Effect | Tool | Why |
|---|---|---|
| Reveal cascade (flood-fill expansion) | Per-cell `withAnimation(theme.motion.fast)` triggered by ViewModel mutating each cell's `isRevealed` in BFS order, with `try await Task.sleep(for: .milliseconds(8))` between rings | The cascade IS the BFS; let it animate naturally. No special API needed. `matchedGeometryEffect` is overkill — cells aren't moving, just transitioning state. |
| Flag spring (long-press to toggle flag) | `.symbolEffect(.bounce, value: cell.isFlagged)` (iOS 17) on the SF Symbol, or a `withAnimation(.spring(response: 0.3, dampingFraction: 0.6))` on a scale modifier | One-shot springy toggle. Built into SwiftUI iOS 17. |
| Win-board sweep (full board lights up) | `phaseAnimator` with `[.dim, .glow, .settled]` phases driving brightness/saturation across cells | This IS what `phaseAnimator` is for: a fixed multi-step sequence. |
| Loss-shake (board jiggles + revealed mine flashes) | `keyframeAnimator` for the precise shake (-8, +6, -4, +2, 0 over ~250ms), combined with a `.foregroundStyle(theme.colors.danger)` flash on the mine | `keyframeAnimator` (iOS 17) gives you exact control over timing curves, which `.spring` can't quite hit for a shake. ([Apple Docs][apple-keyframe]) |

### When to reach for each tool

| API | Use when | Don't use when |
|---|---|---|
| `withAnimation` + `.transition` | Standard state-driven changes (reveal, flag, score updates) | You need keyframe-precise timing |
| `matchedGeometryEffect` | A view appears to fly between two parents (none of GameKit's effects need this) | Just changing a state on one stationary view |
| `phaseAnimator(_:trigger:)` (iOS 17) | A sequence of 2-N visual states triggered once (win sweep, score-up bounce) | Continuous looping animation; the recurring trigger pattern is awkward |
| `keyframeAnimator` (iOS 17) | Precise multi-keyframe motion (shake, custom bounce, choreographed sequence) | Anything a `.spring` already nails |
| `Canvas` | High cardinality (>1000 elements) or per-frame redraw needs (particles, generative art) | A 16×30 grid of cells. **Massive overkill** and you lose accessibility per-cell. |
| `TimelineView` | UI that updates against a clock independently of state (a smooth running timer) | Anything triggered by user action |
| `drawingGroup()` | Composited heavy effects (blur+shadow+gradient on many views) | Default text/symbol cells |

### Specific call: should the 480-cell Hard board use `Canvas`?

**No.** `LazyVGrid` (or `Grid`) with one view per cell is correct for GameKit because:

- Each cell needs a tappable, accessible, VoiceOver-labeled `View`. Canvas doesn't expose hit-testing or accessibility per-shape.
- 480 simple cells is well within SwiftUI's diffing budget. Use `Equatable`-conforming cell views and `.id(cell.id)` to avoid spurious redraws.
- Canvas wins are GPU-side rendering for 1000s of shapes or arbitrary-frame compositing — neither applies.
- `LazyVGrid` wraps the whole board in a single grid view; on iPhone, the full Hard board fits on-screen (no scrolling required) so "lazy" is fine and not even strictly necessary; either `Grid` or `LazyVGrid` is correct. Pick `LazyVGrid` for consistency with iPad rotated states where the board could exceed viewport.

If perf becomes a problem at the polish phase (it almost certainly won't), the escalation order is: `.equatable()` cell views → `drawingGroup()` on the board container → `Canvas` (last resort, last resort, last resort).

### Reduce Motion respect

Wrap the polish into a `MotionPalette` helper that reads `@Environment(\.accessibilityReduceMotion)` and returns dampened `Animation` values. PROJECT.md A11Y-03 makes this required, not nice-to-have.

[apple-keyframe]: https://developer.apple.com/documentation/swiftui/controlling-the-timing-and-movements-of-your-animations

---

## 5) Haptics — what `DKHaptics` should wrap

### The 2026 picture

There are now **three** haptic surfaces on iOS, and they are NOT redundant:

| Surface | Best for | Notes |
|---|---|---|
| `UIImpactFeedbackGenerator` / `UISelectionFeedbackGenerator` / `UINotificationFeedbackGenerator` | Standard simple cues | Pre-iOS-17 way; still works; needs `.prepare()` to avoid first-fire latency. |
| **SwiftUI `.sensoryFeedback(_:trigger:)`** (iOS 17+) | The 90% case in modern SwiftUI | Trigger-driven, declarative, no `prepare()` lifecycle to manage. Has `.success / .warning / .error / .selection / .impact(...) / .increase / .decrease / .start / .stop / .alignment / .levelChange` ([Use Your Loaf][useyourloaf-sensory]) |
| **CoreHaptics** (`CHHapticEngine`) | Custom multi-event patterns synced with audio (a custom "win" arpeggio of taps) | Manual lifecycle. Worth it for 1-2 marquee moments only. |

### Recommendation for GameKit's `DKHaptics`

```swift
public enum DKHapticCue {
    case tap            // cell tap (.selection)
    case flag           // long-press flag (.impact(.light))
    case unflag         // (.selection)
    case reveal         // (.impact(.medium))
    case win            // CoreHaptics custom 3-event arpeggio
    case loss           // (.warning) + a short CoreHaptics rumble
}
```

Implementation strategy:

- **Light/medium/selection cues:** wrap as a SwiftUI modifier `.dkHaptic(cue, trigger: state)` that internally calls `.sensoryFeedback(...)`. This is the path of least resistance and Apple-recommended for iOS 17+.
- **Win and loss only:** instantiate a single shared `CHHapticEngine` (lazy, on-demand, started just before play) and load 2 pre-built `CHHapticPattern` JSON files (`Win.ahap`, `Loss.ahap`). `.ahap` files are authored once and tweaked by ear.
- **Settings toggle:** the wrapper consults `SettingsStore.hapticsEnabled` and is a no-op if off. PROJECT.md MINES-09 makes this required.
- **Reduce motion / Reduce haptics?** iOS doesn't expose a "reduce haptics" environment. The user's Settings app has it, and `UIDevice` doesn't surface it. Just respect the in-app Haptics toggle.

### Promotion to DesignKit

Per CLAUDE.md §2 ("game-specific haptics patterns *unless* the same pattern is reused in 2+ games — only then promote"), `DKHaptics` graduates to DesignKit only when a second game (Merge, Sudoku) needs the same `.win/.loss/.reveal` vocabulary. Until then, keep at `Games/Minesweeper/Haptics.swift` — but write it with the abstraction shape it'll have when promoted, so the move is mechanical.

**Confidence:** HIGH on the SwiftUI-modifier-first approach; HIGH on CoreHaptics for custom patterns; MEDIUM on the exact AHAP file contents (those are tuned by ear, not by docs).

[useyourloaf-sensory]: https://useyourloaf.com/blog/swiftui-sensory-feedback/

---

## 6) Sound Effects — `AVAudioPlayer` (preloaded), not `SystemSoundID`

Three short cues: tap, win, loss. Off by default (PROJECT.md MINES-10). Calm, premium-feeling, not arcade-y.

### Why `AVAudioPlayer` wins for this case

| Criterion | `AVAudioPlayer` | `AudioServicesPlaySystemSound` (SystemSoundID) | OpenAL / AVAudioEngine |
|---|---|---|---|
| File length supported | Any | ≤ 30s | Any |
| Format flexibility | WAV/M4A/MP3/AAC/CAF | CAF only practical | Any |
| Volume control | Yes | No (system volume only) | Yes |
| Play same cue overlapping | Need multiple instances | No | Yes (mixing engine) |
| Setup complexity | Low | Lowest | High |
| First-play latency | High by default; fixed by `prepareToPlay()` | Lowest | Low |
| Right for games with chord/many overlapping cues | Marginal | No | Yes |

GameKit needs **3 short cues, off by default, never overlapping** (no rapid-fire chord clicks in MVP per PROJECT.md Out-of-Scope). `AVAudioPlayer` with preloading is the simplest correct choice. ([Apple Forum 98401][apple-forum-98401])

### Implementation pattern

```swift
@MainActor
final class SFXPlayer {
    private var players: [SFX: AVAudioPlayer] = [:]

    init() {
        for cue in SFX.allCases {
            guard let url = Bundle.main.url(forResource: cue.fileName, withExtension: "m4a"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()           // critical — primes buffers
            player.volume = cue.defaultVolume
            players[cue] = player
        }
    }

    func play(_ cue: SFX) {
        guard SettingsStore.shared.sfxEnabled else { return }
        let player = players[cue]
        player?.currentTime = 0
        player?.play()
    }
}
```

### Asset notes

- **Format:** ship `.m4a` (AAC). Smaller than WAV, fast to decode after `prepareToPlay()`.
- **Length:** all cues ≤ 1.5s. Tap = ~80ms, win = ~1.2s, loss = ~700ms.
- **Volume:** ship at 0.6 default; gives headroom and feels calmer.
- **`AVAudioSession` category:** set to `.ambient` (NOT `.playback`) so the user's music isn't ducked. PROJECT.md's calm posture demands this.
- **Don't lazy-load.** First-play latency without `prepareToPlay()` runs hundreds of ms on iOS — feels broken.

**What about `.systemSoundID` for the tap?** Tempting because it's one line. But you give up volume control, and you're at the mercy of the user's ringer settings — system sounds inherit ringer/silent state. A "subtle SFX" that goes silent because the user has ringer-off is broken behavior. Reject.

**Confidence:** MEDIUM-HIGH. The concrete recommendation is solid; the perfect cue assets need iteration during the polish phase.

[apple-forum-98401]: https://developer.apple.com/forums/thread/98401

---

## 7) String Catalogs (`.xcstrings`) — EN-only ship, translation-ready

### The setup (do this once)

1. Add a `Localizable.xcstrings` file (File → New → File → String Catalog) to the app target.
2. **Project Settings → Localizations:** keep only English at v1. Adding new languages later is a 2-click operation that backfills the catalog.
3. **Build Settings → Localization → "Use Compiler to Extract Swift Strings" = YES.** This is the workflow's keystone — every build scans Swift sources and merges discovered strings into the catalog. ([SimpleLocalize][simplelocalize-xcstrings])
4. **App target Info → Localization Native Development Region:** `en`.

### The discipline (apply consistently)

- Every user-facing string uses `String(localized: "key")` or the SwiftUI `Text("key")` initializer (which is implicitly localized when the file exists).
- Use **descriptive keys** that double as the EN value: `Text("Mines remaining")` not `Text("mines_label_2")`. Catalogs key by the English source.
- **Always pass a comment** for any non-obvious key. The catalog stores it and translators rely on it: `String(localized: "Best", comment: "Best time label on stats screen")`.
- **Pluralization:** use `String(localized: "^[\(n) mines](inflect: true)")` syntax (Foundation pluralization) for "1 mine" / "2 mines" — handled in-catalog.
- **Don't concatenate localized fragments.** Always full sentences with `\(...)` interpolations. Translators need full context.
- **Avoid `LocalizedStringKey` as a function parameter type** if the parameter could be passed a runtime string — Xcode's extractor won't pick it up. Use `String` + explicit `String(localized:)` at the call site.

### CI sanity

In Xcode's String Catalog editor, statuses to watch:
- **Stale** = source code no longer references this key → either delete or restore reference.
- **Needs Review** (amber) = autogenerated/auto-imported, needs human eyes.
- **Untranslated** = no value in non-EN locales — fine while we're EN-only.

A pre-TestFlight check: open `Localizable.xcstrings`, filter by "Stale", clean. (No CI tooling needed for this small a catalog.)

### Plurals that GameKit will hit

`"%d mines"`, `"%d games played"`, `"%d wins"`, `"%d flags placed"`. Handle all four with the catalog's plural variants from day 1.

**Confidence:** HIGH. String Catalogs are mature in Xcode 16/26; the workflow above is the documented happy path.

[simplelocalize-xcstrings]: https://simplelocalize.io/blog/posts/xcstrings-string-catalog-guide/

---

## 8) Cold-Start Performance Budget (<1s on a recent device)

PROJECT.md FOUND-01 makes this a P0 bug. The budget is brutal but doable for an app with no third-party SDKs.

### The five tactics (do all)

1. **Static `LaunchScreen.storyboard`** that visually matches the Home screen background — DesignKit's `theme.colors.background` for the default Classic Forest preset. No code, no logic. Apple recommends static. ([SwiftLee][swiftlee-launch])
2. **Lazy `ModelContainer`.** Build it inside an `enum AppModelContainer { static let shared = ... }` so it's lazy and built only on first reference — not in `App.init()`.
3. **Don't fetch on first frame.** The Home screen lists Minesweeper as the only active game (PROJECT.md SHELL-01). It does NOT need to read SwiftData synchronously to render. Defer any `@Query` to detail screens (Stats).
4. **Hoist `ThemeManager` only.** It's tiny, reads UserDefaults synchronously, and is needed for the first frame. Everything else (ModelContainer, SignInCoordinator, SFXPlayer) is `lazy` or constructed on first-use.
5. **No `Task.detached` in `App.init`.** Spinning up tasks before the first scene is rendered competes for the same main thread you need for paint. Move any "warm caches" work to `.task` modifier on the Home view.

### View-tree depth budget

- App → ContentView → TabView/HomeView → DKCard rows → cell content. **4 layers max** to first paint.
- Don't wrap in `NavigationStack` deeper than necessary. One root `NavigationStack` per major flow.
- Avoid `AnyView` — type-erasure costs SwiftUI's diffing engine cycles.

### What NOT to do at startup

- Don't initialize `CHHapticEngine` (it does I/O and audio session work; lazy on first haptic).
- Don't preload all SFX (defer to right after first paint via `.task`).
- Don't call `getCredentialState` synchronously — it's a network-touchy call. Fire it from `.task` on the root view.
- Don't read or migrate the JSON export schema unless the user is in the Settings → Export flow.

### Measurement

Use Xcode → Product → Profile → **App Launch** template in Instruments. Target: <500ms `didFinishLaunching` → first frame on iPhone 14 / 15. Anything over a second on a 14+ class device is the bug PROJECT.md flags.

**Confidence:** HIGH. The tactics are universally accepted; the only variable is asset weight.

[swiftlee-launch]: https://www.avanderlee.com/optimization/launch-time-performance-optimization/

---

## 9) Testing — Swift Testing, decisively

### The pick: Swift Testing (`@Test` / `#expect`)

Swift Testing (the modern macro-based framework that ships with Xcode 16+) is the right tool for testing pure game engines because:

1. **Engines are exactly its sweet spot.** Pure value types, deterministic outputs given inputs, parameterized over difficulty — Swift Testing's `@Test(arguments: [...])` was built for this. ([SwiftLang][swift-testing])
2. **`#expect` produces better diagnostics on failure.** It expands sub-expressions: `#expect(board.minesCount == 10)` failing prints both sides. XCTest's `XCTAssertEqual` is more verbose for less info.
3. **Parallel execution by default.** Engine tests are pure — they parallelize trivially. Faster CI.
4. **Suites with `@Suite` give natural namespacing** — `MinesweeperEngineTests` → `BoardGenerationTests`, `RevealEngineTests`, `WinDetectionTests`, `FirstTapSafetyTests`.
5. **Apple's own forward direction.** Apple positions Swift Testing as the official testing tool of choice as of Xcode 16. XCTest is in maintenance, not deprecated. ([miCoach][micoach-testing])

### Where XCTest is still needed

- `XCUIApplication` UI tests (Swift Testing has no UI testing equivalent yet).
- `measure { ... }` performance blocks (Swift Testing's perf story is thin).
- Snapshot testing if you adopt `swift-snapshot-testing` later (it's XCTest-based today, though Swift Testing support is in flight).

### Determinism note

Swift Testing **runs tests in randomized order by default**. For pure engines this is fine — they're stateless. But if you ever write a test that mutates a fixture, slap `.serialized` on it. ([SwiftLang][swift-testing])

The board generator must accept an injected RNG (`RandomNumberGenerator`) so tests can pass a `SeededRNG` for deterministic placement assertions. This isn't a Swift Testing requirement — it's an engine-design requirement that *enables* clean testing in either framework.

### Coverage targets at MVP

Per PROJECT.md MINES-03 / CLAUDE.md §5:
- `BoardGenerator`: first-tap safety (mine never in tapped cell or 8 neighbors), correct mine count per difficulty, deterministic with seed
- `RevealEngine`: flood-fill stops at numbered borders, no double-reveal, doesn't reveal flagged cells
- `WinDetector`: win when all non-mines revealed, loss when mine revealed, neither otherwise
- `Codable` round-trip on `MinesweeperStat` (Export/Import safety per PERSIST-03)

**Confidence:** HIGH on Swift Testing as the pick. HIGH on retaining XCTest for the niches.

[swift-testing]: https://github.com/swiftlang/swift-testing
[micoach-testing]: https://blog.micoach.itj.com/swift-testing-vs-xctest

---

## Alternatives Considered

| Recommended | Alternative | Why we rejected the alternative |
|---|---|---|
| SwiftData built-in CloudKit mirror | `CKSyncEngine` (manual sync) | Way more code, no actual benefit for private-DB-only with no shared/public scope. ([Apple Forum 731435][apple-forum-731435]) |
| SwiftData built-in CloudKit mirror | Core Data + NSPersistentCloudKitContainer | Older but more mature for tricky migrations. Rejected for ecosystem consistency (DesignKit-era apps standardize on SwiftData) and to avoid the API-surface duplication. |
| `LazyVGrid` of SwiftUI cells | `Canvas` + `drawingGroup` | Loses per-cell accessibility & hit testing. Massive engineering for 480 cells that SwiftUI can render fine. |
| `withAnimation` + `phaseAnimator`/`keyframeAnimator` | SpriteKit | PROJECT.md explicitly excludes game engines. SpriteKit also bypasses the DesignKit theming surface. |
| `.sensoryFeedback` + CoreHaptics for marquee | `UIImpactFeedbackGenerator` everywhere | Older surface, requires lifecycle management, can't easily express custom patterns. |
| `AVAudioPlayer` preloaded | `SystemSoundID` | Inherits ringer state, no volume control, no headroom for premium feel. |
| `AVAudioPlayer` preloaded | `AVAudioEngine` | Overkill for 3 non-overlapping cues. Right answer if a future game needs simultaneous SFX. |
| Swift Testing | XCTest | Slower iteration loop, weaker diagnostics, weaker parameterization. XCTest stays for UI/perf only. |
| Swift Testing | `swift-testing` from `pointfreeco` | Apple's official `swift-testing` IS the testing framework. We don't need an extra pkg. |
| `String(localized:)` + `.xcstrings` | `.strings` files + `NSLocalizedString` | Old workflow, no auto-extraction, harder to keep in sync. Catalog is strictly better in Xcode 15+. |
| Sign in with Apple + CloudKit private DB | Firebase Auth, Supabase, custom backend | Banned by PROJECT.md. Also hostile to the privacy posture. |
| `@MainActor` + pure value engines | `@ModelActor` background actor for everything | Premature complexity. Mines writes are tiny. Add a ModelActor when you have a writer that takes >10ms. ([Massicotte][massicotte-modelactor]) |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|---|---|---|
| Third-party backends (Firebase, Supabase, custom server) | PROJECT.md absolute exclusion + privacy posture | CloudKit private DB |
| Ad SDKs (AdMob, AppLovin, Unity Ads) | PROJECT.md absolute exclusion + differentiator | Nothing — no ads ever |
| Analytics SDKs (Firebase Analytics, Mixpanel, Amplitude, even Apple's `MetricKit` for telemetry) | PROJECT.md no-phone-home rule | Nothing — local stats only |
| TCA, Redux-likes, Combine-heavy state managers | Excessive ceremony for an app with this state graph | Lightweight MVVM with `@Observable` view models |
| SpriteKit, RealityKit, GameplayKit | Mines is a UI grid, not an action game; bypasses DesignKit | SwiftUI views + `withAnimation` |
| `Canvas` for the board | Loses per-cell accessibility and hit-testing | `LazyVGrid` of cell views |
| `AnyView` in tight render paths | Erases SwiftUI's static type info, slows diffing | Concrete `some View` returns + `@ViewBuilder` |
| `@Attribute(.unique)` / `#Unique` on synced models | Crashes CloudKit mirror at runtime | Application-level uniqueness via `UUID` ids |
| Required (non-optional) relationships in synced models | Crashes container init | All relationships optional, defaulted to empty arrays |
| `Force unwrap` in model init paths used by SwiftData | SwiftData decode-time crashes are gnarly | Optionals + defaults |
| `AVAudioPlayer` instances created on the play call | First-play latency feels broken | Preload at launch with `prepareToPlay()` |
| `AudioServicesPlaySystemSoundID` for SFX | No volume control; inherits ringer state | `AVAudioPlayer` |
| `XCTAssert*` in new test files | Worse diagnostics, less ergonomic | `#expect` in Swift Testing |
| `LocalizedStringKey` as a fn-parameter type for runtime strings | Xcode extractor misses these — they don't land in the catalog | `String(localized:)` at call site |

---

## Stack Patterns by Variant

**If user is signed in with Apple AND iCloud is available:**
- `ModelContainer` configured `cloudKitDatabase: .automatic`
- Stats sync silently to iCloud private DB
- UI surface: a small "Synced via iCloud" disclosure on Stats screen header

**If user has skipped sign-in OR iCloud is unavailable OR credential is `.revoked`:**
- `ModelContainer` configured `cloudKitDatabase: .none`
- All data is local-only, exports work via JSON
- No "sync" UI shown

**If user signs in mid-session (intro skip → later in Settings):**
- Save Apple `userID` to Keychain
- Tear down + rebuild `ModelContainer` with `.automatic` (or, if hot-swap proves flaky in testing, prompt "Sign-in active on next launch" — graceful degradation)

**If running on iOS 18+:**
- Optionally adopt `@Observable` macro improvements
- `sensoryFeedback` is unchanged (already iOS 17)
- SwiftData has additional bugfixes around `VersionedSchema` migrations

**If running on iOS 26+ (model inheritance, new at WWDC25):**
- Future games (Sudoku, Word Grid) might use `@Model` inheritance for shared `Stat` base — defer to that game's research, not MVP. ([Mike Tsai][mjtsai-wwdc25])

---

## Version Compatibility

| Package / Capability | Compatible With | Notes |
|---|---|---|
| Swift 6.0 | Xcode 16.0+ | Strict concurrency on. |
| SwiftUI iOS 17 | iOS 17.0+ | `phaseAnimator`, `keyframeAnimator`, `sensoryFeedback`, `symbolEffect` all iOS 17. |
| SwiftData CloudKit mirror | iOS 17.0+, prefer 17.4+ | Pre-17.2 had non-optional crashes; 17.4 broke a custom-migration workaround. Plan additive migrations only. |
| `SignInWithAppleButton` (SwiftUI) | iOS 14.0+, fully fine on 17+ | — |
| Swift Testing | Xcode 16.0+ | Bundled. No `Package.swift` dependency needed for app-target tests. |
| String Catalogs (`.xcstrings`) | Xcode 15+, format 1.0; Xcode 26 adds format 1.1 features | Stay on 1.0 unless using new auto-comments. |
| DesignKit (local SPM) | Swift 6.0, iOS 17+ / macOS 14+ | Matches GameKit's floor exactly. |

---

## Installation / Project Setup

```bash
# No npm here — Xcode project + Package.swift refs

# 1. In Xcode: File → Add Package Dependencies → "Add Local..."
#    Select ../DesignKit folder.

# 2. Capabilities to add to GameKit target (Signing & Capabilities → +):
#    - iCloud   (check CloudKit, container: iCloud.com.lauterstar.gamekit)
#    - Background Modes (check "Remote notifications")
#    - Push Notifications
#    - Sign in with Apple

# 3. Build Settings:
#    - Swift Language Version: Swift 6
#    - Strict Concurrency Checking: Complete
#    - Use Compiler to Extract Swift Strings: YES
#    - iOS Deployment Target: 17.0

# 4. Localizable.xcstrings: File → New → File → String Catalog (en only)

# 5. Run the test target — confirm `import Testing` resolves and a stub
#    `@Test func smoke() { #expect(true) }` runs.
```

---

## Confidence Summary

| Area | Confidence | Why |
|---|---|---|
| Swift 6 + SwiftUI + SwiftData stack | HIGH | Apple-canonical, multiply confirmed via Context7 + Apple docs |
| CloudKit constraints (no unique, no required relationships, defaults required) | HIGH | Confirmed via Apple Developer Forums (multiple threads) + Hacking With Swift + Mike Tsai's WWDC25 roundup |
| Sign in with Apple lifecycle (credential state, revocation notification) | HIGH | Apple Docs verified |
| Anonymous → signed-in container hot-swap | MEDIUM | Apple's docs are thin; community reports work but require careful teardown. Recommend launch-only swap as bulletproof fallback. |
| Animation API selection per effect | HIGH | Apple Docs verified for `phaseAnimator` / `keyframeAnimator` semantics |
| Haptics (sensoryFeedback first, CoreHaptics for marquee) | HIGH | Apple iOS 17 modifier docs verified |
| AVAudioPlayer over SystemSoundID | MEDIUM-HIGH | The trade-offs are well-understood; specific cue assets need ear-tuning during polish phase |
| String Catalog workflow | HIGH | Apple Docs + multiple current guides |
| Cold-start tactics | HIGH | Universally accepted, no hidden gotchas for an app this size |
| Swift Testing pick | HIGH | Apple's stated direction; ergonomic fit for pure engines |

---

## Sources

### Context7 (authoritative, current)
- `/websites/developer_apple_swiftdata` — `@Model`, `@Unique`, `@Relationship`, `ModelConfiguration` semantics
- `/websites/developer_apple_swiftui` — `phaseAnimator`, `keyframeAnimator`, `matchedGeometryEffect` API surface and version availability
- `/swiftlang/swift-testing` — `@Test`, `#expect`, `@Suite`, parameterized, parallel execution
- `/websites/developer_apple_testing` — Apple's official Swift Testing documentation

### Apple Developer Documentation
- [`ModelConfiguration.CloudKitDatabase`](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct)
- [`ASAuthorizationAppleIDProvider`](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidprovider)
- [`ASAuthorizationAppleIDProvider.CredentialState.revoked`](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidprovider/credentialstate/revoked)
- [`Canvas`](https://developer.apple.com/documentation/swiftui/canvas)
- [Core Haptics](https://developer.apple.com/documentation/corehaptics)
- [Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Controlling the timing and movements of your animations](https://developer.apple.com/documentation/swiftui/controlling-the-timing-and-movements-of-your-animations)

### Apple Developer Forums (verified pain points)
- [731334 — SwiftData configurations for Private and Public CloudKit](https://developer.apple.com/forums/thread/731334)
- [731375 — Disable automatic iCloud sync with SwiftData](https://developer.apple.com/forums/thread/731375)
- [731435 — CKSyncEngine & SwiftData (incompatibility)](https://developer.apple.com/forums/thread/731435)
- [744491 — SwiftData with CloudKit failing to mirror](https://developer.apple.com/forums/thread/744491)
- [756538 — Local SwiftData to CloudKit migration](https://developer.apple.com/forums/thread/756538)
- [98401 — Why does AVAudioPlayer cause lag](https://developer.apple.com/forums/thread/98401)

### Independent verifications (MEDIUM confidence)
- [Hacking With Swift — Syncing SwiftData with CloudKit](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit)
- [Hacking With Swift — How SwiftData works with concurrency](https://www.hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency)
- [Hacking With Swift — How to stop SwiftData syncing with CloudKit](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-stop-swiftdata-syncing-with-cloudkit)
- [Massicotte — ModelActor is Just Weird](https://www.massicotte.org/model-actor/)
- [Use Your Loaf — SwiftUI Sensory Feedback](https://useyourloaf.com/blog/swiftui-sensory-feedback/)
- [SwiftLee — App launch time performance](https://www.avanderlee.com/optimization/launch-time-performance-optimization/)
- [SimpleLocalize — XCStrings guide](https://simplelocalize.io/blog/posts/xcstrings-string-catalog-guide/)
- [Mike Tsai — SwiftData and Core Data at WWDC25](https://mjtsai.com/blog/2025/06/19/swiftdata-and-core-data-at-wwdc25/)
- [miCoach — Swift Testing vs XCTest](https://blog.micoach.itj.com/swift-testing-vs-xctest)
- [swiftlang/swift-testing GitHub](https://github.com/swiftlang/swift-testing)

---

*Stack research for: GameKit (iOS classic logic-games suite, MVP = Minesweeper)*
*Researched: 2026-04-24*
