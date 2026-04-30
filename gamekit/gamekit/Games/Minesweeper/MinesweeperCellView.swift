//
//  MinesweeperCellView.swift
//  gamekit
//
//  Single Minesweeper tile. Three responsibilities:
//    1. Render the cell's current visual (background fill + glyph) per
//       (cell.state x cell.isMine x gameState).
//    2. Compose the long-press-vs-tap gesture
//       (LongPressGesture(0.25).exclusively(before: TapGesture()))
//       — load-bearing for SC1; the 0.25s constant is locked by ROADMAP and
//       zero-misfire-tested on iPhone SE-class hardware.
//    3. Bake `accessibilityLabel` at view creation (D-19), 1-indexed row/col.
//
//  Phase 3 invariants (per D-17, D-18, D-19, RESEARCH §Pattern 1 + §Pattern 5):
//    - .exclusively(before:) — NEVER .simultaneously(with:) (Pitfall 7 fires both)
//    - 0.25s long-press threshold — locked by ROADMAP SC1; do not change
//    - Loss-state mine reveal is INSTANT in P3 (no animation) — D-18 explicitly
//      defers the cascade to P5. P3 lays out switch arms so P5 can layer
//      `phase: MinesweeperPhase` enum changes without touching V/VM contracts.
//    - Adjacency text color reads `theme.gameNumber(n)` — semantic token
//      (THEME-02); Plan 01 added the token, this view consumes it.
//    - Zero Color(...) literals — FOUND-07 pre-commit hook rejects (RESEARCH
//      Pitfall 7).
//

import SwiftUI
import DesignKit

struct MinesweeperCellView: View {
    let cell: MinesweeperCell
    let index: MinesweeperIndex
    let cellSize: CGFloat
    let theme: Theme
    let gameState: MinesweeperGameState

    // P5 (D-04/D-07) — animation/haptic orchestration props (props-only).
    // Gating-at-source: when `hapticsEnabled` is false, the trigger value
    // is constant 0 so `.sensoryFeedback` never fires (the modifier is
    // value-driven, not event-driven). When `reduceMotion` is true the
    // `.symbolEffect(.bounce)` value is 0 so the symbol does not animate
    // (defensive belt-and-suspenders to system-level handling per D-04).
    let hapticsEnabled: Bool
    let reduceMotion: Bool
    let revealCount: Int
    let flagToggleCount: Int

    let onTap: (MinesweeperIndex) -> Void
    let onLongPress: (MinesweeperIndex) -> Void

    var body: some View {
        tileBackground
            .frame(width: cellSize, height: cellSize)
            .overlay(glyph)
            .overlay(
                Rectangle()
                    .stroke(theme.colors.textPrimary.opacity(0.18), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.25)
                    .exclusively(before: TapGesture())
                    .onEnded { result in
                        switch result {
                        case .first:
                            onLongPress(index)        // long-press won
                        case .second:
                            onTap(index)              // tap won
                        }
                    }
            )
            // P5 D-07: cell-level haptics. Trigger gating-at-source —
            // hapticsEnabled=false collapses the trigger to constant 0
            // so .sensoryFeedback never fires.
            .sensoryFeedback(.selection, trigger: hapticsEnabled ? revealCount : 0)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticsEnabled ? flagToggleCount : 0)
            .accessibilityElement(children: .ignore)  // RESEARCH Pitfall 5
            .accessibilityLabel(accessibilityLabelKey)
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Tile background
    //
    // revealed = surface (touched / been-here tone)
    // hidden / flagged = surfaceElevated (unrevealed affordance)
    // mineHit = danger (the "you stepped here" highlight per D-17 step 1)

    @ViewBuilder
    private var tileBackground: some View {
        ZStack {
            Rectangle().fill(backgroundFill)
            // Hidden/flagged cells get a strong textPrimary tint so they
            // stand out against the surface across every preset (tested
            // on Paper / Cream / Classic where surface ≈ background).
            if needsHiddenTint {
                Rectangle().fill(theme.colors.textPrimary.opacity(0.22))
            }
        }
    }

    private var needsHiddenTint: Bool {
        switch cell.state {
        case .hidden, .flagged: return true
        default: return false
        }
    }

    private var backgroundFill: Color {
        switch cell.state {
        case .revealed:
            return theme.colors.surface
        case .hidden, .flagged:
            return theme.colors.surface
        case .mineHit:
            return theme.colors.danger
        }
    }

    // MARK: - Glyph (state x isMine x gameState switch — D-17 + RESEARCH §Pattern 5)

    @ViewBuilder
    private var glyph: some View {
        switch (cell.state, cell.isMine, isLost) {

        // 1. Trip mine — circle.fill on the danger background (background already
        //    supplies danger fill).
        case (.mineHit, _, _):
            Image(systemName: "circle.fill")
                .resizable().scaledToFit()
                .frame(width: cellSize * 0.45, height: cellSize * 0.45)
                .foregroundStyle(theme.colors.textPrimary)

        // 2. On loss, flip every other still-hidden mine to a visible mine glyph
        //    (D-17 step 2).
        case (.hidden, true, true):
            Image(systemName: "circle.fill")
                .resizable().scaledToFit()
                .frame(width: cellSize * 0.45, height: cellSize * 0.45)
                .foregroundStyle(theme.colors.textPrimary)

        // 3. On loss, mark wrongly-flagged cells with X overlay on the flag
        //    (D-17 step 3).
        case (.flagged, false, true):
            ZStack {
                Image(systemName: "flag.fill")
                    .resizable().scaledToFit()
                    .frame(width: cellSize * 0.55, height: cellSize * 0.55)
                    .foregroundStyle(theme.colors.danger)
                Image(systemName: "xmark")
                    .resizable().scaledToFit()
                    .frame(width: cellSize * 0.7, height: cellSize * 0.7)
                    .foregroundStyle(theme.colors.danger)
            }

        // 4. Normal flag (in-progress; correctly-placed flag-on-mine after loss).
        case (.flagged, _, _):
            Image(systemName: "flag.fill")
                .resizable().scaledToFit()
                .frame(width: cellSize * 0.55, height: cellSize * 0.55)
                .foregroundStyle(theme.colors.danger)
                // P5 D-04 + D-07: flag spring on commitment. Reduce Motion
                // belt-and-suspenders — value=0 prevents replay even though
                // .symbolEffect honors the system flag automatically.
                .symbolEffect(.bounce, value: reduceMotion ? 0 : flagToggleCount)

        // 5. Revealed numbered cell — adjacency 1...8 from theme.gameNumber(_:).
        case (.revealed, _, _) where cell.adjacentMineCount > 0:
            Text("\(cell.adjacentMineCount)")
                .font(.system(size: cellSize * 0.55, weight: .bold, design: .rounded))
                .foregroundStyle(theme.gameNumber(cell.adjacentMineCount))

        // 6. Revealed empty cell (zero adjacency) — no glyph.
        case (.revealed, _, _):
            EmptyView()

        // 7. Hidden non-mine pre-loss — no glyph.
        default:
            EmptyView()
        }
    }

    private var isLost: Bool {
        if case .lost = gameState { return true }
        return false
    }

    // MARK: - Accessibility (D-19 — baked at view creation; 1-indexed row/col;
    //                        LocalizedStringKey form auto-extracts to xcstrings
    //                        via SWIFT_EMIT_LOC_STRINGS=YES per RESEARCH §Pattern 7)

    private var accessibilityLabelKey: LocalizedStringKey {
        switch cell.state {
        case .hidden:
            return "Unrevealed, row \(index.row + 1) column \(index.col + 1)"
        case .revealed where cell.adjacentMineCount == 0:
            return "Revealed, 0 mines adjacent, row \(index.row + 1) column \(index.col + 1)"
        case .revealed:
            return "Revealed, \(cell.adjacentMineCount) mines adjacent, row \(index.row + 1) column \(index.col + 1)"
        case .flagged:
            return "Flagged, row \(index.row + 1) column \(index.col + 1)"
        case .mineHit:
            return "Mine, row \(index.row + 1) column \(index.col + 1)"
        }
    }
}
