---
phase: 06
slug: cloudkit-siwa
status: verified
threats_open: 0
threats_total: 22
threats_closed: 22
asvs_level: 1
created: 2026-04-27
verified: 2026-04-27
---

# Phase 06 — Security: cloudkit-siwa

> Per-phase security contract for the CloudKit + SIWA persistence wave.
> Aggregates STRIDE threat registers from Plans 06-01 through 06-09.
> All threats verified CLOSED via code grep + UAT SC1-SC5 sign-off (06-UAT.md, all 6 tests PASS @ 15bb99c).

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| App ↔ Keychain | Apple `userID` written via `SystemKeychainBackend` to secure-enclave-backed Keychain. | userID (PII) |
| App ↔ AuthenticationServices | `ASAuthorizationAppleIDProvider.getCredentialState(forUserID:)` returns 1 of 4 enum cases via background-thread callback. | credentialState |
| os.Logger ↔ system log stream | Sign-in lifecycle events log outcome strings only — never userID or identityToken. | log lines (`.public` privacy) |
| Production target ↔ Test target | `InMemoryKeychainBackend` is test-only; AuthStore EnvironmentKey default must remain `SystemKeychainBackend`. | type identity |
| App ↔ Apple Developer Console | Capability registrations (SIWA + iCloud + CloudKit + Background Modes Remote Notifications) crossed at provisioning time. | entitlements |
| App ↔ CloudKit Dashboard | Schema (`CD_GameRecord`, `CD_BestTime`) deployed via `CloudKitSchemaInitializer` (DEBUG only). | schema metadata |
| CloudKit notification ↔ Observer | `NSPersistentCloudKitContainer.eventChangedNotification` fires on background; observer hops to `@MainActor` before mutating `status`. | event payload |
| ASAuthorization result ↔ AuthStore | SIWA `onCompletion` returns `Result<ASAuthorization, Error>`. Call sites extract `credential.user` String only — never `identityToken`. | userID String |
| Production code ↔ Real iCloud / App Store Review | First contact site for SC2/SC3 manual flows; `requestedScopes = []` and empty "Quit GameKit" body checked verbatim. | runtime behavior |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-06-01 | Information Disclosure | Apple userID storage | mitigate | `SystemKeychainBackend.swift:118` uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` verbatim; no fallback to `kSecAttrAccessibleAlways` / `AfterFirstUnlock`. AuthStore reads/writes ONLY through KeychainBackend (no `UserDefaults` references). | closed |
| T-06-02 | Information Disclosure | os.Logger interpolation of userID | mitigate | Zero matches for `\(userID`, `\(stored`, or `\(currentUserID` inside any `logger.*` call in `AuthStore.swift`. Outcome strings only (`"Signed in"`, `"Cleared local sign-in state: …"`). | closed |
| T-06-03 | Information Disclosure | identityToken persistence | mitigate | Zero `identityToken` references in `Core/AuthStore.swift`, `Core/SettingsStore.swift`, `Screens/SettingsSyncSection.swift`, `Screens/IntroFlowView.swift`. Call sites extract `credential.user` String only. | closed |
| T-06-04 | Tampering | `requestedScopes` drift | mitigate | `request.requestedScopes = []` literal verified at both SIWA call sites: `IntroFlowView.swift:114`, `SettingsSyncSection.swift:80`. Zero `.email` / `.fullName` matches in either file. | closed |
| T-06-05 | Compliance / Tampering | "Quit GameKit" button action | mitigate | Zero `exit(`, `UIApplication.shared.suspend`, `abort(` matches in `Screens/RootTabView.swift`. Empty action body — UX hint only, no programmatic termination (App Store Review safe). | closed |
| T-06-06 | Tampering | Container ID literal `iCloud.com.lauterstar.gamekit` | mitigate | Literal preserved byte-identical at all 4 known sites: `App/GameKitApp.swift:79`, `Core/SettingsStore.swift:41` (doc), `Core/CloudKitSchemaInitializer.swift:47`, `gamekit.entitlements`. P4 forcing-function smoke test catches drift. | closed |
| T-06-07 | Information Disclosure | Public CloudKit DB exposure | accept | Locked: only `.private(...)` is used; PROJECT.md forbids public DB. `CloudKitSchemaInitializer` uses the same `.private`-equivalent container identifier. No public DB API surfaced. | closed |
| T-06-08 | Loss of Availability | Sign-out wipes local data | mitigate | `AuthStore.swift` does NOT import SwiftData and contains zero `ModelContainer` / `ModelContext` references. `clearLocalSignInState` deletes only the Keychain userID entry; SwiftData store path unchanged (D-08 same-store-path lock). | closed |
| T-06-09 | Denial of Service | Missing capabilities + duplicate-item Keychain write | mitigate | Capabilities verified in 06-03 Wave-0 checkpoint (UAT Test 1 PASS). `SystemKeychainBackend.write` uses idempotent `try? delete(account:)` BEFORE `SecItemAdd` to avoid `errSecDuplicateItem`. | closed |
| T-06-W-test-leak | Tampering / Information Disclosure | `InMemoryKeychainBackend` placement | mitigate | Type defined ONLY at `gamekitTests/Helpers/InMemoryKeychainBackend.swift:24`. Production target contains zero compilation references — only a doc comment in `AuthStore.swift:13` naming the stub. | closed |
| T-06-state-drift | Tampering | `SyncStatus` 4-state vs UI label drift | mitigate | `var label: String` lives ON the enum (PATTERNS §7) — adding a 5th case forces compile error in exhaustive switch. | closed |
| T-06-state-bg-write | Tampering | `status` write from background thread | mitigate | `CloudSyncStatusObserver.swift:51` is `@MainActor` final class; `Task { @MainActor [weak self] in …` (line 125) hops before mutating `status`. | closed |
| T-06-A1 | Information Disclosure (low) | Wrong userInfo key | mitigate | Defensive `guard let event = … as? Event else { return }` cast in observer handler. Key reference is `NSPersistentCloudKitContainer.eventNotificationUserInfoKey`. | closed |
| T-06-pitfall-3 | Loss of Availability | Silent CloudKit sync failures hidden | mitigate | Failure path → `.unavailable(lastSynced:)`; `logger.error` at `.public` privacy with `error.localizedDescription` only (no PII). SettingsView SYNC row 2 surfaces the unavailable state. | closed |
| T-06-PitfallF | Tampering | `withCheckedContinuation` double-resume | mitigate | `AuthStore.swift:76` uses `withCheckedContinuation`; error path early-returns at `continuation.resume(returning: .notFound)` (line 81) BEFORE the success path (line 84). | closed |
| T-06-PitfallG | Denial of Service | Battery drain from per-active-transition validation | accept | D-14 mandates scene-active checks; faster revocation detection is the intentional tradeoff. Optional debounce deferred (premature for v1). | closed |
| T-06-formatter-locale | Information Disclosure (low) | `RelativeDateTimeFormatter` locale | accept | EN-only at v1 per FOUND-05 + REQUIREMENTS §L10N-V2-01 deferred. Future locales mechanical. | closed |
| T-06-row-noSignOut | Compliance | In-app sign-out button | mitigate | `SettingsSyncSection.swift:92` `signedInRow` body has zero `Button` declarations (Image + Text + Spacer only). System Settings is the only sign-out path (PATTERNS §10 + ARCHITECTURE §line 423 lock). | closed |
| T-06-PERSIST05 | Compliance | Alert on SIWA failure | mitigate | Zero `isPresented:` matches in `SettingsSyncSection.swift` and `IntroFlowView.swift`. The only alert in the SIWA flow is the Restart prompt at `RootTabView.swift` (success path only). PERSIST-05 "never nag" honored. | closed |
| T-06-introdismiss | Tampering | `dismissIntro` helper byte-identical | mitigate | P5 `dismissIntro()` body unchanged in 06-08; only callers added (Skip / Done / SIWA-success all flip `hasSeenIntro = true`). | closed |
| T-06-schema-prod-leak | Tampering | DEBUG schema initializer shipped to production | mitigate | `Core/CloudKitSchemaInitializer.swift` bracketed by `#if DEBUG` (line 34) / `#endif` (line 82). Release builds compile zero symbols from this file. | closed |
| T-06-S1..S5 | Manual SCs (Compliance / Availability / Performance) | UAT manual sweep | mitigate | All 5 SCs verified PASS in `06-UAT.md` (commit 15bb99c). Sign-out parity (SC1), silent revocation (SC2), 2-device promotion (SC3), 4-state SyncStatus row (SC4), cold-start ≤1000ms (SC5) — every test PASS. | closed |

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-06-01 | T-06-07 | Project policy locks app to private CloudKit DB. No public DB API surfaced. | gxnielsen@gmail.com | 2026-04-27 |
| AR-06-02 | T-06-PitfallG | D-14 mandates scene-active checks; battery cost intentional vs faster revocation detection. Debounce deferred to v2. | gxnielsen@gmail.com | 2026-04-27 |
| AR-06-03 | T-06-formatter-locale | EN-only at v1 (FOUND-05). REQUIREMENTS §L10N-V2-01 deferred. Future locales mechanical. | gxnielsen@gmail.com | 2026-04-27 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-27 | 22 | 22 | 0 | /gsd-secure-phase 6 (Claude Code) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter
- [x] All mitigations verified via code grep against current `gamekit/gamekit/` source
- [x] All manual SC threats (T-06-S1..S5) backed by UAT PASS sign-off (06-UAT.md @ 15bb99c)

**Approval:** verified 2026-04-27
