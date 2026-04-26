//
//  StatsExportDocument.swift
//  gamekit
//
//  `FileDocument` wrapper that hands the encoded `Data` to SwiftUI's
//  `.fileExporter(...)`. Plan 05 SettingsView constructs
//  `StatsExportDocument(data: encoded)` and binds it via
//  `.fileExporter(isPresented:document:contentType:defaultFilename:onCompletion:)`.
//  UTI = `public.json` (system constant `UTType.json`).
//
//  Phase 4 invariants:
//    - Per UI-SPEC §Layout & Sizing, presentation is the iOS native
//      `.fileExporter` modal — system handles document picker chrome,
//      accessibility, dismiss. No custom UI surface here.
//    - Read-side init throws `CocoaError(.fileReadCorruptFile)` on empty
//      file blob — matches Apple's idiomatic FileDocument shape and lets
//      SwiftUI's `.fileImporter` callback surface the error to the user.
//    - SwiftUI + UniformTypeIdentifiers imports ONLY here. The envelope,
//      error enum, and exporter remain Foundation/SwiftData-only.
//

import SwiftUI
import UniformTypeIdentifiers

/// `FileDocument` bridge for SwiftUI's `.fileExporter(...)` (D-21 / D-19
/// path). Wraps the encoded JSON `Data` produced by
/// `StatsExporter.export(modelContext:)`.
struct StatsExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let blob = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = blob
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
