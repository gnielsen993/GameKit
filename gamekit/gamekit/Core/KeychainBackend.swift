//
//  KeychainBackend.swift
//  gamekit
//
//  P6 (D-16): Apple-framework wrapper for Keychain Services (Security
//  framework). Protocol seam means AuthStore (Plan 06-04) can be unit-tested
//  via an in-memory test stub (test target only) without requiring a
//  host-app Keychain entitlement or a real iCloud account.
//
//  Phase 6 invariants:
//    - **Verbatim attribute lock (T-06-01 mitigation, SC2 + Pitfall 5):**
//      `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` is the ONLY
//      acceptable accessibility class. Any drift to `kSecAttrAccessibleAlways`
//      or `kSecAttrAccessibleAfterFirstUnlock` (which migrates across
//      devices) breaks the SC2 verbatim guarantee.
//    - **Service-name lock (T-06-06 mitigation):** `serviceName` is a
//      `static let` constant so a typo trips Keychain lookup but cannot
//      corrupt user data. Smoke-tested in Plan 06-04 round-trip suite.
//    - **Idempotent write (T-06-09 mitigation):** `write(_:account:)` calls
//      `try? delete(account:)` BEFORE `SecItemAdd` to avoid the
//      `errSecDuplicateItem` failure class entirely (RESEARCH §Pattern 3
//      lines 421-423).
//    - **Protocol seam (D-16):** an in-memory test stub (test target only)
//      bypasses real `SecItem*` calls; production target only ever sees
//      `SystemKeychainBackend`.
//
//  Threat model (Plan 06-01 register):
//    - T-06-01 (Information Disclosure): the verbatim accessibility token
//      ensures Keychain rows never migrate to a new device and require
//      first-unlock before they can be read.
//    - T-06-06 (Tampering): hardcoded `serviceName` is the lookup root —
//      mismatch breaks lookup, never corrupts data.
//    - T-06-09 (Denial of Service): delete-then-add idempotent pattern
//      avoids `errSecDuplicateItem` on repeated sign-in flows.
//
//  Logging note: error reporting flows through `KeychainError` thrown
//  from `write` / `delete`. `AuthStore` (Plan 06-04) owns the
//  `os.Logger(subsystem: "com.lauterstar.gamekit", category: "auth")`
//  call sites so Keychain identifiers (Apple userID) never appear in
//  this file's surface — anti-pattern guard per RESEARCH lines 693-694.
//

import Foundation
import Security

// MARK: - Protocol seam (D-16)

/// Test-injectable Keychain wrapper. Production callers receive
/// `SystemKeychainBackend()` by default; AuthStoreTests inject the
/// in-memory test stub (test target only).
protocol KeychainBackend: Sendable {
    func read(account: String) -> String?
    func write(_ value: String, account: String) throws
    func delete(account: String) throws
}

// MARK: - Errors

/// Non-fatal errors thrown by the production backend. AuthStore logs
/// these via `os.Logger` and continues — the flag-flip contract on
/// revocation MUST proceed even if Keychain delete fails.
enum KeychainError: Error {
    case writeFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
}

// MARK: - Production backend

/// Production `KeychainBackend` implementation backed by `SecItem*`
/// calls from `Security.framework`. Verbatim attribute set per
/// CONTEXT line 202 + SC2 lock — do NOT modify any of the literal
/// `kSec*` values without a phase-level decision.
///
/// NOT `@MainActor`: Apple `SecItem*` APIs are thread-safe, and the
/// `KeychainBackend` protocol is `Sendable`. Annotating with
/// `@MainActor` would force the conformance to cross actor isolation
/// (Swift 6 strict-concurrency error: "Conformance crosses into main
/// actor-isolated code"). AuthStore (Plan 06-04) is `@MainActor` and
/// holds a `let backend: KeychainBackend` reference — calling Sendable
/// non-isolated methods from a MainActor context is allowed.
final class SystemKeychainBackend: KeychainBackend, @unchecked Sendable {
    // @unchecked Sendable: this class has no instance stored properties
    // (only `static let serviceName`), and Apple's SecItem* APIs are
    // thread-safe per Apple Security framework docs. The "@unchecked"
    // marker tells the compiler we've manually verified safety.

    /// Hardcoded Keychain service name (T-06-06 lock). Renaming breaks
    /// lookup; smoke-tested in Plan 06-04 round-trip.
    static let serviceName = "com.lauterstar.gamekit.auth"

    func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    func write(_ value: String, account: String) throws {
        // Idempotent: delete-then-add avoids errSecDuplicateItem (T-06-09).
        try? delete(account: account)
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            // SC2 + Pitfall 5 verbatim — T-06-01 mitigation:
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(status: status)
        }
    }

    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}
