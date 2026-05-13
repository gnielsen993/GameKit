//
//  VideoCompactControlRow.swift
//  gamekit
//
//  Shared compact control row for Video Mode games (per VIDEO-04 / Phase 9 SC4).
//  Generic @ViewBuilder closure slots — every game's Phase 11/12 adoption
//  passes its own primary info chip / picker / secondary info chip into the
//  same slot order:  Back | primary info | picker | secondary info | settings.
//
//  Phase 9 invariants:
//    - Generic @ViewBuilder slots (Topic 1 verdict) — NOT a typed struct of
//      type-erased views, NOT environment-injected slot bindings. Matches DKCard shape.
//    - All dimensions read DesignKit tokens (Phase 8 D-13):
//        pill radius   = theme.radii.button
//        pill height   = theme.spacing.xl
//        inter-item    = theme.spacing.s
//        chip radius   = theme.radii.chip
//        chip height   = theme.spacing.l
//      No literal cornerRadius: / padding(N) integers anywhere in this file.
//      Core/ is exempt from the pre-commit hook (CLAUDE.md §8 — hook targets
//      Games/ + Screens/) but token discipline carries.
//    - Preview block at bottom shows all 3 game slot mappings (Mines /
//      Merge / Nonogram per Phase 8 D-08) — SC4 satisfaction (D-04).
//      No DEBUG-only standalone screen, no HomeView dev hook — D-04 lock.
//

import SwiftUI
import DesignKit

struct VideoCompactControlRow<Primary: View, Picker: View, Secondary: View>: View {
    let theme: Theme
    let onBack: () -> Void
    let onSettings: () -> Void
    @ViewBuilder let primaryInfo: () -> Primary
    @ViewBuilder let picker: () -> Picker
    @ViewBuilder let secondaryInfo: () -> Secondary

    var body: some View {
        HStack(spacing: theme.spacing.s) {           // D-13 inter-item gap
            backButton
            primaryInfo()
            picker()
            secondaryInfo()
            settingsButton
        }
        .frame(height: theme.spacing.xl)             // D-13 pill height anchor
    }

    @ViewBuilder
    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
        }
        .accessibilityLabel(Text(String(localized: "Back")))
    }

    @ViewBuilder
    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "gearshape")
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
        }
        .accessibilityLabel(Text(String(localized: "Settings")))
    }
}

// MARK: - Preview

#Preview {
    // 3 game slot mappings per Phase 8 D-08 (SC4 satisfaction per D-04).
    // Theme constructed via the canonical DesignKit resolver
    // (Theme.resolve(preset:scheme:)) — same shape SettingsView reads at runtime.
    let theme = Theme.resolve(preset: .classicMuted, scheme: .light)
    return VStack(spacing: theme.spacing.l) {
        // Minesweeper: Back | Flags/mines | Reveal/Flag picker | Time | Settings
        VideoCompactControlRow(
            theme: theme,
            onBack: {},
            onSettings: {}
        ) {
            PreviewChip(theme: theme, glyph: "flag.fill", label: "10")     // primary: flags/mines
        } picker: {
            PreviewPicker(theme: theme, label: "Reveal/Flag")               // Reveal/Flag
        } secondaryInfo: {
            PreviewChip(theme: theme, glyph: "timer", label: "1:23")        // secondary: time
        }

        // Merge: Back | Score | Mode picker | Best/time | Settings
        VideoCompactControlRow(
            theme: theme,
            onBack: {},
            onSettings: {}
        ) {
            PreviewChip(theme: theme, glyph: "number", label: "2048")       // primary: score
        } picker: {
            PreviewPicker(theme: theme, label: "Mode picker")               // Mode picker
        } secondaryInfo: {
            PreviewChip(theme: theme, glyph: "star.fill", label: "Best")    // secondary: best/time
        }

        // Nonogram: Back | Lives/size | Fill/Mark picker | Time | Settings
        VideoCompactControlRow(
            theme: theme,
            onBack: {},
            onSettings: {}
        ) {
            PreviewChip(theme: theme, glyph: "heart.fill", label: "3 / 5x5") // primary: lives/size
        } picker: {
            PreviewPicker(theme: theme, label: "Fill/Mark")                  // Fill/Mark
        } secondaryInfo: {
            PreviewChip(theme: theme, glyph: "timer", label: "2:45")         // secondary: time
        }
    }
    .padding(theme.spacing.l)
    .background(theme.colors.background)
}

// MARK: - Preview helpers (private — not exported, used only by the preview)

private struct PreviewChip: View {
    let theme: Theme
    let glyph: String
    let label: String
    var body: some View {
        HStack(spacing: theme.spacing.s) {
            Image(systemName: glyph)
            Text(label)
        }
        .foregroundStyle(theme.colors.textPrimary)
        .padding(.horizontal, theme.spacing.s)
        .frame(height: theme.spacing.l)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
    }
}

private struct PreviewPicker: View {
    let theme: Theme
    let label: String
    var body: some View {
        Text(label)
            .foregroundStyle(theme.colors.textPrimary)
            .padding(.horizontal, theme.spacing.m)
            .frame(height: theme.spacing.xl)
            .background(theme.colors.accentPrimary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
    }
}
