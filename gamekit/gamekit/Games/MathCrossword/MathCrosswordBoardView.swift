import SwiftUI
import DesignKit
import MathCrosswordCore

struct MathCrosswordBoardView: View {
    let theme: Theme
    let puzzle: TallyPuzzle
    let placements: [GridPos: Int]
    let selectedCell: GridPos?
    let hintPlacements: [GridPos: Int]
    let onSelect: (GridPos) -> Void
    let dropTarget: GridPos?
    let onFrameChange: (CGRect) -> Void

    var body: some View {
        GeometryReader { proxy in
            let columns = max(1, puzzle.colCount)
            let rows = max(1, puzzle.rowCount)
            let cellSide = max(0, min(
                proxy.size.width / CGFloat(columns),
                proxy.size.height / CGFloat(rows)
            ))
            ZStack(alignment: .topLeading) {
                ForEach(cells, id: \.self) { position in
                    cell(for: position)
                        .frame(width: cellSide, height: cellSide)
                        .position(
                            x: CGFloat(position.col) * cellSide + cellSide / 2,
                            y: CGFloat(position.row) * cellSide + cellSide / 2
                        )
                }
            }
            .frame(width: CGFloat(columns) * cellSide, height: CGFloat(rows) * cellSide)
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .named(MathCrosswordCoordinateSpace.name))
            } action: { onFrameChange($0) }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, theme.spacing.m)
        .layoutPriority(1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Math crossword board"))
    }

    private var cells: [GridPos] {
        Set(puzzle.equations.flatMap { [$0.a, $0.opCell, $0.b, $0.eqCell, $0.r] }).sorted()
    }

    @ViewBuilder
    private func cell(for position: GridPos) -> some View {
        if let symbol = symbol(at: position) {
            Text(symbol)
                .font(theme.typography.title.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.01)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(Text(symbol == "=" ? "equals" : symbol))
        } else {
            numberCell(position)
        }
    }

    private func numberCell(_ position: GridPos) -> some View {
        let given = puzzle.givens.contains(position)
        let value = given ? puzzle.solution[position] : placements[position]
        let selected = selectedCell == position || dropTarget == position
        let hinted = hintPlacements[position] != nil
        let incorrect = !given && value != nil && value != puzzle.solution[position]
        return Button { onSelect(position) } label: {
            Text(value.map(String.init) ?? "")
                .font(theme.typography.title.weight(.semibold))
                .foregroundStyle(selected ? theme.colors.background : incorrect ? theme.colors.danger : theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.01)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selected ? theme.colors.accentPrimary : theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                        .stroke(hinted ? theme.colors.accentPrimary : incorrect ? theme.colors.danger : theme.colors.border, lineWidth: hinted ? 2 : 1)
                )
                .chipShadow()
        }
        .buttonStyle(.pressable)
        .disabled(given)
        .accessibilityIdentifier("math-cell-\(position.row)-\(position.col)")
        .accessibilityLabel(Text(accessibilityLabel(for: position, value: value, given: given, hinted: hinted, incorrect: incorrect)))
        .accessibilityValue(Text(value.map(String.init) ?? "empty"))
        .accessibilityHint(Text(given ? "Given number" : "Select this blank"))
    }

    private func symbol(at position: GridPos) -> String? {
        for equation in puzzle.equations {
            if equation.opCell == position { return equation.op.rawValue }
            if equation.eqCell == position { return "=" }
        }
        return nil
    }

    private func accessibilityLabel(
        for position: GridPos,
        value: Int?,
        given: Bool,
        hinted: Bool,
        incorrect: Bool
    ) -> String {
        var result = "\(given ? "Given" : "Blank") number at row \(position.row + 1), column \(position.col + 1)"
        if let value { result += ", \(value)" }
        if hinted { result += ", hint target" }
        if incorrect { result += ", does not fit the equations" }
        return result
    }
}

enum MathCrosswordCoordinateSpace {
    nonisolated static let name = "math-crossword-board"
}
