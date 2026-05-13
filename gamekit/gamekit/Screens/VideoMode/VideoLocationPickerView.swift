//
//  VideoLocationPickerView.swift
//  gamekit
//
//  Push-destination sub-screen for the VIDEO MODE Settings card's
//  NavigationLink (D-08). Renders a visual iPhone-outline picker per D-02:
//  6 tappable zones in the locked PiP vocabulary, the selected zone fills
//  with theme.colors.accentPrimary.opacity(0.25) and shows
//  "Your video will go here". Below the outline, VIDEO-14 verbatim copy
//  (D-10) explains "GameDrawer can't detect your video automatically".
//
//  Phase 9 invariants:
//    - Push destination only — no own NavigationStack (Settings owns it).
//    - @Environment(\.videoModeStore) — NEVER @EnvironmentObject (Pitfall 2).
//    - GeometryReader + .aspectRatio for the outline (RESEARCH Topic 2).
//      NOT SwiftUI Grid (zones are irregular: 2 full-width bands + 4 corners).
//    - All dimensions read DesignKit tokens; no literal cornerRadius/padding
//      integers (Screens/ pre-commit hook enforces — Pitfall 4).
//    - A11Y per D-09: per-zone .accessibilityLabel matching localized
//      vocabulary + .accessibilityValue (selection state) + .isButton trait.
//      Container: .accessibilityElement(children: .contain) + container label.
//

import SwiftUI
import DesignKit

struct VideoLocationPickerView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.videoModeStore) private var videoModeStore

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                iPhoneOutline(
                    theme: theme,
                    selected: videoModeStore.location,
                    onSelect: { newLocation in
                        videoModeStore.location = newLocation
                    }
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(String(localized: "videoMode.pickerContainerA11yLabel")))

                Text(String(localized: "videoMode.manualSelectionExplanation"))
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(theme.spacing.l)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(String(localized: "videoMode.pickerTitle"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - iPhone outline (GeometryReader proportions, NOT SwiftUI Grid)

private struct iPhoneOutline: View {
    let theme: Theme
    let selected: VideoModeLocation
    let onSelect: (VideoModeLocation) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let bandH = h * 0.25
            let midH = h * 0.50
            let cornerW = w * 0.40
            let cornerH = midH * 0.45

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: theme.radii.sheet, style: .continuous)
                    .fill(theme.colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radii.sheet, style: .continuous)
                            .stroke(theme.colors.border, lineWidth: 1)
                    )

                VStack(spacing: 0) {
                    zone(.largeTop)
                        .frame(width: w, height: bandH)

                    HStack(spacing: 0) {
                        VStack(spacing: theme.spacing.s) {
                            zone(.smallTopLeft)
                                .frame(width: cornerW, height: cornerH)
                            zone(.smallBottomLeft)
                                .frame(width: cornerW, height: cornerH)
                        }
                        Spacer()
                        VStack(spacing: theme.spacing.s) {
                            zone(.smallTopRight)
                                .frame(width: cornerW, height: cornerH)
                            zone(.smallBottomRight)
                                .frame(width: cornerW, height: cornerH)
                        }
                    }
                    .frame(width: w, height: midH)
                    .padding(.horizontal, theme.spacing.s)

                    zone(.largeBottom)
                        .frame(width: w, height: bandH)
                }
            }
        }
        .aspectRatio(9.0 / 19.5, contentMode: .fit)
    }

    @ViewBuilder
    private func zone(_ loc: VideoModeLocation) -> some View {
        Button {
            onSelect(loc)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                    .fill(selected == loc
                          ? theme.colors.accentPrimary.opacity(0.25)
                          : Color.clear)
                if selected == loc {
                    Text(String(localized: "videoMode.zoneFillLabel"))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(theme.spacing.xs)
                }
            }
        }
        .accessibilityLabel(Text(loc.localizedLabel))
        .accessibilityValue(Text(selected == loc ? String(localized: "Selected") : ""))
        .accessibilityAddTraits(.isButton)
    }
}
