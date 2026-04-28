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

    let onTap: (MinesweeperIndex) -> Void
    let onLongPress: (MinesweeperIndex) -> Void

    // P6.1 (A11Y-05) — measured ScrollView width via .onGeometryChange.
    // Default 0 yields the minCellSize floor on the first render; the
    // background measurement triggers a single follow-up render with the
    // real width (RESEARCH §Pattern 4 — onGeometryChange runs in the
    // background layout pass and does NOT cause a layout-feedback loop).
    @State private var availableWidth: CGFloat = 0

    // P6.1 (A11Y-05) — pinch-zoom state. Dual-@State pattern (RESEARCH §Pattern 3):
    //   - zoomScale: live commit-on-end value (also used by .scaleEffect)
    //   - baseZoomScale: snapshot at .onChanged START so each new pinch
    //     gesture composes from the accumulated zoom (NOT resetting to 1.0)
    // Persists across vm.restart() within session because the zoom lives in
    // view @State and the VM's restart() cannot reach view state (CONTEXT
    // D-14, Discretion #9 — in-memory only). Cold launch resets to 1.0.
    @State private var zoomScale: CGFloat = 1.0
    @State private var baseZoomScale: CGFloat = 1.0

    // MARK: - P6.1 (A11Y-05) cellSize / pinch-zoom constants
    //
    // 18pt floor (CONTEXT D-13 + Discretion #1) — tap-target tolerable for
    // casual play; pinch-zoom gives the user the escape hatch when cells
    // clamp at floor on narrow screens.
    static let minCellSize: CGFloat = 18

    // Pinch-zoom range (CONTEXT D-14 + Discretion #4). Below 0.8 cells become
    // illegible; above 2.0 the user might as well play a different difficulty.
    static let minZoomScale: CGFloat = 0.8
    static let maxZoomScale: CGFloat = 2.0

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
    static func cellSize(forWidth width: CGFloat, cols: Int, padding: CGFloat, spacing: CGFloat) -> CGFloat {
        guard cols > 0 else { return minCellSize }
        let colsF = CGFloat(cols)
        let usable = max(0, width - 2 * padding)
        let spacingTotal = max(0, colsF - 1) * spacing
        let computed = (usable - spacingTotal) / colsF
        return max(minCellSize, computed)
    }

    /// Pure clamp extracted for unit testing (Plan 06.1-03 Wave 0).
    /// Clamps a proposed zoom scale to the [minZoomScale, maxZoomScale]
    /// range. Used by Task 3's MagnifyGesture .onChanged handler.
    static func clampZoomScale(_ value: CGFloat) -> CGFloat {
        return min(maxZoomScale, max(minZoomScale, value))
    }

    // P6.1 — instance computed property delegates to the static helper so
    // the view's body reads exactly one source of truth for cellSize math
    // and the static helper stays unit-testable from gamekitTests.
    //
    // RESEARCH open question #1 RESOLVED — option (a): horizontal padding
    // reduced from theme.spacing.l (16pt) to theme.spacing.s (8pt) so Easy
    // 9-col + Medium 16-col fit comfortably on 390pt iPhone widths without
    // clamping at the 18pt floor.
    private var cellSize: CGFloat {
        Self.cellSize(
            forWidth: availableWidth,
            cols: board.cols,
            padding: theme.spacing.s,
            spacing: theme.spacing.xs
        )
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(cellSize), spacing: theme.spacing.xs),
            count: board.cols
        )
    }

    var body: some View {
        // P5 D-01: extract the engine-ordered reveal list once per render so
        // the per-cell delay lookup is O(n) instead of O(n²).
        let revealingCells: [MinesweeperIndex] = {
            if case .revealing(let cells) = phase { return cells }
            return []
        }()
        let cascadeCount = max(revealingCells.count, 1)

        ScrollView(scrollAxis(for: board.difficulty), showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: theme.spacing.xs) {
                ForEach(board.allIndices(), id: \.self) { index in
                    let perCellDelay: Double = {
                        // D-04: Reduce Motion → no stagger; cascade collapses
                        // to simultaneous reveal.
                        guard !reduceMotion,
                              let order = revealingCells.firstIndex(of: index)
                        else { return 0 }
                        // D-01 budget: per-cell delay = min(8ms × index,
                        // theme.motion.normal / count). Hard flood-fill of
                        // 100+ cells stays inside theme.motion.normal cap.
                        return min(0.008 * Double(order), theme.motion.normal / Double(cascadeCount))
                    }()

                    MinesweeperCellView(
                        cell: board.cell(at: index),
                        index: index,
                        cellSize: cellSize,
                        theme: theme,
                        gameState: gameState,
                        hapticsEnabled: hapticsEnabled,
                        reduceMotion: reduceMotion,
                        revealCount: revealCount,
                        flagToggleCount: flagToggleCount,
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
            // P6.1 (A11Y-05) — option (a) padding reduction. Horizontal padding
            // dropped from theme.spacing.l (16pt) to theme.spacing.s (8pt) so
            // the auto-scale formula gives Easy/Medium boards comfortable cell
            // sizes on 390pt iPhone widths without hitting the 18pt floor.
            .padding(.horizontal, theme.spacing.s)
            .padding(.vertical, theme.spacing.s)
            // P6.1 (A11Y-05) — pinch-zoom scale layer.
            // Applied to LazyVGrid (NOT the ScrollView) so the ScrollView's
            // clipping frame stays stable during zoom — only the board
            // content scales. Anchor .center keeps the visual pivot at the
            // viewport midpoint regardless of pinch-finger position.
            .scaleEffect(zoomScale, anchor: .center)
        }
        // P6.1 (A11Y-05) — measure available width without participating in
        // layout. The .background(Color.clear...) trick runs in the background
        // layout pass; assigning to availableWidth triggers a single follow-up
        // render with the correct cellSize. The proxy-based pattern avoids the
        // greedy layout-feedback loop that plagues the older container-reader
        // approach (RESEARCH §Pattern 4). Color.clear is the standard SwiftUI
        // transparent placeholder (NOT a hex/RGB literal) and is exempt from
        // FOUND-07.
        .background(
            Color.clear
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { newWidth in
                    availableWidth = newWidth
                }
        )
        // P6.1 (A11Y-05) — pinch-zoom via MagnifyGesture (iOS 17+).
        // CRITICAL: .simultaneousGesture (NOT .gesture) per RESEARCH §Pattern 3
        // — child cell LongPressGesture(0.25).exclusively(before: TapGesture())
        // continues to win for single-finger taps and long-presses; this
        // parent gesture fires independently for two-finger pinch only.
        // CRITICAL: MagnifyGesture is the iOS 17+ pinch primitive (the
        // earlier iOS 16 spelling is deprecated and would emit a build
        // warning). The .magnification value on .onChanged is the delta
        // multiplier from gesture START (1.0 = no change), so we compose
        // live = baseZoomScale * delta and commit baseZoomScale on .onEnded
        // so each new pinch resumes from the accumulated zoom.
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let proposed = baseZoomScale * value.magnification
                    zoomScale = Self.clampZoomScale(proposed)
                }
                .onEnded { _ in
                    baseZoomScale = zoomScale
                }
        )
    }

    /// Hard scrolls horizontally as a fallback for sub-floor cases (e.g.
    /// iPhone SE 320pt where 30 × 18pt + 29 × 4pt > viewport width).
    /// Easy/Medium return `[]` because the auto-scale formula keeps cells
    /// inside the viewport on standard iPhone widths.
    private func scrollAxis(for difficulty: MinesweeperDifficulty) -> Axis.Set {
        difficulty == .hard ? .horizontal : []
    }
}
