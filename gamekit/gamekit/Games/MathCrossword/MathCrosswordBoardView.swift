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
    @ScaledMetric(relativeTo: .body) private var minimumCell: CGFloat = 44

    var body: some View {
        GeometryReader { proxy in
            let columns = max(1, puzzle.colCount)
            let cellSide = max(minimumCell, min(68, (proxy.size.width - theme.spacing.m * 2) / CGFloat(columns)))
            ScrollView([.horizontal, .vertical]) {
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
                .frame(
                    width: CGFloat(columns) * cellSide,
                    height: CGFloat(max(1, puzzle.rowCount)) * cellSide,
                    alignment: .topLeading
                )
                .padding(theme.spacing.m)
            }
            .scrollIndicators(.automatic)
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
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(Text(symbol == "=" ? "equals" : symbol))
        } else {
            numberCell(position)
        }
    }

    private func numberCell(_ position: GridPos) -> some View {
        let given = puzzle.givens.contains(position)
        let value = given ? puzzle.solution[position] : placements[position]
        let selected = selectedCell == position
        let hinted = hintPlacements[position] != nil
        let incorrect = !given && value != nil && value != puzzle.solution[position]
        return Button { onSelect(position) } label: {
            Text(value.map(String.init) ?? "")
                .font(theme.typography.title.weight(.semibold))
                .foregroundStyle(selected ? theme.colors.background : incorrect ? theme.colors.danger : theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
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
