//
//  SettingsPieceTuningSection.swift
//  gamekit
//
//  DEBUG-only piece strength picker (Phase 19.1). Compiled out of Release.
//  The preview row uses the same piece style as the game, so the change is
//  visible in place without leaving Settings. Removed with PieceTuning.swift
//  after the device pick.
//

#if DEBUG

import SwiftUI
import DesignKit

struct SettingsPieceTuningSection: View {
    let theme: Theme

    @AppStorage(PieceStrength.defaultsKey) private var strengthRaw: String = PieceStrength.medium.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            settingsSectionHeader(theme: theme, "DEBUG · PIECE STRENGTH")
            DKCard(theme: theme) {
                VStack(alignment: .leading, spacing: theme.spacing.m) {
                    Picker(selection: $strengthRaw) {
                        ForEach(PieceStrength.allCases) { strength in
                            Text(verbatim: strength.title).tag(strength.rawValue)
                        }
                    } label: {
                        Text(verbatim: "Strength")
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: theme.spacing.s) {
                        ForEach(1...3, id: \.self) { n in
                            Button {} label: {
                                Text(verbatim: "\(n)")
                                    .font(RoundedType.font(.title2, weight: .bold))
                                    .foregroundStyle(theme.colors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, theme.spacing.s)
                            }
                            .buttonStyle(.piece(
                                theme: theme,
                                shape: .rounded(theme.radii.chip),
                                size: .regular
                            ))
                        }
                    }

                    Button {} label: {
                        Text(verbatim: "Large piece")
                            .font(RoundedType.font(.headline, weight: .bold))
                            .foregroundStyle(theme.colors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacing.m)
                    }
                    .buttonStyle(.piece(
                        theme: theme,
                        role: .filled(theme.colors.accentPrimary),
                        shape: .rounded(theme.radii.button),
                        size: .large
                    ))
                }
            }
        }
    }
}

#endif
