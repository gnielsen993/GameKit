//
//  SettingsView.swift
//  gamekit
//
//  Phase 4 (PERSIST-02 + PERSIST-03 supporting): adds DATA section with
//  Export / Import / Reset stats rows + alerts + .fileExporter / .fileImporter.
//
//  Layout per 04-UI-SPEC §Component Inventory + §Layout & Sizing:
//    - APPEARANCE card (P1 stub — preserved unchanged; SHELL-02 polish at P5)
//    - DATA card (NEW) — three SettingsActionRow tap-targets:
//      * Export stats (square.and.arrow.up) — opens .fileExporter
//      * Import stats (square.and.arrow.down) — opens .fileImporter
//      * Reset stats (trash, theme.colors.danger) — opens .alert(role: .destructive)
//    - ABOUT card (P1 stub — preserved unchanged)
//
//  Phase 4 invariants:
//    - GameStats lazily resolved via @Environment(\.modelContext) inside
//      tap closures (not body — Pitfall 8 same as GameView)
//    - .fileImporter onCompletion wraps Data(contentsOf: url) with
//      security-scoped resource bookends (RESEARCH Pitfall 5 — LOAD-BEARING
//      for real-device imports; works in simulator without bookends but
//      fails silently in release on physical iPhone)
//    - schemaVersionMismatch and decodeFailed both surface "Couldn't import
//      stats" alert with case-specific body (UI-SPEC §Copywriting D-21)
//    - Reset alert per D-22/D-23 — single confirmation, no "Export first?"
//      nudge (user can Export from same Settings card one row above)
//    - Token discipline: zero Color(...) literals; SF Symbols only;
//      tappable rows .frame(minHeight: 44) HIG carve-out per UI-SPEC §Spacing
//

import SwiftUI
import SwiftData
import DesignKit
import UniformTypeIdentifiers
import os

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @State private var isExporterPresented = false
    @State private var isImporterPresented = false
    @State private var isResetAlertPresented = false
    @State private var isImportErrorAlertPresented = false
    @State private var importErrorMessage: String = ""
    @State private var exportDocument: StatsExportDocument?

    private var theme: Theme { themeManager.theme(using: colorScheme) }
    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "settings"
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {

                    appearanceSection
                    dataSection
                    aboutSection
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Settings"))
            .fileExporter(
                isPresented: $isExporterPresented,
                document: exportDocument,
                contentType: .json,
                defaultFilename: StatsExporter.defaultExportFilename()
            ) { result in
                if case .failure(let error) = result {
                    Self.logger.error("Export failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result: result)
            }
            .alert(
                String(localized: "Reset all stats?"),
                isPresented: $isResetAlertPresented
            ) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Reset all stats"), role: .destructive) {
                    do {
                        let stats = GameStats(modelContext: modelContext)
                        try stats.resetAll()
                    } catch {
                        Self.logger.error("Reset failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
            } message: {
                Text(String(localized: "This deletes all your Minesweeper games and best times. This can't be undone."))
            }
            .alert(
                String(localized: "Couldn't import stats"),
                isPresented: $isImportErrorAlertPresented
            ) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var appearanceSection: some View {
        // P1 stub — UNCHANGED. SHELL-02 polish at P5.
        settingsSectionHeader(theme: theme, String(localized: "APPEARANCE"))
        DKCard(theme: theme) {
            Text(String(localized: "Theme controls coming in a future update."))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var dataSection: some View {
        settingsSectionHeader(theme: theme, String(localized: "DATA"))
        DKCard(theme: theme) {
            VStack(spacing: 0) {
                SettingsActionRow(
                    theme: theme,
                    glyph: "square.and.arrow.up",
                    label: String(localized: "Export stats"),
                    glyphTint: theme.colors.textPrimary
                ) {
                    beginExport()
                }
                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)
                SettingsActionRow(
                    theme: theme,
                    glyph: "square.and.arrow.down",
                    label: String(localized: "Import stats"),
                    glyphTint: theme.colors.textPrimary
                ) {
                    isImporterPresented = true
                }
                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)
                SettingsActionRow(
                    theme: theme,
                    glyph: "trash",
                    label: String(localized: "Reset stats"),
                    glyphTint: theme.colors.danger
                ) {
                    isResetAlertPresented = true
                }
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        // P1 stub — UNCHANGED.
        settingsSectionHeader(theme: theme, String(localized: "ABOUT"))
        DKCard(theme: theme) {
            Text(String(localized: "GameKit · v1.0"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func beginExport() {
        do {
            let data = try StatsExporter.export(modelContext: modelContext)
            exportDocument = StatsExportDocument(data: data)
            isExporterPresented = true
        } catch {
            Self.logger.error("Export pre-picker failed: \(error.localizedDescription, privacy: .public)")
            // No user-facing alert per Deferred Ideas — toast is P5 polish.
        }
    }

    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // RESEARCH Pitfall 5 — LOAD-BEARING for real-device imports.
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                try StatsExporter.importing(data, modelContext: modelContext)
                // Success: silent. @Query refreshes StatsView automatically.
            } catch let importError as StatsImportError {
                importErrorMessage = importError.errorDescription
                    ?? String(localized: "The file couldn't be read. Check that it's a GameKit stats export and try again.")
                isImportErrorAlertPresented = true
            } catch {
                Self.logger.error("Import unexpected failure: \(error.localizedDescription, privacy: .public)")
                importErrorMessage = String(localized: "The file couldn't be read. Check that it's a GameKit stats export and try again.")
                isImportErrorAlertPresented = true
            }
        case .failure:
            // User cancelled — silent (no alert).
            break
        }
    }
}

// MARK: - File-private SettingsActionRow (UI-SPEC §Component Inventory)

private struct SettingsActionRow: View {
    let theme: Theme
    let glyph: String
    let label: String
    let glyphTint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.s) {
                Image(systemName: glyph)
                    .foregroundStyle(glyphTint)
                Text(label)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
            }
            .frame(minHeight: 44)               // HIG min target — UI-SPEC §Spacing carve-out
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
