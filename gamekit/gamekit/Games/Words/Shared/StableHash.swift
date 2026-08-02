import Foundation

/// Deterministic string hashing for content that must select the same value
/// on every launch, device, and OS version.
///
/// `String.hashValue` cannot be used for this. Swift seeds its hasher randomly
/// per process, so `"2026-07-31".hashValue` differs between launches of the
/// same binary — and therefore between two players on the same calendar day.
///
/// FNV-1a (64-bit) is specified by constant, not by library, so the mapping is
/// frozen forever. `StableHashTests` pins golden values: changing them changes
/// which puzzle every player receives on a given date, so a failure there is a
/// product regression, not a stale expectation to update.
nonisolated enum StableHash {
    private static let offsetBasis: UInt64 = 0xcbf2_9ce4_8422_2325
    private static let prime: UInt64 = 0x0000_0100_0000_01b3

    /// FNV-1a over the string's UTF-8 bytes.
    static func fnv1a(_ string: String) -> UInt64 {
        var hash = offsetBasis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }

    /// A stable index into a collection of `count` elements.
    ///
    /// Returns 0 for an empty collection so callers cannot divide by zero;
    /// they are expected to guard the empty case for their own reasons.
    static func index(for string: String, upperBound count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(fnv1a(string) % UInt64(count))
    }
}
