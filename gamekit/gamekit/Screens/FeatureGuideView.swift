import SwiftUI
import DesignKit

/// Standalone feature list — mirrors the onboarding welcome page.
/// Accessible from Settings → About so users can revisit what the app offers.
struct FeatureGuideView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(GameDrawerFeature.all) { feature in
                    featureRow(feature)
                    if feature.id != GameDrawerFeature.all.last?.id {
                        Divider()
                            .padding(.leading, 48 + theme.spacing.m * 2)
                    }
                }
            }
            .padding(.horizontal, theme.spacing.l)
            .padding(.vertical, theme.spacing.m)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(String(localized: "Feature Guide"))
        .navigationBarTitleDisplayMode(.large)
    }

    private func featureRow(_ feature: GameDrawerFeature) -> some View {
        HStack(spacing: theme.spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .fill(theme.colors.accentPrimary.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(theme.colors.accentPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(theme.typography.body.weight(.semibold))
                    .foregroundStyle(theme.colors.accentPrimary)
                Text(feature.description)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, theme.spacing.s)
    }
}
