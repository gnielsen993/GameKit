//
//  VideoLocationPickerView.swift
//  gamekit
//
//  Push-destination sub-screen for the VIDEO MODE Settings card's
//  NavigationLink (D-08). Renders a footprint-accurate picker: each
//  highlighted zone inside the iPhone outline represents the ACTUAL
//  rectangle the video will occupy on the player's screen — not a full-band
//  card. The empty area between zones is the gameplay surface.
//
//    [ Large | Small ]   ← segmented size toggle
//    ╭──────────────╮   ← iPhone outline (RoundedRectangle stroke,
//    │ ┌──────────┐ │     theme.radii.sheet, ~9:19.5 aspect)
//    │ │ video    │ │   ← Large-mode: top footprint (~28% height)
//    │ └──────────┘ │
//    │              │   ← empty gameplay gap (~44% height)
//    │ ┌──────────┐ │
//    │ │ video    │ │   ← Large-mode: bottom footprint (~28% height)
//    │ └──────────┘ │
//    ╰──────────────╯
//
//  In Small mode the outline shows four corner thumbnails (~32% × ~15% of
//  the inner area) anchored to each corner — the small video docks to one
//  of the four corners, with empty space everywhere else. Switching the
//  toggle preserves the user's Top/Bottom vertical half so the change feels
//  like a size swap, not a re-selection.
//
//  Layout uses GeometryReader inside the fixed-aspect outline so the
//  zones scale proportionally with the outline regardless of device width
//  — exactly the use case GeometryReader is intended for (proportional
//  placement inside a fixed-aspect-ratio container).
//
//  Phase 9 invariants (still in force):
//    - Push destination only — no own NavigationStack (Settings owns it).
//    - @Environment(\.videoModeStore) — NEVER @EnvironmentObject (Pitfall 2).
//    - All literal-pt dimensions read DesignKit tokens; ratios used inside
//      GeometryReader proportional math are acceptable as Double literals
//      (they're aspect ratios, not pixel values) per CLAUDE.md §2.
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
    private let showsNavigationChrome: Bool

    init(showsNavigationChrome: Bool = true) {
        self.showsNavigationChrome = showsNavigationChrome
        // Default initial; replaced in .onAppear from the store so the toggle
        // matches the actual persisted selection on first render.
        _size = State(initialValue: .large)
    }

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            sizeToggle

            iPhoneOutlineFrame {
                GeometryReader { proxy in
                    zoneFootprintLayer(in: proxy.size)
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
        .padding(showsNavigationChrome ? theme.spacing.l : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if showsNavigationChrome {
                theme.colors.background.ignoresSafeArea()
            }
        }
        .modifier(VideoLocationNavigationChrome(
            enabled: showsNavigationChrome,
            title: String(localized: "videoMode.pickerTitle")
        ))
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

    // MARK: - Footprint layer

    /// Footprint ratios (Double literals are aspect ratios, not pixel values —
    /// see header note on the CLAUDE.md §2 escape hatch). These describe what
    /// fraction of the iPhone outline's INNER area each video footprint
    /// occupies, so the user reads each highlighted zone as "the video goes
    /// HERE on this part of the screen" instead of as a full-band card.
    ///
    /// Large mode: two rectangles, full inner width, each ~28% of inner
    /// height — leaves a ~44% gap in the middle (the gameplay area).
    ///
    /// Small mode: four rectangles, each ~32% × ~15% of inner area, pinned
    /// to each corner with a small inset — the rest of the screen stays
    /// empty (no full-band background).
    private static let largeFootprintHeightRatio: CGFloat = 0.28
    private static let smallFootprintWidthRatio:  CGFloat = 0.32
    private static let smallFootprintHeightRatio: CGFloat = 0.15

    /// Renders the appropriate set of footprint zones for the current size
    /// inside the supplied inner-geometry size (after the outline's inner
    /// padding has been applied by the GeometryReader's frame).
    @ViewBuilder
    private func zoneFootprintLayer(in size: CGSize) -> some View {
        switch self.size {
        case .large:
            largeFootprints(in: size)
        case .small:
            smallFootprints(in: size)
        }
    }

    private func largeFootprints(in size: CGSize) -> some View {
        let zoneHeight = size.height * Self.largeFootprintHeightRatio
        return ZStack(alignment: .top) {
            // Top footprint — anchored to outline top
            zoneButton(location: .largeTop) {
                zoneLabel(location: .largeTop)
            }
            .frame(width: size.width, height: zoneHeight)
            .frame(maxHeight: .infinity, alignment: .top)

            // Bottom footprint — anchored to outline bottom
            zoneButton(location: .largeBottom) {
                zoneLabel(location: .largeBottom)
            }
            .frame(width: size.width, height: zoneHeight)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: size.width, height: size.height)
    }

    private func smallFootprints(in size: CGSize) -> some View {
        let zoneWidth  = size.width  * Self.smallFootprintWidthRatio
        let zoneHeight = size.height * Self.smallFootprintHeightRatio
        return ZStack {
            // Top-left corner
            zoneButton(location: .smallTopLeft) {
                zoneLabel(location: .smallTopLeft)
            }
            .frame(width: zoneWidth, height: zoneHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Top-right corner
            zoneButton(location: .smallTopRight) {
                zoneLabel(location: .smallTopRight)
            }
            .frame(width: zoneWidth, height: zoneHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // Bottom-left corner
            zoneButton(location: .smallBottomLeft) {
                zoneLabel(location: .smallBottomLeft)
            }
            .frame(width: zoneWidth, height: zoneHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // Bottom-right corner
            zoneButton(location: .smallBottomRight) {
                zoneLabel(location: .smallBottomRight)
            }
            .frame(width: zoneWidth, height: zoneHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(width: size.width, height: size.height)
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
        // Both selected and non-selected zones read as highlighted footprints
        // (per the patch spec — "all four visible simultaneously as highlighted
        // tap targets"). Selected = bolder fill + thicker accent stroke;
        // non-selected = lighter fill + thin accent stroke so the empty space
        // between zones still reads as the empty gameplay area.
        Button {
            videoModeStore.location = location
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                    .fill(theme.colors.accentPrimary.opacity(isSelected ? 0.28 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                            .stroke(
                                theme.colors.accentPrimary.opacity(isSelected ? 1.0 : 0.45),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                label()
            }
            .contentShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
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
            // Small zones are ~32%×15% of inner outline → ~64×69pt on the
            // capped iPhone-outline width. Use caption + minimumScaleFactor so
            // the "Your video will go here" copy fits without truncation, and
            // allow up to 3 lines for the smaller footprint.
            let isSmallZone = (self.size == .small)
            Text(String(localized: "videoMode.zoneFillLabel"))
                .font((isSmallZone ? theme.typography.caption : theme.typography.body).weight(.bold))
                .foregroundStyle(theme.colors.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(isSmallZone ? 3 : 2)
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

private struct VideoLocationNavigationChrome: ViewModifier {
    let enabled: Bool
    let title: String

    func body(content: Content) -> some View {
        if enabled {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
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
