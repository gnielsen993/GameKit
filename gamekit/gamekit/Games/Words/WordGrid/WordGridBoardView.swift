import SwiftUI
import DesignKit

struct WordGridBoardView: View {
    let theme: Theme
    let board: [[Character]]
    let selectedPath: [WordGridPosition]
    let onSelect: (WordGridPosition) -> Void

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let spacing = theme.spacing.s
            let tileSide = (side - spacing * CGFloat(WordGridEngine.size - 1)) / CGFloat(WordGridEngine.size)
            let originX = (proxy.size.width - side) / 2
            let originY = (proxy.size.height - side) / 2

            ZStack(alignment: .topLeading) {
                ForEach(0..<WordGridEngine.size, id: \.self) { row in
                    ForEach(0..<WordGridEngine.size, id: \.self) { column in
                        let position = WordGridPosition(row: row, column: column)
                        tile(position)
                            .frame(width: tileSide, height: tileSide)
                            .position(
                                x: originX + CGFloat(column) * (tileSide + spacing) + tileSide / 2,
                                y: originY + CGFloat(row) * (tileSide + spacing) + tileSide / 2
                            )
                            .accessibilityLabel(Text("Letter \(letter(row: row, column: column)), row \(row + 1), column \(column + 1)"))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let position = position(
                            at: value.location,
                            originX: originX,
                            originY: originY,
                            tileSide: tileSide,
                            spacing: spacing
                        ) else { return }
                        onSelect(position)
                    }
            )
        }
        .padding(.horizontal, theme.spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
    }

    private func tile(_ position: WordGridPosition) -> some View {
        let selected = isSelected(position)
        return Text(letter(row: position.row, column: position.column))
            .font(theme.typography.title.weight(.bold))
            .foregroundStyle(selected ? theme.colors.background : theme.colors.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selected ? theme.colors.accentPrimary : theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                    .stroke(theme.colors.border, lineWidth: 1)
            )
            // Tiles lift as the trace picks them up and settle on release —
            // makes the drag feel physical (DESIGN.md §10.2). The accent
            // glow marks the tile as held (DESIGN.md §3 depth rules).
            .activeGlow(theme.colors.accentPrimary, active: selected)
            .scaleEffect(selected ? 1.08 : 1)
            .feedbackAnimation(.spring(response: 0.22, dampingFraction: 0.6), value: selected)
    }

    private func letter(row: Int, column: Int) -> String {
        guard board.indices.contains(row), board[row].indices.contains(column) else { return "" }
        return String(board[row][column])
    }

    private func isSelected(_ position: WordGridPosition) -> Bool {
        selectedPath.contains(position)
    }

    private func position(
        at location: CGPoint,
        originX: CGFloat,
        originY: CGFloat,
        tileSide: CGFloat,
        spacing: CGFloat
    ) -> WordGridPosition? {
        let localX = location.x - originX
        let localY = location.y - originY
        guard localX >= 0, localY >= 0 else { return nil }

        let step = tileSide + spacing
        let column = Int(localX / step)
        let row = Int(localY / step)
        guard (0..<WordGridEngine.size).contains(row),
              (0..<WordGridEngine.size).contains(column) else { return nil }

        let cellX = localX - CGFloat(column) * step
        let cellY = localY - CGFloat(row) * step
        guard cellX <= tileSide, cellY <= tileSide else { return nil }
        return WordGridPosition(row: row, column: column)
    }
}
