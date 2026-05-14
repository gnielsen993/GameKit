//
//  MinesweeperBoardView.swift
//  gamekit
//
//  Composes MinesweeperCellView instances into a LazyVGrid.
//
//  Phase 6.1 (A11Y-05):
//    - cellSize is auto-scaled to the available width via .onGeometryChange.
//      The pre-P6.1 fixed-per-difficulty switch (Easy 44pt / Medium 40pt /
//      Hard 36pt) has been replaced with a width-driven formula clamped to
//      an 18pt floor. Easy and Medium fit comfortably on standard iPhone
//      widths (>=390pt) without horizontal scroll; Hard clamps at the floor
//      and falls back to horizontal scroll (CONTEXT D-16).
//    - MagnifyGesture pinch-zoom layer applied via .simultaneousGesture
//      coexists with the cell-level LongPressGesture(0.25).exclusively(
//      before: TapGesture()) — single-finger taps/long-presses hit the
//      child gesture by default child-priority; two-finger pinch hits the
//      parent simultaneously. Scale clamped to [0.8, 2.0]; zoom persists
//      across vm.restart() within the session via in-memory @State and
//      resets on cold launch (CONTEXT D-14, Discretion #9).
//
//  Phase 3 invariants (per CONTEXT D-12, UI-SPEC §Layout & Sizing,
//  RESEARCH §Pattern 5 loss-state per-cell switch is OWNED BY MinesweeperCellView):
//    - Cell-size constants are intrinsic component dimensions — UI-SPEC §Spacing carve-out
//      (NOT new spacing tokens; .frame(width:height:) is exempt from the FOUND-07 hook)
//    - Props-only — receives theme + board + gameState + tap/long-press closures
//    - Routes events through closures; never reads or writes the VM directly
//    - ForEach iterates board.allIndices() (Hashable Index) — NOT enumerated() —
//      RESEARCH Pitfall 6 (stable diffing across board reset)
//

import SwiftUI
import DesignKit

struct MinesweeperBoardView: View {
    let theme: Theme
    let board: MinesweeperBoard
    let gameState: MinesweeperGameState

    // P5 (D-01/D-04/D-07) — animation orchestration props (props-only,
    // CLAUDE.md §8.2). MinesweeperGameView hoists these from the VM /
    // environment and passes through; child cells receive the same.
    let phase: MinesweeperPhase
    let hapticsEnabled: Bool
    let reduceMotion: Bool
    let revealCount: Int
    let flagToggleCount: Int

    // Loss cascade orchestration — flipped by GameView's loss-stage Task.
    let lossMinesRevealed: Bool
    let lossWrongFlagsPopped: Bool
    let lossTripIdx: MinesweeperIndex?

    let onTap: (MinesweeperIndex) -> Void
    let onLongPress: (MinesweeperIndex) -> Void

    // P11 D-10/D-12 (Plan 11-05): Video Mode env read. ONLY used to gate
    // the cellSize floor lookup; no other branches in this view. D-17
    // untouched contract: MagnifyGesture / scaleEffect / clampZoomScale /
    // cell-level LongPressGesture composition stay byte-identical.
    @Environment(\.videoModeStore) private var videoModeStore

    // 18pt floor (CONTEXT D-13). With Hard reshaped to 24×16 the formula
    // never clamps at this floor on iPhone-class widths.
    //
    // Width measurement uses GeometryReader (pull-based per layout pass) —
    // NOT @State + .onGeometryChange. The .background-on-LazyVGrid pattern
    // measures the LazyVGrid's *resolved* size, which when columns are
    // .fixed(cellSize) equals content width — so once cellSize grows in
    // landscape, the next portrait layout still measures the big content
    // width and never shrinks back. GeometryReader reports the parent's
    // *proposed* width every layout pass and is rotation-stable.
    static let minCellSize: CGFloat = 18

    /// Video-Mode-aware floor for Hard 16×30 on Large PiP zones.
    /// Locked from the Plan 11-05 audit:
    ///   - render Hard at 10/11/12/13pt on Dracula + Voltage presets
    ///   - measure mine icon + 1–8 SF Symbol legibility per CLAUDE.md §8.12
    ///   - pick the value that survives §8.12 cleanly
    /// Working number per `.planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md`
    /// §"How it composes with the existing 06.1-03 system" is ~12pt.
    ///
    /// Audit screenshots:
    ///   - Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png
    ///   - Docs/screenshots/v1.2-design/mines-hard-dracula-pip-large.png
    ///
    /// Rollback condition (ADR §Rollback): if mis-tap rate regresses on
    /// iPhone 17 Pro Max OR §8.12 Dracula legibility regresses, switch to
    /// warning-compromise (Variant 4) as the v1.3 fallback.
    ///
    /// TODO 11-05 audit: replace placeholder with the locked value before
    /// the human-verify checkpoint (Task 2) closes.
    static let minCellSizeVideoMode: CGFloat = 12   // PLACEHOLDER — locked at Task 2

    /// Returns the appropriate floor for the current Video Mode state.
    /// Off → minCellSize (v1.0 = 18). On → minCellSizeVideoMode.
    /// Single gate per ADR §How-it-composes + CONTEXT D-12:
    /// the floor depends ONLY on `videoModeOn`. PiP location (Large vs
    /// Small) is NOT a factor; game difficulty is NOT a factor. Easy +
    /// Medium auto-scale above the lowered floor at iPhone-class widths,
    /// so only the Hard squeeze case actually consumes the new floor.
    static func minCellSize(videoModeOn: Bool) -> CGFloat {
        videoModeOn ? minCellSizeVideoMode : minCellSize
    }

    /// Pure formula extracted for unit testing (Plan 06.1-03 Wave 0).
    /// Returns the per-cell side length given the available container
    /// width, column count, and surrounding padding/spacing values.
    ///
    /// Formula derivation (CONTEXT D-13):
    ///   usable       = max(0, width - 2 * padding)
    ///   spacingTotal = max(0, (cols - 1)) * spacing
    ///   cellSize     = max(minCellSize, (usable - spacingTotal) / cols)
    ///
    /// Sub-floor cases (e.g. Hard 30-col on iPhone SE 320pt) clamp to
    /// `minCellSize` and rely on the horizontal-scroll fallback
    /// (`scrollAxis(for:)`) plus pinch-zoom-out for the accessibility path.
    static func cellSize(
        forWidth width: CGFloat,
        cols: Int,
        padding: CGFloat,
        spacing: CGFloat,
        floor: CGFloat = minCellSize
    ) -> CGFloat {
        guard cols > 0 else { return floor }
        let colsF = CGFloat(cols)
        let usable = max(0, width - 2 * padding)
        let spacingTotal = max(0, colsF - 1) * spacing
        let computed = (usable - spacingTotal) / colsF
        return max(floor, computed)
    }

    /// 2026-05-02 — iPad fix. Width-only sizing was correct for iPhone
    /// (height was always the slack dimension) but on iPad 13" portrait
    /// Hard's 16 cols × ~62pt cells produced 24 × 62 = 1488pt of grid
    /// height which overflowed the available vertical space — the
    /// LazyVGrid extended past the viewport with no ScrollView, so the
    /// visible region rendered as a blank gray rectangle.
    ///
    /// New formula: take the smaller of width-bound and height-bound
    /// per-cell sizes so the whole board fits both axes regardless of
    /// device aspect. Same `minCellSize` floor.
    static func cellSize(
        forWidth width: CGFloat,
        height: CGFloat,
        cols: Int,
        rows: Int,
        padding: CGFloat,
        spacing: CGFloat,
        floor: CGFloat = minCellSize
    ) -> CGFloat {
        let widthBound = cellSize(forWidth: width, cols: cols, padding: padding, spacing: spacing, floor: floor)
        guard rows > 0 else { return widthBound }
        let rowsF = CGFloat(rows)
        let usableHeight = max(0, height - 2 * padding)
        let spacingTotalH = max(0, rowsF - 1) * spacing
        let heightBound = (usableHeight - spacingTotalH) / rowsF
        return max(floor, min(widthBound, heightBound))
    }

    var body: some View {
        // P5 D-01: extract the engine-ordered reveal list once per render so
        // the per-cell delay lookup is O(n) instead of O(n²).
        let revealingCells: [MinesweeperIndex] = {
            if case .revealing(let cells) = phase { return cells }
            return []
        }()
        let cascadeCount = max(revealingCells.count, 1)

        GeometryReader { proxy in
            let cs = Self.cellSize(
                forWidth: proxy.size.width,
                height: proxy.size.height,
                cols: board.cols,
                rows: board.rows,
                padding: theme.spacing.s,
                spacing: 0,
                floor: Self.minCellSize(videoModeOn: videoModeStore.isEnabled)
            )
            let columns = Array(
                repeating: GridItem(.fixed(cs), spacing: 0),
                count: board.cols
            )

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(board.allIndices(), id: \.self) { index in
                    let perCellDelay: Double = {
                        guard !reduceMotion,
                              let order = revealingCells.firstIndex(of: index)
                        else { return 0 }
                        return min(0.008 * Double(order),
                                   theme.motion.normal / Double(cascadeCount))
                    }()

                    MinesweeperCellView(
                        cell: board.cell(at: index),
                        index: index,
                        cellSize: cs,
                        theme: theme,
                        gameState: gameState,
                        hapticsEnabled: hapticsEnabled,
                        reduceMotion: reduceMotion,
                        revealCount: revealCount,
                        flagToggleCount: flagToggleCount,
                        lossMinesRevealed: lossMinesRevealed,
                        lossWrongFlagsPopped: lossWrongFlagsPopped,
                        lossTripIdx: lossTripIdx,
                        onTap: onTap,
                        onLongPress: onLongPress
                    )
                    .transition(
                        reduceMotion
                        ? .identity
                        : .opacity.animation(.easeOut(duration: theme.motion.fast).delay(perCellDelay))
                    )
                }
            }
            .padding(.horizontal, theme.spacing.s)
            .padding(.vertical, theme.spacing.s)
            // 2026-05-02 — center horizontally so iPad Hard (16 cols at
            // height-bound size) doesn't pin to the leading edge with
            // a wide trailing gap. iPhone Easy/Medium also benefit when
            // height is the binding constraint in landscape.
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
    }
}
