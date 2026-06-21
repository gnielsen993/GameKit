//
//  HomeVideoModeSheet.swift
//  gamekit
//
//  Home-surface entry point for Video Mode. Keeps the flagship control out of
//  the buried Settings path while reusing the existing location picker.
//

import SwiftUI
import DesignKit

struct HomeVideoModeButton: View {
    let theme: Theme
    let action: () -> Void

    @Environment(\.videoModeStore) private var videoModeStore

    var body: some View {
        Button(action: action) {
            Image(systemName: "pip")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(
                    videoModeStore.isEnabled
                    ? theme.colors.accentPrimary
                    : theme.colors.textPrimary
                )
                .frame(width: theme.spacing.xxl, height: theme.spacing.xxl)
                .background(
                    Circle()
                        .fill(videoModeStore.isEnabled ? theme.colors.accentPrimary.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "Video Mode")))
        .accessibilityValue(Text(statusText))
    }

    private var statusTint: Color {
        videoModeStore.isEnabled ? theme.colors.accentPrimary : theme.colors.textTertiary
    }

    private var statusText: String {
        videoModeStore.isEnabled ? videoModeStore.location.localizedLabel : String(localized: "Off")
    }
}

struct HomeVideoModeSheet: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.videoModeStore) private var videoModeStore

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    modeCard

                    if videoModeStore.isEnabled {
                        VideoLocationPickerView(showsNavigationChrome: false)
                    } else {
                        offState
                    }
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Video Mode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var modeCard: some View {
        DKCard(theme: theme) {
            Toggle(isOn: Bindable(videoModeStore).isEnabled) {
                HStack(spacing: theme.spacing.s) {
                    Image(systemName: "pip")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(
                            videoModeStore.isEnabled
                            ? theme.colors.accentPrimary
                            : theme.colors.textSecondary
                        )
                        .frame(width: theme.spacing.xl)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Video Mode"))
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textPrimary)
                        Text(statusText)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
            }
            .toggleStyle(.switch)
        }
    }

    private var offState: some View {
        DKCard(theme: theme) {
            HStack(alignment: .top, spacing: theme.spacing.s) {
                Image(systemName: "rectangle.on.rectangle.slash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(width: theme.spacing.xl)

                Text(String(localized: "Turn on Video Mode to choose where the video window sits while you play."))
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusText: String {
        videoModeStore.isEnabled ? videoModeStore.location.localizedLabel : String(localized: "Off")
    }
}
