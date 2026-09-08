import SwiftUI
import DesignKit

struct MathCrosswordNumberBank: View {
    let theme: Theme
    let values: [Int]
    let selectedCell: Bool
    let onPlace: (Int) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSide: CGFloat = 44

    var body: some View {
        if values.isEmpty {
            Text("Every tile is on the board.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel(Text("Every number tile is on the board"))
        } else if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                HStack(spacing: theme.spacing.xs) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        tile(value).frame(width: tileSide, height: tileSide)
                    }
                }
            }
            .frame(height: tileSide)
            .padding(.horizontal, theme.spacing.m)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 44), spacing: theme.spacing.xs)],
                spacing: theme.spacing.xs
            ) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    tile(value)
                }
            }
            .padding(.horizontal, theme.spacing.m)
        }
    }

    private func tile(_ value: Int) -> some View {
        Button { onPlace(value) } label: {
            Text("\(value)")
                .font(theme.typography.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(selectedCell ? theme.colors.textPrimary : theme.colors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                        .stroke(theme.colors.border, lineWidth: 1)
                )
                .chipShadow()
        }
        .buttonStyle(.pressable)
        .disabled(!selectedCell)
        .accessibilityLabel(Text("Place \(value)"))
    }
}
