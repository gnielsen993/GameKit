//
//  StackGameView+Chrome.swift
//  gamekit
//
//  Chrome surfaces for StackGameView, split out per the §8.1 file-size cap:
//  score/streak overlay, idle tap-to-start card, game-over banner content,
//  and the back-chevron toolbar pieces. Pure presentation — all state and
//  lifecycle stay in StackGameView.swift.
//

import SwiftUI
import DesignKit

extension StackGameView {

    // MARK: - Game-over banner content

    var gameOverContent: VideoModeBannerContent {
        VideoModeBannerContent(
            outcome: .loss,
            title: String(localized: "Game over"),
            subtitle: nil,
            primaryButtonLabel: String(localized: "Restart"),
            accessibilityLabel: String(
                format: String(localized: "Game over. Score %d. Restart"),
                vm.frame.score
            ),
            onPrimary: {
                vm.restart()
                showBanner = false
            }
        )
    }

    // MARK: - Chrome overlays

    /// Score + visible streak counter (D-04). Corner is parameterized for
    /// Video Mode Small zones (overlay packs opposite the PiP per DESIGN
    /// §7.2); off-path always passes `.topTrailing` — the v1.5 baseline.
    @ViewBuilder func scoreOverlay(alignment: Alignment) -> some View {
        let leadingSide = (alignment == .topLeading || alignment == .bottomLeading)
        VStack(alignment: leadingSide ? .leading : .trailing, spacing: theme.spacing.xs) {
            Text("\(vm.frame.score)")
                .font(theme.typography.title.monospacedDigit())
                .foregroundStyle(theme.colors.textPrimary)
            if vm.frame.streak > 0 {
                Text(String(localized: "Streak: \(vm.frame.streak)"))
                    .font(theme.typography.caption.monospacedDigit())
                    .foregroundStyle(theme.colors.accentPrimary)
            }
        }
        .padding(theme.spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .allowsHitTesting(false)   // board overlays never intercept taps (DESIGN §7.1)
    }

    /// Idle / tap-to-start screen — shown before the first tap and after restart.
    @ViewBuilder var idleContent: some View {
        VStack(spacing: theme.spacing.l) {
            Text(String(localized: "Stack"))
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)
            Text(String(localized: "Tap anywhere to start"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
            DKButton(String(localized: "Start"), theme: theme) {
                vm.start()
            }
            .frame(maxWidth: 220)
        }
        .padding(theme.spacing.xl)
        // Card backing — the idle overlay sits on the tower pedestal, so it
        // needs a surface behind it for contrast on every preset.
        .background(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(theme.colors.surfaceElevated.opacity(0.94))
        )
        .padding(theme.spacing.l)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder var backChevron: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            backButton
        }
    }

    /// Back chevron button body — shared between the off-path toolbar and
    /// the Small-zone routed toolbar (StackGameView+VideoMode.swift).
    var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back to The Drawer"))
    }
}
