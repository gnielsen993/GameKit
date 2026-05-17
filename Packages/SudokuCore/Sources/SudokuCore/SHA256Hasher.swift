import Foundation
import CryptoKit

public struct SHA256Hasher: PuzzleHashing {
    public init() {}

    public func canonicalHash(for puzzleString: String) -> String {
        let digest = SHA256.hash(data: Data(puzzleString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
