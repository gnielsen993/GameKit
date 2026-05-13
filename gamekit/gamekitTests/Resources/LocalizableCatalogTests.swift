//
//  LocalizableCatalogTests.swift
//  gamekitTests
//
//  Phase 9 Wave 0 RED gate — locks the contract that Localizable.xcstrings
//  (Wave 2, plan 09-03) must satisfy:
//    - VIDEO-14 row 09-05-01: All `videoMode.*` keys exist in the catalog
//                              with non-empty `en` stringUnit values.
//
//  Key list source: 09-PATTERNS.md §7 (lists all ~11 keys verbatim).
//
//  RED-STATE NOTE: The Localizable.xcstrings catalog currently lacks the
//  videoMode.* keys. This test parses the catalog as JSON via
//  JSONSerialization (no Bundle lookups — xcstrings is a JSON file in the
//  test bundle's main bundle) and asserts each required key is present
//  with a non-empty `en` stringUnit value. Failing here is the RED gate
//  until Wave 2 plan 09-03 lands the keys.
//
//  Pattern source: 09-PATTERNS.md §7 (key naming + catalog mechanics) +
//  SettingsStoreFlagsTests.swift:23-29 (test-file header).
//
//  Test name matches 09-VALIDATION.md row 09-05-01 verbatim.
//

import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("LocalizableCatalog")
struct LocalizableCatalogTests {

    // MARK: - Helpers

    /// Per-test isolated UserDefaults — mirrors SettingsStoreFlagsTests:36-39.
    /// (Unused for this catalog test, included for pattern uniformity.)
    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    /// All `videoMode.*` keys Wave 2/3 must land in Localizable.xcstrings
    /// per 09-PATTERNS.md §7. Renaming any key here = catalog miss in
    /// production code — fail loudly.
    static let requiredVideoModeKeys: [String] = [
        "videoMode.sectionHeader",
        "videoMode.toggleLabel",
        "videoMode.locationRowTitle",
        "videoMode.location.largeTop",
        "videoMode.location.largeBottom",
        "videoMode.location.smallTopLeft",
        "videoMode.location.smallTopRight",
        "videoMode.location.smallBottomLeft",
        "videoMode.location.smallBottomRight",
        "videoMode.pickerTitle",
        "videoMode.pickerContainerA11yLabel",
        "videoMode.zoneFillLabel",
        "videoMode.manualSelectionExplanation"
    ]

    // MARK: - VIDEO-14 row 09-05-01: xcstrings key existence

    @Test("All videoMode.* xcstrings keys exist with non-empty `en` stringUnit values (VIDEO-14 / 09-05-01)")
    func test_videoMode_copy_keys_exist() throws {
        // Locate Localizable.xcstrings inside the gamekit main bundle.
        // (xcstrings is compiled into .strings files at build time, but
        // the source JSON is also available via the test bundle's
        // resource lookup when SWIFT_EMIT_LOC_STRINGS=YES.)
        //
        // For RED-state safety, we parse the source xcstrings JSON
        // directly from the gamekit source tree if the bundle lookup
        // fails — this keeps the test runnable even before the
        // xcstrings catalog has been recompiled.
        let catalogJSON = try Self.loadCatalogJSON()
        guard let strings = catalogJSON["strings"] as? [String: Any] else {
            Issue.record("Localizable.xcstrings missing top-level `strings` object")
            return
        }

        for key in Self.requiredVideoModeKeys {
            guard let entry = strings[key] as? [String: Any] else {
                Issue.record("Missing xcstrings key: \(key)")
                continue
            }
            // Navigate localizations.en.stringUnit.value
            let value = (entry["localizations"] as? [String: Any])
                .flatMap { $0["en"] as? [String: Any] }
                .flatMap { $0["stringUnit"] as? [String: Any] }
                .flatMap { $0["value"] as? String }
            #expect(value?.isEmpty == false, "Empty `en` stringUnit value for key: \(key)")
        }
    }

    // MARK: - Catalog Loading

    /// Loads the Localizable.xcstrings JSON. Tries the main bundle first;
    /// falls back to the source path resolved via `#filePath` so this
    /// test works before the xcstrings catalog is compiled into the test
    /// bundle (a real concern during the RED state — Wave 2 plan 09-03
    /// is when the catalog first contains the videoMode.* keys).
    static func loadCatalogJSON() throws -> [String: Any] {
        // 1. Bundle lookup (preferred — fast, no FS traversal).
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings") {
            let data = try Data(contentsOf: url)
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
        }
        // 2. Source-tree fallback (RED-state safe).
        // Resolve relative to this source file: ../../gamekit/Resources/Localizable.xcstrings
        let thisFile = URL(fileURLWithPath: #filePath)
        let sourcePath = thisFile
            .deletingLastPathComponent()             // gamekitTests/Resources
            .deletingLastPathComponent()             // gamekitTests
            .deletingLastPathComponent()             // gamekit/
            .appendingPathComponent("gamekit")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: sourcePath)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "LocalizableCatalogTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Localizable.xcstrings is not a valid JSON dictionary"
            ])
        }
        return obj
    }
}
