import os

/// Unified logging entry point for the app.
///
/// Replaces ad-hoc `print(...)` diagnostics and inline `Logger(subsystem:...)`
/// construction. Unlike `print`, `os.Logger` respects log levels, is filterable
/// in Console.app / `log stream`, is privacy-aware, and is compiled out of the
/// hot path when not being collected — so these calls are safe to leave in
/// release builds without a `#if DEBUG` guard.
///
/// Mirrors the `AppLog` pattern in the sibling FitnessTracker repo so a session
/// crossing repos sees the same shape.
///
/// Diagnostic values (error descriptions, difficulty names, file names) are
/// interpolated as `.public` so they remain readable in logs; none carry user PII.
enum AppLog {
    private static let subsystem = "com.lauterstar.gamekit"

    /// App startup, scene lifecycle, CloudKit schema bootstrap.
    static let app = Logger(subsystem: subsystem, category: "app")
    /// Sound effects: AVAudioSession setup, CAF loading and playback.
    static let audio = Logger(subsystem: subsystem, category: "audio")
    /// Sign in with Apple, keychain access.
    static let auth = Logger(subsystem: subsystem, category: "auth")
    /// CloudKit sync of stats and save states.
    static let sync = Logger(subsystem: subsystem, category: "sync")
    /// Stats persistence, save-state encode/decode, export/import.
    static let storage = Logger(subsystem: subsystem, category: "storage")
    /// Puzzle-pack loading and validation (Nonogram, Sudoku libraries).
    static let puzzles = Logger(subsystem: subsystem, category: "puzzles")
    /// Haptic engine lifecycle.
    static let haptics = Logger(subsystem: subsystem, category: "haptics")
}
