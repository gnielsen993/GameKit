//
//  VideoLocationPickerView.swift
//  gamekit
//
//  Push-destination sub-screen for the VIDEO MODE Settings card's
//  NavigationLink (D-08). Renders a vertical-stack picker per the Phase 9
//  human-verify gap-closure redesign, wrapped in an iPhone-outline frame so
//  the bands have spatial meaning ("this is your phone, your video appears
//  HERE on it") rather than reading as floating cards:
//
//    [ Large | Small ]   ← segmented size toggle
//    ╭──────────────╮   ← iPhone outline (RoundedRectangle stroke,
//    │ ┌──────────┐ │     theme.radii.sheet, ~9:19.5 aspect)
//    │ │ Top band │ │   ← Large-mode: whole band tappable
//    │ ├──────────┤ │
//    │ │ Bot band │ │
//    │ └──────────┘ │
//    ╰──────────────╯
//
//  In Small mode each band contains TWO corner buttons (left+right) — the
//  small video docks to a corner of one of the two large bands, never floats
//  independently. Switching the toggle preserves the user's Top/Bottom
//  vertical half so the change feels like a size swap, not a re-selection.
//
//  Phase 9 invariants (still in force):
//    - Push destination only — no own NavigationStack (Settings owns it).
//    - @Environment(\.videoModeStore) — NEVER @EnvironmentObject (Pitfall 2).
//    - All dimensions read DesignKit tokens; no literal cornerRadius/padding
//      integers (CLAUDE.md §2 / Pitfall 4).
//    - Selected-zone label uses theme.colors.textPrimary, NOT accentPrimary
//      (Pitfall 5 lock — Loud presets remain legible).
//    - A11Y per D-09: per-zone .accessibilityLabel matching localized
//      vocabulary + .accessibilityValue (selection state) + .isButton trait.
//      Container: .accessibilityElement(children: .contain) + container label.
//    - VideoModeLocation enum is LOCKED (D-07): 6 cases, no largeMiddle.
//

import SwiftUI
import DesignKit

struct VideoLocationPickerView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.videoModeStore) private var videoModeStore

    /// User-facing size axis derived from `videoModeStore.location`.
    /// Kept in `@State` so the segmented control responds to taps immediately
    /// without forcing a write into the store on every flip — the actual
    /// location write happens when the user picks a zone in the new size.
    @State private var size: VideoSize

    init() {
        // Default initial; replaced in .onAppear from the store so the toggle
        // matches the actual persisted selection on first render.
        _size = State(initialValue: .large)
    }

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            sizeToggle

            iPhoneOutlineFrame {
                VStack(spacing: theme.spacing.m) {
                    bandView(for: .top)
                    bandView(for: .bottom)
                }
                .padding(theme.spacing.m)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(String(localized: "videoMode.pickerContainerA11yLabel")))

            Text(String(localized: "videoMode.manualSelectionExplanation"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(theme.spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(String(localized: "videoMode.pickerTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Sync toggle to whatever the store actually holds.
            size = VideoSize(for: videoModeStore.location)
        }
        .onChange(of: videoModeStore.location) { _, newLocation in
            // External writes (e.g. settings reset) keep the toggle honest.
            size = VideoSize(for: newLocation)
        }
        .onChange(of: size) { oldSize, newSize in
            guard oldSize != newSize else { return }
            // Preserve the user's vertical half (Top vs Bottom) when flipping
            // sizes — switching Large↔Small should feel like a size swap,
            // not a re-selection. Defaults to "right" corner on Small per
            // the D-03 spirit (largeBottom default → smallBottomRight when
            // the user shrinks).
            let half = VerticalHalf(for: videoModeStore.location)
            videoModeStore.location = defaultLocation(size: newSize, half: half)
        }
    }

    // MARK: - Size toggle

    private var sizeToggle: some View {
        Picker("", selection: $size) {
            Text(String(localized: "videoMode.locationPicker.sizeLarge"))
                .tag(VideoSize.large)
            Text(String(localized: "videoMode.locationPicker.sizeSmall"))
                .tag(VideoSize.small)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(Text(String(localized: "videoMode.locationPicker.sizeA11yLabel")))
    }

    // MARK: - Band

    @ViewBuilder
    private func bandView(for half: VerticalHalf) -> some View {
        switch size {
        case .large:
            largeBand(for: half)
        case .small:
            smallBand(for: half)
        }
    }

    private func largeBand(for half: VerticalHalf) -> some View {
        let location: VideoModeLocation = (half == .top) ? .largeTop : .largeBottom
        return zoneButton(location: location) {
            zoneLabel(location: location)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func smallBand(for half: VerticalHalf) -> some View {
        let leftLocation: VideoModeLocation = (half == .top) ? .smallTopLeft : .smallBottomLeft
        let rightLocation: VideoModeLocation = (half == .top) ? .smallTopRight : .smallBottomRight
        return HStack(spacing: theme.spacing.m) {
            zoneButton(location: leftLocation) {
                zoneLabel(location: leftLocation)
            }
            .frame(maxWidth: .infinity)
            zoneButton(location: rightLocation) {
                zoneLabel(location: rightLocation)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - iPhone outline frame

    /// Decorative iPhone-outline wrapper that gives the band stack spatial
    /// meaning — "this is your phone screen, your video appears HERE on it"
    /// — rather than letting the bands read as floating cards (the gap that
    /// the post-11d109a redesign accidentally introduced). The outline is
    /// a stroked `RoundedRectangle` with a ~9:19.5 aspect ratio (modest
    /// phone shape, matches the original 09-07 picker geometry). All
    /// chrome reads DesignKit tokens; stroke width is a small visual
    /// constant (1.5pt) since DesignKit does not surface a stroke-width
    /// token (CLAUDE.md §2 escape hatch for visual chrome).
    @ViewBuilder
    private func iPhoneOutlineFrame<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            content()
        }
        .aspectRatio(9.0 / 19.5, contentMode: .fit)
        .frame(maxWidth: theme.spacing.xxl * 7)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.sheet, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1.5)
                .accessibilityHidden(true)
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Zone button + label

    @ViewBuilder
    private func zoneButton<Label: View>(
        location: VideoModeLocation,
        @ViewBuilder label: () -> Label
    ) -> some View {
        let isSelected = (videoModeStore.location == location)
        Button {
            videoModeStore.location = location
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .fill(theme.colors.accentPrimary.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                            .stroke(
                                isSelected
                                    ? theme.colors.accentPrimary
                                    : theme.colors.border,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                label()
            }
            .contentShape(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(location.localizedLabel))
        .accessibilityValue(Text(isSelected ? String(localized: "Selected") : ""))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func zoneLabel(location: VideoModeLocation) -> some View {
        let isSelected = (videoModeStore.location == location)
        if isSelected {
            Text(String(localized: "videoMode.zoneFillLabel"))
                .font(theme.typography.body.weight(.bold))
                .foregroundStyle(theme.colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(theme.spacing.xs)
        }
    }

    // MARK: - Size → location defaulting

    /// When the user flips the size toggle without picking a zone, default to
    /// the canonical zone for that (size, half). Small defaults to the right
    /// corner (mirrors the D-03 default `.largeBottom` → `.smallBottomRight`
    /// shrink path).
    private func defaultLocation(size: VideoSize, half: VerticalHalf) -> VideoModeLocation {
        switch (size, half) {
        case (.large, .top):    return .largeTop
        case (.large, .bottom): return .largeBottom
        case (.small, .top):    return .smallTopRight
        case (.small, .bottom): return .smallBottomRight
        }
    }
}

// MARK: - Local enums

/// User-facing size axis surfaced by the segmented control. Derived from
/// `VideoModeLocation` — NOT a persisted shape (the persisted value stays
/// the 6-case enum per D-07 lock).
private enum VideoSize: Hashable {
    case large
    case small

    init(for location: VideoModeLocation) {
        switch location {
        case .largeTop, .largeBottom:
            self = .large
        case .smallTopLeft, .smallTopRight, .smallBottomLeft, .smallBottomRight:
            self = .small
        }
    }
}

/// Vertical half of the screen — used to preserve the user's Top/Bottom
/// choice when flipping the size toggle.
private enum VerticalHalf: Hashable {
    case top
    case bottom

    init(for location: VideoModeLocation) {
        switch location {
        case .largeTop, .smallTopLeft, .smallTopRight:
            self = .top
        case .largeBottom, .smallBottomLeft, .smallBottomRight:
            self = .bottom
        }
    }
}
