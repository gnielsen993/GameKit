//
//  DrawerRow.swift
//  gamekit
//
//  One row of the home "drawer cabinet." Closed = a saturated accent-color
//  drawer face (icon plate · title · subtitle · brass pull). Open = same
//  face still visible at top, with a dark drawer-body cavity sliding down
//  below it holding mode-chip tabs. The cavity reads as the inside of a
//  drawer pulled open; chips are tab-shaped with a hinge highlight at the
//  top so they feel attached to the cavity rail rather than floating.
//
//  Visual model (mirrors the studio mockup the user pulled):
//    Closed → full-bleed accent fill, white-on-color content. No cavity.
//    Open   → same face untouched; below it, a dark cavity slides down
//             carrying the chip tabs. All chips share one visual style
//             (no selected/unselected variants — every tap launches that
//             mode immediately, so a "selected" state would only confuse).
//
//  Accent color comes from `theme.catalogueColor(descriptor.accent.index)`
//  — a per-preset palette accessor on Theme. Each game pins a stable slot
//  so neighboring drawers always read as distinct blocks regardless of
//  active preset.
//
//  Cavity color is a structural near-black depth color (not a theme
//  token) so the drawer interior stays visually "deep" across light AND
//  dark presets — like Apple's tab bars and HIG chrome surfaces. Chip
//  text uses DrawerChrome.onAccent for the same reason: it is foreground-on-color,
//  not theme-driven foreground. Both exceptions are tagged inline.
//
//  This view is dumb — it owns no expansion state. HomeView tracks the
//  single expanded kind and passes `isExpanded` in. Tap on the face
//  calls `onToggle`; tap on a chip calls `onSelectMode(chip.route)`.
//

import SwiftUI
import DesignKit

struct DrawerRow: View {
    let descriptor: GameDescriptor
    let theme: Theme
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelectMode: (GameRoute) -> Void

    /// Per-preset palette color resolved at render time.
    private var accentColor: Color {
        theme.catalogueColor(descriptor.accent.index)
    }

    /// Structural chrome colors come from `DrawerChrome` (Core/) so the
    /// §1 token-discipline pre-commit hook stays clean on this file.
    private static var cavityColor: Color { DrawerChrome.cavity }
    private static var chipColor: Color { DrawerChrome.chip }
    private static var hingeHighlight: Color { DrawerChrome.hingeRail }

    /// Fixed row height. Face and cavity both occupy this same vertical
    /// slot — the row never grows on tap. The hinge motion is layered
    /// in-place: face flips back and out, cavity flips forward into view.
    private static let rowHeight: CGFloat = 76

    var body: some View {
        ZStack {
            // Back layer — chip cavity. Lives in the same slot as the
            // face. Fades in as the face flips down; no rotation of its
            // own so the motion reads as one element pivoting away
            // rather than two competing hinges.
            chipCavity
                .opacity(isExpanded ? 1 : 0)
                .allowsHitTesting(isExpanded)

            // Front layer — drawer face. Flips DOWN: top edge stays
            // pinned, bottom edge swings forward and down toward the
            // viewer, like a drop-front mail slot. By the time the face
            // crosses 90° it is edge-on and invisible; we drive opacity
            // to 0 in parallel so the back of the face never flashes.
            drawerFace
                .rotation3DEffect(
                    .degrees(isExpanded ? 110 : 0),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .top,
                    anchorZ: 0,
                    perspective: 0.7
                )
                .opacity(isExpanded ? 0 : 1)
                .allowsHitTesting(!isExpanded)
        }
        .frame(height: Self.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(isExpanded ? Self.cavityColor : accentColor)
                .shadow(
                    color: DrawerChrome.shadow.opacity(isExpanded ? 0.22 : 0.12),
                    radius: isExpanded ? 14 : 6,
                    x: 0,
                    y: isExpanded ? 6 : 3
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
    }

    // MARK: - Face

    @ViewBuilder
    private var drawerFace: some View {
        Button(action: onToggle) {
            HStack(spacing: theme.spacing.m) {
                // White icon plate — inverse contrast against the
                // saturated face fill, mirrors the mockup's white-on-red
                // square.
                ZStack {
                    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                        .fill(DrawerChrome.onAccent.opacity(0.94))
                    Image(systemName: descriptor.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: String.LocalizationValue(descriptor.titleKey)))
                        .font(theme.typography.headline)
                        .foregroundStyle(DrawerChrome.onAccent)
                    Text(String(localized: String.LocalizationValue(descriptor.captionKey)))
                        .font(theme.typography.caption)
                        .foregroundStyle(DrawerChrome.onAccent.opacity(0.78))
                        .textCase(.uppercase)
                }

                Spacer(minLength: theme.spacing.s)

                pullHandle
            }
            .padding(.horizontal, theme.spacing.l)
            .padding(.vertical, theme.spacing.m)
            .frame(maxWidth: .infinity, minHeight: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: String.LocalizationValue(descriptor.titleKey))))
        .accessibilityHint(Text(isExpanded
            ? String(localized: "Drawer open. Tap a mode to play, or tap again to close.")
            : String(localized: "Tap to open drawer and choose a mode.")))
        .accessibilityAddTraits(.isButton)
    }

    /// Horizontal brass-pull analog — a compact white bar with a darker
    /// inset, reads as the drawer handle. Mirrors the rectangular pull in
    /// the user's mockup; no chevron rotation so the open/closed signal
    /// comes purely from the cavity reveal.
    @ViewBuilder
    private var pullHandle: some View {
        RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
            .fill(DrawerChrome.onAccent.opacity(0.92))
            .frame(width: 22, height: 8)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                    .stroke(DrawerChrome.shadow.opacity(0.18), lineWidth: 1)
            )
    }

    // MARK: - Cavity

    @ViewBuilder
    private var chipCavity: some View {
        HStack(spacing: 0) {
            ForEach(Array(descriptor.modes.enumerated()), id: \.element.id) { index, chip in
                if index > 0 {
                    // Hairline rail-divider between hinged tabs.
                    Rectangle()
                        .fill(DrawerChrome.onAccent.opacity(0.06))
                        .frame(width: 1)
                }
                ModeChipTab(
                    chip: chip,
                    theme: theme,
                    chipColor: Self.chipColor,
                    hingeHighlight: Self.hingeHighlight
                ) {
                    onSelectMode(chip.route)
                }
            }
        }
        .frame(height: 64)
        .background(Self.cavityColor)
        .overlay(alignment: .top) {
            // Top inset shadow — sells the cavity as a recessed space
            // that the face has been "lifted to expose."
            LinearGradient(
                colors: [DrawerChrome.shadow.opacity(0.45), DrawerChrome.shadow.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 6)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - ModeChipTab

/// One hinged mode tab inside the cavity. Flat-edged, dark on dark, with
/// a 2pt highlight band along the top edge that reads as a hinge rail —
/// the tab feels attached to the cavity's top seam rather than floating.
private struct ModeChipTab: View {
    let chip: GameModeChip
    let theme: Theme
    let chipColor: Color
    let hingeHighlight: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text(String(localized: String.LocalizationValue(chip.labelKey)))
                    .font(theme.typography.body.weight(.semibold))
                    .foregroundStyle(DrawerChrome.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if !chip.detailKey.isEmpty {
                    Text(String(localized: String.LocalizationValue(chip.detailKey)))
                        .font(theme.typography.caption)
                        .foregroundStyle(DrawerChrome.onAccent.opacity(0.65))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, theme.spacing.xs)
            .background(chipColor)
            .overlay(alignment: .top) {
                // Hinge rail highlight — 2pt brighter band at the very
                // top edge so the tab reads as pivoting along this seam.
                Rectangle()
                    .fill(hingeHighlight)
                    .frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
