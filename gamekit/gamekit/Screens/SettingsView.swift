//
//  SettingsView.swift
//  gamekit
//
//  Phase 5 (SHELL-02 + THEME-03 entry point + A11Y-02): rebuilt Settings spine.
//  Phase 4 DATA section preserved verbatim (D-16).
//
//  Layout per 05-UI-SPEC + 05-CONTEXT D-13 (section order):
//    - APPEARANCE card — 5 Classic preset swatches (DKThemePicker(catalog: .core,
//      grouped: false)) + 1pt divider + "More themes & custom colors" NavigationLink
//      to FullThemePickerView (D-14, CLAUDE.md §2 theme picker UX convention)
//    - AUDIO card (NEW P5) — 2 SettingsToggleRow rows bound to settingsStore:
//      * Haptics (iphone.radiowaves.left.and.right) → settingsStore.hapticsEnabled (default true)
//      * Sound effects (speaker.wave.2.fill) → settingsStore.sfxEnabled (default false)
//    - DATA card (P4 verbatim per D-16) — Export / Import / Reset stats rows
//    - ABOUT card (NEW P5) — Version (mono digits) / Privacy (inline disclosure)
//      / Acknowledgments (NavigationLink to AcknowledgmentsView)
//
//  Phase 5 invariants (additive — preserves all P4 invariants below):
//    - SettingsToggleRow uses the Toggle(label, isOn:) initializer (NOT the
//      empty-string label initializer) so VoiceOver reads "Haptics, switch
//      button, on/off" per UI-SPEC line 174-175
//      (A11Y-02 + threat T-05-17 lock); .labelsHidden() hides the duplicate
//      visible label (the leading Text(label) already shows it sighted-side)
//    - Version row reads Bundle.main.infoDictionary defensively with fallbacks
//      (T-05-12 mitigation against malformed Info.plist)
//    - AcknowledgmentsView extracted to sibling file per CLAUDE.md §8.1 to keep
//      this file under the ~400-line soft cap
//
//  Phase 4 invariants (preserved verbatim per D-16):
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

    @Environment(\.settingsStore) private var settingsStore

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
                    audioSection
                    SettingsSyncSection(theme: theme)
                    dataSection
                    SettingsAboutSection(theme: theme)
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
        // P5 (D-14, SHELL-02 + CLAUDE.md §2 theme picker UX convention):
        // System/Light/Dark mode picker + 5 Classic preset swatches inline +
        // NavigationLink to FullThemePickerView.
        settingsSectionHeader(theme: theme, String(localized: "APPEARANCE"))
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                Picker(
                    String(localized: "Appearance mode"),
                    selection: Binding(
                        get: { themeManager.mode },
                        set: { themeManager.mode = $0 }
                    )
                ) {
                    Text(String(localized: "System")).tag(ThemeMode.system)
                    Text(String(localized: "Light")).tag(ThemeMode.light)
                    Text(String(localized: "Dark")).tag(ThemeMode.dark)
                }
                .pickerStyle(.segmented)
                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)
                DKThemePicker(
                    themeManager: themeManager,
                    theme: theme,
                    scheme: colorScheme,
                    catalog: PresetCatalog.core,
                    maxGridHeight: nil,
                    grouped: false
                )
                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)
                NavigationLink(destination: FullThemePickerView()) {
                    settingsNavRow(
                        theme: theme,
                        title: String(localized: "More themes & custom colors")
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var audioSection: some View {
        // P5 (D-15): two SettingsToggleRow rows bound to settingsStore.
        // Haptics defaults true (D-10 premium feel); SFX defaults false
        // (D-10 / ROADMAP SC2 — sound is opt-in).
        settingsSectionHeader(theme: theme, String(localized: "AUDIO"))
        DKCard(theme: theme) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    theme: theme,
                    glyph: "iphone.radiowaves.left.and.right",
                    label: String(localized: "Haptics"),
                    isOn: Bindable(settingsStore).hapticsEnabled
                )
                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)
                SettingsToggleRow(
                    theme: theme,
                    glyph: "speaker.wave.2.fill",
                    label: String(localized: "Sound effects"),
                    isOn: Bindable(settingsStore).sfxEnabled
                )
            }
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

// MARK: - File-private SettingsToggleRow (UI-SPEC §Component Inventory + A11Y-02)

/// AUDIO toggle row: SF Symbol leading + label + system Toggle trailing.
/// Mirrors `SettingsActionRow` shape; differs by carrying a Toggle binding.
///
/// **A11Y-02 lock (UI-SPEC line 174-175 + threat T-05-17):**
/// `Toggle(label, isOn: $isOn)` — NOT the empty-string label initializer.
/// The label parameter is what `.labelsHidden()` HIDES VISUALLY but is what
/// VoiceOver READS. Passing `label` produces "Haptics, switch button, on" /
/// "Sound effects, switch button, on" matching UI-SPEC §A11y rows 174-175
/// verbatim. The leading visible `Text(label)` already shows the label
/// sighted-side, so `.labelsHidden()` keeps the system Toggle from
/// rendering its own duplicate label — no visual change vs. an empty label,
/// only the a11y string differs.
private struct SettingsToggleRow: View {
    let theme: Theme
    let glyph: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            Image(systemName: glyph)
                .foregroundStyle(theme.colors.textTertiary)
            Text(label)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            Toggle(label, isOn: $isOn)
                .labelsHidden()
                .tint(theme.colors.accentPrimary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// AcknowledgmentsView lives in `Screens/AcknowledgmentsView.swift` (extracted
// per CLAUDE.md §8.1 to keep this file under the ~400-line soft cap).
// SettingsAboutSection lives in `Screens/SettingsAboutSection.swift` (extracted
// 2026-05-01 to keep this file under the §8.5 hard 500-line cap).
