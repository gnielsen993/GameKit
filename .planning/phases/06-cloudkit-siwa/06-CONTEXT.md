# Phase 6: CloudKit + Sign in with Apple - Context

**Gathered:** 2026-04-27
**Status:** Ready for research/planning

<domain>
## Phase Boundary

P6 ships **optional cross-device sync** by wiring the SIWA placeholder shipped in P5 to a real auth flow, flipping `SettingsStore.cloudSyncEnabled` to `true` on success, and prompting the user to relaunch so the shared `ModelContainer` reconfigures with `cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit")` (P4 D-08 already reads the flag at launch). Schema is already CloudKit-compatible from day 1 (P4 D-01..D-06). This phase adds the sign-in lifecycle, the anonymous→signed-in promotion path, the in-Settings sync surface, and the sync-status row.

**P6 ships:**
- `Core/AuthStore.swift` — NEW `@Observable @MainActor final class AuthStore`. Keychain wrapper for the Apple `userID` (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` per SC2 + Pitfalls Pitfall 5). Owns `signIn(credential:)`, `signOutLocally()`, `currentUserID -> String?`. Registers `ASAuthorizationAppleIDProvider.credentialRevokedNotification` observer in `init`. Exposes `validateOnSceneActive()` calling `getCredentialState(forUserID:)` for the stored userID and clearing Keychain + flipping `cloudSyncEnabled=false` on `.revoked` / `.notFound`.
- `Core/CloudSyncStatusObserver.swift` — NEW `@Observable @MainActor final class`. Subscribes to `NSPersistentCloudKitContainer.eventChangedNotification` and translates events into `enum SyncStatus { case syncing, syncedAt(Date), notSignedIn, unavailable(lastSynced: Date?) }`. Exposes `var status: SyncStatus { get }` for the Settings status row.
- `Core/SettingsStore.swift` edit — extend with `appleUserIDPresent: Bool` (computed from AuthStore, NOT persisted to UserDefaults). `cloudSyncEnabled` already shipped P4 — no schema change here. Verbatim P4 default (`false`) preserved; P6 flips on SIWA success.
- `Screens/SettingsView.swift` edit — new SYNC section between AUDIO and DATA per D-09. Contains: SignInWithAppleButton row when signed-out, "Signed in" status row when signed-in (no in-app sign-out button per ARCHITECTURE §line 423 + Pitfall 5 — system-level only), sync-status row showing the 4 states.
- `Screens/IntroFlowView.swift` edit — replace P5 D-21 no-op `signInTapped()` with real SIWA `onCompletion` handler that calls `AuthStore.signIn(credential:)`, sets `cloudSyncEnabled=true`, and triggers the Restart prompt at app level. Skip path unchanged.
- `Screens/RestartPromptView.swift` (or inline in `RootTabView` — planner discretion) — new `.alert` modifier wired to a single app-level `@State var showRestartPrompt: Bool` per D-13.
- `App/GameKitApp.swift` edit — construct `AuthStore` and `CloudSyncStatusObserver` at startup (mirrors P4 SettingsStore D-29 + P5 SFXPlayer D-12 injection pattern). Call `AuthStore.validateOnSceneActive()` on `scenePhase` transitions to `.active` (per SC2). Register the alert at root scope so it surfaces from either Settings or IntroFlow trigger.
- `gamekit/gamekit.entitlements` — add `com.apple.developer.applesignin` (`Default`) entitlement; iCloud + CloudKit container `iCloud.com.lauterstar.gamekit` (already declared P1 — verify no drift).
- `Resources/Localizable.xcstrings` edit — auto-extracted P6 strings (Restart alert title/body/buttons, sync-status row labels, signed-in row label).
- Tests:
  - `gamekitTests/Core/AuthStoreTests.swift` — Swift Testing. Keychain round-trip (write userID → read → delete), `validateOnSceneActive` clears state on synthetic `.revoked`, observer wires `credentialRevokedNotification` once. Real Keychain access requires a host-app entitlement; tests run against a stubbed `KeychainBackend` protocol with an in-memory implementation.
  - `gamekitTests/Core/CloudSyncStatusObserverTests.swift` — Swift Testing. 4-state machine: synthetic `eventChangedNotification` events flip the published `status` to the right case; "Synced X ago" label format function (pure) verified for <60s / minutes / hours / days inputs.
- Manual checkpoint plan in `06-VERIFICATION.md` (planner-authored): SC1 feature-parity signed-out sweep, SC2 SIWA flow + Keychain + scene-active validation + revocation, SC3 50-game promotion via 2-simulator iCloud test, SC4 sync-status 4 states, SC5 once-in-intro + once-in-settings + cold-start <1s regression test (Instruments).

**Out of scope for P6** (owned by other phases):
- Schema deploy from CloudKit Dashboard Development → Production (P7 + Pitfalls Pitfall 3 + Pitfall 11). P6 ships against Development; the Production promotion + nutrition-label sign-off is a P7 release-checklist item.
- Real app icon (P7 FOUND-06).
- App Review / TestFlight verification of SIWA in Production (P7).
- Live `ModelContainer` hot-swap on flag change (deferred — see D-08, MEDIUM-confidence path that the launch-only Restart prompt sidesteps entirely).
- `CKSyncEngine` / `@ModelActor` for writes (PROJECT.md out-of-scope reminder).
- Privacy nutrition label answer (P7 — ROADMAP Phase 7 SC2).

**v1 ROADMAP P6 success criteria carried forward as locked specs (no re-asking):**
- SC1 — Full-feature Minesweeper plays without ever signing in; every gameplay path / stat / theme works identically signed-out and signed-in.
- SC2 — SIWA in Settings with `request.requestedScopes = []`; Apple `userID` persists in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; `getCredentialState(forUserID:)` runs on every scene-active transition; `credentialRevokedNotification` observer registered.
- SC3 — Anonymous→signed-in promotion: 50-game user signs in, sees Restart prompt, restarts, all 50 games present + mirroring; verified via 2nd simulator on the same iCloud account showing the rows.
- SC4 — Settings sync-status row reports 4 states ("Synced just now" / "Syncing…" / "Not signed in" / "iCloud unavailable — last synced [date]") subscribed to `NSPersistentCloudKitContainer.eventChangedNotification`.
- SC5 — SIWA surfaced once in 3-step intro (with Skip) and once in Settings; never modal, never push, never re-prompted after dismissal. Cold-start <1s post-sign-in (FOUND-01 not regressed).

</domain>

<decisions>
## Implementation Decisions

### First-sign-in Restart prompt (PERSIST-04 + SC5)
- **D-01:** **Surface = iOS `.alert`** (per W-confirmed). Title `"Restart to enable iCloud sync"`, body per D-04. Two buttons: `"Cancel"` (`.cancel` role) and `"Quit GameKit"` (default role). Lightest touch, matches the Apple Notes/Reminders idiom for relaunch-required toggles. NO themed sheet, NO `.fullScreenCover` — overweight for a non-destructive instruction.
- **D-02:** **`cloudSyncEnabled` flips `true` on SIWA success, BEFORE the prompt shows** (per W-confirmed). The prompt is a UX hint, not a consent gate. If the user taps Cancel and never quits, the next cold-start picks up `cloudSyncEnabled=true` and reconfigures the `ModelConfiguration` with `.private("iCloud.com.lauterstar.gamekit")` automatically (P4 D-08 path) — sticky decision, matches Pitfall 4 "same store path; mirroring just turns on." No half-state, no rollback complexity.
- **D-03:** **Prompt fires from BOTH SIWA success sites: Settings sign-in tap AND IntroFlow Step 3 SignInWithAppleButton onCompletion** (per W-confirmed). Single source of truth: `@State var showRestartPrompt: Bool` lives at root level (likely `RootTabView` or a `RestartPromptModifier` wrapping the scene). Either trigger sets it `true`; alert dismiss clears it. Honors SC5 "surfaced once in intro and once in Settings."
- **D-04:** **Copy — Apple-style minimal** (per W-confirmed):
  - Title: `"Restart to enable iCloud sync"`
  - Body: `"Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup."`
  - Buttons: `"Cancel"` (`.cancel`) / `"Quit GameKit"` (default)
- **D-05:** **"Quit GameKit" button = dismiss-only — NO `exit(0)` / `UIApplication.shared.suspend()` call.** Calling `exit(0)` from app code is an App Store Review red flag (guidance: apps must not programmatically terminate; user-initiated termination only). Both buttons dismiss the alert; the body copy instructs the user to manually swipe away from the app switcher and reopen. The button label is a UX hint ("here's what to do"), not a programmatic action.
- **D-06:** **No re-prompt logic, no dedup flag.** If the user dismisses, the next cold-start naturally reconfigures with CloudKit. If they're already running cloud-mirrored on a fresh launch (the alert never shows again because the prompt is wired to *the SIWA completion event*, not to "cloudSyncEnabled changed"). Simpler than a `hasShownRestartPrompt: Bool` flag — no SettingsStore key bloat.

### Container reconfiguration strategy (locked from ROADMAP RESEARCH HIGH-conf default)
- **D-07:** **Launch-only reconfiguration via Restart prompt** — THIS phase does NOT introduce live `ModelContainer` reconfiguration. The flag `cloudSyncEnabled` is read once at `GameKitApp.init()` per P4 D-08; flipping the flag while the app is running does not affect the live container. The Restart prompt (D-01..D-06) is the entire reconfig UX. Roadmap notes HIGH confidence on this path; the MEDIUM-confidence "hot-swap" alternative is deliberately deferred.
- **D-08:** **Same store path in both modes** (per ARCHITECTURE Pattern 5 + Pattern 4). Flipping `cloudKitDatabase: .none` → `.private("iCloud.com.lauterstar.gamekit")` on next launch reuses the same on-disk SQLite store. SwiftData/CloudKit sees existing local rows and pushes them up — that's the entire promotion mechanism (PERSIST-06). Local data is NEVER orphaned by the swap (Pitfall 4 mitigation).

### Settings SYNC section + sign-in surface (PERSIST-05 + SC4 + SC5)
- **D-09:** **New SYNC section between AUDIO and DATA**. Section order locks to: APPEARANCE → AUDIO → **SYNC** → DATA → ABOUT. Maintains P5 D-13 logical grouping (preferences first, data ops next, meta last). SYNC sits before DATA because it gates whether DATA Export/Import is supplemented by cross-device sync.
- **D-10:** **SYNC section content — 2 rows:**
  - **Row 1: Sign-in row.** Signed-out → `SignInWithAppleButton(.signIn, onRequest:, onCompletion:)` rendered inline (DKCard styling). Signed-in → static row showing `"Signed in to iCloud"` + faint subtitle showing the masked Apple ID (e.g. `"Apple ID: ****1234"` if AuthStore can derive a 4-digit suffix from the userID; otherwise just `"Signed in to iCloud"`). NO sign-out button — system-only per ARCHITECTURE §line 423 + Pitfall 5.
  - **Row 2: Sync-status row.** Reads from `CloudSyncStatusObserver.status`:
    - `.notSignedIn` → `"Not signed in"`, secondary text color
    - `.syncing` → `"Syncing…"` with subtle pulsing dot (theme.colors.accentPrimary)
    - `.syncedAt(date)` → `"Synced just now"` if `Date.now - date < 60s`, otherwise relative format `"Synced X ago"` via `RelativeDateTimeFormatter`
    - `.unavailable(lastSynced)` → `"iCloud unavailable"` + sub-line `"Last synced [relative]"` if known
- **D-11:** **`CloudSyncStatusObserver` observer location** — constructed in `GameKitApp.init()` after `SettingsStore` and `AuthStore`, injected via custom `EnvironmentKey` (`@Environment(\.cloudSyncStatusObserver)`). Mirrors P4 D-29 SettingsStore pattern + P5 D-12 SFXPlayer pattern. Observer subscribes to `NSPersistentCloudKitContainer.eventChangedNotification` in its `init`; SettingsView's status row reads `observer.status` directly.
- **D-12:** **Refresh cadence** — observer updates `@Observable` published `status` immediately on every notification. The "Synced X ago" relative-time label is recomputed on every SwiftUI body invocation (cheap; SwiftUI re-renders the row when `status` changes, and a `TimelineView(.periodic(from: .now, by: 60))` wraps the label so the relative-time string ticks once per minute without observer churn).

### Credential lifecycle (PERSIST-04 + SC2)
- **D-13:** **AuthStore registers `credentialRevokedNotification` observer in `init`** (per Pitfall 5 mitigation). On notification fire: clear Keychain userID, set `cloudSyncEnabled=false`, log via `os.Logger(subsystem:category:"auth")`. NO alert — sign-in card silently returns to the SYNC section per "never nag" PERSIST-05 literal. Local stats remain intact (Pattern 5 + Pitfall 4).
- **D-14:** **Scene-active validation** — `GameKitApp` observes `scenePhase` and on transition to `.active` calls `AuthStore.validateOnSceneActive()`. The method calls `ASAuthorizationAppleIDProvider().getCredentialState(forUserID: storedUserID)` for any stored userID; if return is `.revoked` or `.notFound`, executes the same clear-state path as D-13. If `.authorized`, no-op. If `.transferred`, treat as `.notFound` (defensive default — Apple docs: rare developer-account migration case).
- **D-15:** **Reinstall path** — fresh install has empty Keychain (system behavior). First scene-active: no stored userID → no `getCredentialState` call → SYNC section shows the SIWA button. User re-signs in fresh. CloudKit-mirrored data already in iCloud waits for the first cold-start with `cloudSyncEnabled=true` (post-Restart prompt) and pushes back down.
- **D-16:** **Keychain wrapper isolation** — `AuthStore` does NOT call SecItem APIs directly in its public methods. A nested `protocol KeychainBackend` defines `read/write/delete(account:)` and ships with two implementations: `SystemKeychainBackend` (production, uses `Security.framework`) and `InMemoryKeychainBackend` (tests). AuthStore takes the backend in its init via dependency injection — matches the P4 `InMemoryStatsContainer` test-helper pattern.

### Test matrix scope (locked default — Swift Testing where deterministic, manual where iCloud-dependent)
- **D-17:** **Swift Testing automated:**
  - `AuthStoreTests` — backend round-trip (write/read/delete), revocation handler clears state, scene-active stub returns each `ASAuthorizationAppleIDProvider.CredentialState` case → AuthStore reacts correctly
  - `CloudSyncStatusObserverTests` — synthetic `Notification.Name("NSPersistentCloudKitContainer.eventChangedNotification")` posts with `setupEvent.endDate` / `importEvent` / `exportEvent` payloads → observer.status is the right case; relative-time label is correct for <60s / minutes / hours / days
- **D-18:** **Manual SC1-SC5 verification checkpoint** (P6 plan ships a `06-VERIFICATION.md` template):
  - **SC1** — Sign-out feature-parity sweep on every Mines flow (start / reveal / flag / win / loss / restart / theme switch / Settings open).
  - **SC2** — Sign-in via SettingsView, verify Keychain entry written; backgrounding + foregrounding fires `validateOnSceneActive`; manually revoke via `Settings → Apple ID → Password & Security → Sign in with Apple → GameKit → Stop using Apple ID`; foreground app, verify SYNC section returns to signed-out state silently.
  - **SC3** — Two-simulator iCloud promotion test: simulator A plays 50 Hard games signed-out, signs in, taps Quit GameKit, kills simulator A, relaunches. Simulator B (same iCloud account, fresh install, signs in) opens Stats → 50 games appear after CloudKit catches up (allow up to 60s). NB: requires CloudKit Dashboard schema deployed to Development environment first; Production schema deploy is P7.
  - **SC4** — Sync-status row: each of 4 states observable. `"Not signed in"` (default), `"Syncing…"` (force-trigger via 50-record Reset → re-import → cloud push), `"Synced just now"` (immediately after sync settles), `"iCloud unavailable"` (toggle Airplane Mode + tap Refresh on a sync trigger; status row updates).
  - **SC5** — Cold-start <1s with cloudSyncEnabled=true (Instruments time-profile from launch tap to RootTabView idle). SIWA appears in IntroFlow Step 3 (already P5) and in Settings SYNC section (new) — TWO surfaces, never modal interrupt during gameplay, never re-prompted after dismiss.

### Claude's Discretion
The user did not lock the following — planner has flexibility but should align with research / CLAUDE.md / ARCHITECTURE.md:

- **Whether the SIWA `request.requestedScopes` array is `[]` or `[.email, .fullName]`** — locked by SC2 verbatim (`requestedScopes = []`). No discretion. Listed here only because researchers sometimes propose collecting scopes "in case we need them later" — that violates the "no analytics, no PII" PROJECT.md posture.
- **Whether to render "Apple ID: ****1234" suffix** in D-10 Row 1 — depends on whether AuthStore can derive a stable suffix from the opaque Apple userID without relying on email/fullName scopes. Recommend: just show `"Signed in to iCloud"`; no suffix.
- **Where the `RestartPromptModifier` lives** — D-03 says root level; planner picks `RootTabView` body vs a dedicated `RestartPromptModifier: ViewModifier`. Either is acceptable. CLAUDE.md §8.5 file-cap nudge: if `RootTabView` grows past 200 lines, extract.
- **`SyncStatus` enum location** — `Core/CloudSyncStatusObserver.swift` (alongside the observer) or a sibling `Core/SyncStatus.swift`. Recommend: alongside the observer for now; promote to sibling if a 2nd consumer (e.g., HomeView badge) appears.
- **`TimelineView(.periodic(...))` wrap of the relative-time label** — D-12 recommends; planner may use a single global `Timer.publish` if multiple status labels appear. Premature for v1.
- **Whether `validateOnSceneActive` is `async`** — `getCredentialState(forUserID:completion:)` is callback-based; wrapping in an `async` function via `withCheckedContinuation` is cleaner. Recommend: `async`, called from a Task in the scenePhase observer.
- **Schema deploy timing in P6 vs P7** — P6 must use Development environment to validate the 2-simulator test (D-18 SC3); promotion to Production is P7. P6 plan should call out "Schema deployed to Development before SC3 manual run" as a checklist item.
- **Reset Stats interaction with cloudSyncEnabled** — Reset (P4 D-13) deletes local rows; CloudKit mirroring then propagates the delete. Confirm in P6 verification that SC4 status row reflects the delete event correctly. No new code needed.

### Folded Todos
None — `gsd-sdk query todo.match-phase 6` returned 0 matches.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project rules + invariants
- `CLAUDE.md` — Project constitution (§1 stack/data-safety/no-Color/no-account-required, §2 DesignKit conventions, §8.5 file caps, §8.6 .foregroundStyle, §8.10 atomic commits, §8.12 theme matrix)
- `AGENTS.md` — Mirror of CLAUDE.md
- `.planning/PROJECT.md` — Vision + non-negotiables (CloudKit container ID `iCloud.com.lauterstar.gamekit`; "no analytics", "no required accounts", "Apple-native only" posture)
- `.planning/REQUIREMENTS.md` — PERSIST-04, PERSIST-05, PERSIST-06 full text
- `.planning/ROADMAP.md` — Phase 6 entry: goal, SC1–SC5, RESEARCH flag (HIGH confidence on launch-only Restart-prompt path)

### Architecture + research
- `.planning/research/ARCHITECTURE.md` §Pattern 5 (Conditional CloudKit via ModelConfiguration Swap at App Boot — load-bearing for D-07/D-08)
- `.planning/research/ARCHITECTURE.md` §Pattern 4 (Sign-in flow PERSIST-06 — same store path, mirroring on/off)
- `.planning/research/ARCHITECTURE.md` §Sign-In → CloudKit Promotion section (D-02 sequence)
- `.planning/research/ARCHITECTURE.md` §line 423 (CloudKit sign-out is system-level only — D-10 no-in-app-sign-out lock)
- `.planning/research/PITFALLS.md` Pitfall 3 (silent CloudKit sync failures — D-11/D-12 status-row design driver)
- `.planning/research/PITFALLS.md` Pitfall 4 (anonymous-to-signed-in promotion data loss — D-08 same-store-path lock)
- `.planning/research/PITFALLS.md` Pitfall 5 (SIWA credential revocation lifecycle — D-13/D-14/D-15 lock)
- `.planning/research/PITFALLS.md` Pitfall 11 (App Store CloudKit gotchas — P7 schema-deploy boundary D-Discretion #7)
- `.planning/research/STACK.md` (SwiftUI + SwiftData + iOS 17+ + AuthenticationServices)

### Prior phase decisions (consumed, do NOT modify)
- `.planning/phases/01-foundation/01-CONTEXT.md` — Bundle ID lock, container ID lock, capabilities baseline
- `.planning/phases/04-stats-persistence/04-CONTEXT.md` — D-07/D-08 ModelContainer single-shared + cloudSyncEnabled flag (THE entry point for P6 reconfig); D-09 container ID lock; D-10 SC3 smoke test (already verifies `.private(...)` constructs cleanly); D-28/D-29 SettingsStore + EnvironmentKey injection pattern (P6 mirrors for AuthStore + CloudSyncStatusObserver)
- `.planning/phases/05-polish/05-CONTEXT.md` — D-12 SFXPlayer EnvironmentKey precedent (P6 mirrors); D-21 IntroFlow Step 3 SIWA placeholder (`onCompletion` is no-op log — P6 wires it); D-13 Settings section order (P6 inserts SYNC between AUDIO and DATA per D-09)
- `.planning/phases/03-mines-ui/03-CONTEXT.md` — VM contract; A11y label format precedent
- `.planning/phases/02-mines-engines/02-CONTEXT.md` — `MinesweeperDifficulty.rawValue` canonical key (no change in P6)

### Existing source files (extending in P6)
- `gamekit/gamekit/App/GameKitApp.swift` — Add AuthStore + CloudSyncStatusObserver construction + scenePhase observer for `validateOnSceneActive` + root-level Restart alert wiring
- `gamekit/gamekit/Core/SettingsStore.swift` — `cloudSyncEnabled` already shipped; P6 reads it at SIWA-success site
- `gamekit/gamekit/Screens/SettingsView.swift` — Add SYNC section (D-09/D-10) between AUDIO and DATA
- `gamekit/gamekit/Screens/IntroFlowView.swift` — Replace `signInTapped` no-op with real SIWA `onCompletion` handler (D-03)
- `gamekit/gamekit/Resources/Localizable.xcstrings` — auto-extracted P6 strings
- `gamekit/gamekit.entitlements` — verify `com.apple.developer.applesignin` + iCloud + CloudKit container `iCloud.com.lauterstar.gamekit`

### NEW source (P6 ships)
- `gamekit/gamekit/Core/AuthStore.swift` — Apple userID Keychain wrapper + revocation/scene-active lifecycle
- `gamekit/gamekit/Core/CloudSyncStatusObserver.swift` — `eventChangedNotification` → `SyncStatus` translator
- `gamekit/gamekit/Core/SyncStatus.swift` (or alongside observer per Discretion) — 4-state enum
- `gamekit/gamekitTests/Core/AuthStoreTests.swift` — Swift Testing
- `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift` — Swift Testing
- `gamekit/gamekitTests/Helpers/InMemoryKeychainBackend.swift` — `protocol KeychainBackend` test stub
- `.planning/phases/06-cloudkit-siwa/06-VERIFICATION.md` — manual SC1-SC5 checkpoint (planner authors)

### Apple frameworks
- `AuthenticationServices` (`ASAuthorizationAppleIDProvider`, `ASAuthorizationController`, `SignInWithAppleButton`) — SIWA flow
- `Security` framework — Keychain (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`)
- `CoreData.NSPersistentCloudKitContainer` — `eventChangedNotification` (SwiftData uses this internally; the notification fires regardless of whether the app uses SwiftData or Core Data)
- `CloudKit` (`CKContainer`) — read-only, identifier-only references for the container ID; do NOT call CKContainer APIs directly (SwiftData mediates)

### CloudKit Dashboard (manual ops, P6 partially / P7 fully)
- CloudKit Dashboard Development environment — schema indexes auto-deploy via `try await container.initializeCloudKitSchema()` (Pitfall 3 mitigation; one-shot dev step before SC3 manual test)
- CloudKit Dashboard Production environment — promote schema (P7 release-checklist item; out of scope for P6)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`SettingsStore.cloudSyncEnabled`** (P4 D-08): already wired into `GameKitApp.init()` — flipping it on SIWA success is the entire reconfig trigger.
- **`SignInWithAppleButton`** (Apple framework, already imported in P5 IntroFlowView at line 245): same component reused in SettingsView SYNC section, no new dependency.
- **`SettingsToggleRow` / `SettingsActionRow`** (P5 SettingsView.swift:348-407): file-private row components reusable in spirit; the SYNC sign-in row may need a 3rd file-private variant (`SettingsAuthRow`) for the SIWA-button-or-status-line conditional.
- **`DKCard` / `DKThemePicker`** (DesignKit): SYNC section uses DKCard wrapper matching P5 sections.
- **EnvironmentKey injection pattern** (P4 SettingsStore + P5 SFXPlayer): direct precedent for injecting AuthStore + CloudSyncStatusObserver.
- **In-memory test backend pattern** (`InMemoryStatsContainer.swift` from P4): `InMemoryKeychainBackend` mirrors this exactly.

### Established Patterns
- **`@Observable @MainActor final class`** for app-level singletons constructed in GameKitApp.init (P4 SettingsStore, P5 SFXPlayer). AuthStore + CloudSyncStatusObserver MUST follow this shape — `@StateObject`/`@ObservableObject` is incompatible with `@Observable`.
- **Custom `EnvironmentKey`** for non-SwiftData app-level types (P4 D-29). `@EnvironmentObject` is reserved for `ThemeManager` (`ObservableObject` legacy).
- **Settings section = `settingsSectionHeader` + `DKCard { VStack(spacing: 0) { rows + 1pt borders } }`** (P5 SettingsView §dataSection / §audioSection structure).
- **No `withAnimation` in app-level state machines** (P5 D-05) — animation is view-layer only. P6 status-row pulse + transitions live in the SettingsView, not in the observer.
- **`os.Logger(subsystem:"com.lauterstar.gamekit", category:...)`** for non-fatal failures (P4 GameStats, P5 Haptics). AuthStore uses `category: "auth"`; CloudSyncStatusObserver uses `category: "cloudkit"`.
- **Force-quit + cold-start as the natural reconfig path** (P4 D-29 + ARCHITECTURE Pattern 5). P6 doesn't introduce live mutation of construction-time decisions.

### Integration Points
- **`GameKitApp.init`** — construct AuthStore + CloudSyncStatusObserver after SettingsStore (existing line 49) + SFXPlayer (existing line 56), inject into Environment alongside them.
- **`GameKitApp.body`** scene — observe `scenePhase` via `.onChange(of: scenePhase)`; on `.active`, call `Task { await authStore.validateOnSceneActive() }`. Wire root-level `.alert(isPresented: $showRestartPrompt) { ... }` here.
- **`IntroFlowView.signInTapped`** (line 124) — replace no-op log with real SIWA invocation through AuthStore + restart-prompt trigger. The existing `SignInWithAppleButton` at line 245 already provides `onCompletion`; pipe the credential into AuthStore.
- **`SettingsView` SYNC section** — inserted between `audioSection` (line 161) and `dataSection` (line 187). New `private var syncSection: some View` mirrors existing section structure.

</code_context>

<specifics>
## Specific Ideas

- Restart alert title: `"Restart to enable iCloud sync"`.
- Restart alert body: `"Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup."`
- Restart alert buttons: `"Cancel"` (`.cancel` role) / `"Quit GameKit"` (default role, dismiss-only — NO `exit(0)`).
- Sync-status row labels (literal): `"Not signed in"` / `"Syncing…"` / `"Synced just now"` / `"Synced [relative]"` / `"iCloud unavailable"` + secondary line `"Last synced [relative]"`.
- Signed-in row label: `"Signed in to iCloud"` (no Apple-ID suffix per Discretion #2).
- SIWA `request.requestedScopes = []` (SC2 verbatim — userID only, no email, no fullName).
- Keychain attributes: `kSecClass = kSecClassGenericPassword`, `kSecAttrService = "com.lauterstar.gamekit.auth"`, `kSecAttrAccount = "appleUserID"`, `kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (SC2 + Pitfall 5 verbatim).
- `os.Logger` subsystems: `subsystem: "com.lauterstar.gamekit", category: "auth"` for AuthStore; `category: "cloudkit"` for CloudSyncStatusObserver.
- `CloudSyncStatusObserver.status` initial value: `.notSignedIn` if `cloudSyncEnabled=false`, else `.syncing` (CloudKit setupEvent typically fires within 1-2s of app launch in cloud mode).
- Relative-time formatter: `RelativeDateTimeFormatter` with `.named` style (`"just now"`, `"5 minutes ago"`, `"yesterday"`).
- TimelineView wrap for status row label: `TimelineView(.periodic(from: .now, by: 60)) { _ in Text(status.label) }` so "Synced 5 minutes ago" ticks to "6 minutes ago" without observer churn.
- Test environment: `gamekitTests` host-app target needs the `com.apple.developer.applesignin` entitlement disabled (tests use `InMemoryKeychainBackend`, no real Keychain access). Verify CI scheme matches.
- Schema deploy: before SC3 manual test, run `try await sharedContainer.initializeCloudKitSchema()` ONCE in a debug build to materialize record types in CloudKit Dashboard Development. This is a one-shot setup step, NOT shipped production code (Pitfall 3 mitigation).

</specifics>

<deferred>
## Deferred Ideas

- **Live `ModelContainer` hot-swap on `cloudSyncEnabled` change** — MEDIUM-confidence path per ROADMAP RESEARCH flag. Skipped in P6 because the launch-only Restart prompt is HIGH confidence and avoids the entire teardown/recreate sequence. If post-TestFlight feedback shows the Restart prompt is friction-y, revisit as a v1.x polish.
- **In-app sign-out button** — not adding per ARCHITECTURE §line 423 + Pitfall 5 (CloudKit sign-out is a system-level action, not an app one; matches Apple Notes behavior).
- **Apple-ID suffix display** (`"Apple ID: ****1234"`) in signed-in row — depends on userID format stability; defer to a polish phase if ever wanted.
- **CloudKit Dashboard Production schema promotion** — P7 release-checklist item (ROADMAP Phase 7 SC1).
- **Privacy nutrition label sign-off** — P7 (ROADMAP Phase 7 SC2).
- **TestFlight verification of SIWA in Production environment** — P7 (ROADMAP Phase 7 SC3).
- **Sync conflict resolution UI** — CloudKit handles last-writer-wins by timestamp under `NSPersistentCloudKitContainer`. Multi-device merge edge cases (rare for stats) would need surface; defer until they actually occur.
- **`@ModelActor` for sync writes** — PROJECT.md out-of-scope reminder. v2+ if perf demands.
- **`CKSyncEngine`** — PROJECT.md out-of-scope reminder. Apple's lower-level alternative; sticking with `NSPersistentCloudKitContainer` via SwiftData.
- **Sign-in with Google / passkeys / WebAuthn** — PROJECT.md "Apple-native only" lock; never.
- **Sign-out triggered by user toggling `cloudSyncEnabled` off in app** — would require a new in-Settings toggle that doesn't exist (sign-out IS the disable mechanism, and it's system-level). Defer permanently per CLAUDE.md non-negotiables.
- **Sync-status row pulse animation on `.syncing`** — visual polish; if planner implements a subtle dot pulse, fine; if defers to a v1.x polish, also fine. Not a SC requirement.
- **Two-Apple-ID-on-same-device handling** — Apple's docs treat this as user error (one userID per device per app); no special UX. Defer permanently.

</deferred>

---

*Phase: 06-cloudkit-siwa*
*Context gathered: 2026-04-27*
