import SwiftUI
import DesignKit

struct MathCrosswordNumberBank: View {
    let theme: Theme
    let values: [Int]
    let compact: Bool
    let selectedCell: Bool
    let onPlace: (Int) -> Void
    let onDragChanged: (Int, CGPoint) -> Void
    let onDragEnded: (Int, CGPoint) -> Void

    var body: some View {
        if values.isEmpty {
            Text("Every tile is on the board.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textTertiary)
                .frame(maxWidth: .infinity, minHeight: compact ? theme.spacing.xxl : 44)
                .accessibilityLabel(Text("Every number tile is on the board"))
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.xs) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        tile(value).frame(width: theme.spacing.xxl)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: theme.spacing.xxl), spacing: theme.spacing.xs)],
                    spacing: theme.spacing.xs
                ) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        tile(value)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, theme.spacing.m)
        }
    }

    private func tile(_ value: Int) -> some View {
        Button { if selectedCell { onPlace(value) } } label: {
            Text("\(value)")
                .font(theme.typography.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: compact ? theme.spacing.xxl : 44)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                        .stroke(theme.colors.border, lineWidth: 1)
                )
                .chipShadow()
        }
        .buttonStyle(.pressable)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: theme.spacing.s, coordinateSpace: .named(MathCrosswordCoordinateSpace.name))
                .onChanged { onDragChanged(value, $0.location) }
                .onEnded { onDragEnded(value, $0.location) }
        )
        .accessibilityLabel(Text("Place \(value)"))
        .accessibilityHint(Text("Drag to a blank, or select a blank before tapping"))
    }
}
