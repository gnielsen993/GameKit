//
//  SnakeGameView+Chrome.swift
//  gamekit
//
//  Chrome surfaces for SnakeGameView, split out per the §8.1 file-size cap:
//  game-over banner content, idle card, back-chevron + wall-mode toolbar pieces,
//  and the always-visible D-pad (SnakeDPad). Pure presentation — all state and
//  lifecycle stay in SnakeGameView.swift.
//
//  Token discipline: all colors via theme.colors.* only (CLAUDE.md §1, SNAKE-06).
//

import SwiftUI
import DesignKit

// MARK: - SnakeGameView Chrome extension

extension SnakeGameView {

    // MARK: Game-over banner content (DESIGN §3.6)

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

    // MARK: Idle content (DESIGN §8.3 explicit idle state)

    @ViewBuilder var idleContent: some View {
        VStack(spacing: theme.spacing.l) {
            Text(String(localized: "Snake"))
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)
            Text(String(localized: "Swipe or tap D-pad to start"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
            DKButton(String(localized: "Start"), theme: theme) {
                vm.start()
            }
            .frame(maxWidth: 220)
        }
        .padding(theme.spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(theme.colors.surfaceElevated.opacity(0.94))
        )
        .padding(theme.spacing.l)
    }

    // MARK: Toolbar (DESIGN §6)

    /// Back chevron button body — placement is parameterized in
    /// `standardLayout(backPlacement:)` so Video Mode small-top zones can
    /// re-anchor it away from a covering PiP (necessity principle, §7.7).
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

    /// Wall-mode toggle menu (D-11). The label shows the current state so the
    /// player can see at a glance which mode is active. Tapping always calls
    /// requestWallModeToggle() — if a run is in progress the VM surfaces the
    /// abandon alert; if idle it applies the toggle immediately. Placement is
    /// parameterized in `standardLayout(menuPlacement:)` (see backButton).
    var wallModeMenu: some View {
        Menu {
            Button(vm.wallMode
                   ? String(localized: "Wall mode: On")
                   : String(localized: "Wall mode: Off")) {
                vm.requestWallModeToggle()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Options"))
    }
}

// MARK: - SnakeDPad

/// Always-visible directional pad, placed in the mode-pill slot below the board
/// (DESIGN §5.4). Each button has a ≥44pt hit target (DESIGN §3.3 / §9).
///
/// All four buttons stay enabled at all times — the 180° reversal rejection and
/// capacity cap live in the VM's direction queue, so the D-pad itself never
/// needs to know the current heading. A rejected input fires no haptic (D-07).
struct SnakeDPad: View {
    let theme: Theme
    let onDirection: (SnakeDirection) -> Void

    var body: some View {
        VStack(spacing: theme.spacing.xs) {
            // Up row — centered
            dpadButton(.up, systemImage: "chevron.up")

            // Left / Right row
            HStack(spacing: theme.spacing.xs) {
                dpadButton(.left, systemImage: "chevron.left")
                // Center gap matches button width so the cross reads as a D-pad
                Color.clear.frame(width: 44, height: 44)
                dpadButton(.right, systemImage: "chevron.right")
            }

            // Down row — centered
            dpadButton(.down, systemImage: "chevron.down")
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func dpadButton(_ dir: SnakeDirection, systemImage: String) -> some View {
        Button {
            onDirection(dir)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 44, height: 44)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                        .stroke(theme.colors.border, lineWidth: 1)
                )
                .chipShadow()
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(accessibilityLabel(dir))
    }

    private func accessibilityLabel(_ dir: SnakeDirection) -> String {
        switch dir {
        case .up:    return String(localized: "Move up")
        case .down:  return String(localized: "Move down")
        case .left:  return String(localized: "Move left")
        case .right: return String(localized: "Move right")
        }
    }
}
