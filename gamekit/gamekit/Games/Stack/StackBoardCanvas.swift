//
//  StackBoardCanvas.swift
//  gamekit
//
//  Immediate-mode `Canvas` render for the Stack tower: placed blocks, the
//  current sliding block, and the overhang trim piece. Camera/scroll lives
//  here in the view layer — the engine never reads geometry or motion state.
//
//  Gaffer interpolation (non-RM): the sliding block's on-screen position is
//  linearly interpolated between the previous-tick center (`prevCenterX`)
//  and the current-tick center (`frame.currentCenterX`) using `accAlpha`
//  (accumulator ÷ fixedDt). This smooths the block's motion at 120 Hz
//  without changing the 60 Hz simulation rate.
//
//  Reduce Motion gate (STACK-06): when `reduceMotion` is true, the block
//  position snaps to `frame.currentCenterX` each tick (jump-cut), the
//  camera snaps to its target, and the trim piece vanishes instantly.
//  The engine is never affected by this flag.
//
//  Token discipline: all colors come from DesignKit semantic tokens via
//  `StackPalette` and `theme.colors.*`. No raw color initializers appear
//  anywhere in this file (CLAUDE.md §1, D-07).
//
//  Pitfall 18 guard: no SwiftUI implicit-animation modifier is applied to
//  board state in this file. All interpolation happens inside the Canvas draw closure.
//

import SwiftUI
import DesignKit

/// Immediate-mode `Canvas` board view for Stack.
///
/// **Props-only** — reads an engine snapshot each display frame and draws
/// via `ctx.fill`. Camera and block-position interpolation live here;
/// the pure `StackEngine` is untouched.
struct StackBoardCanvas: View {

    // MARK: - Props

    /// Tower blocks from the engine snapshot (index 0 = base block).
    let placed: [PlacedBlock]

    /// Latest engine frame — sliding block position + game-state.
    let frame: StackFrame

    /// Sliding block center at the previous engine tick.
    /// Used for Gaffer interpolation; pass `frame.currentCenterX` from the
    /// tick before the current one. Snapped under `reduceMotion`.
    let prevCenterX: Double

    /// Accumulator remainder ÷ fixedDt, in [0, 1].
    /// Drives Gaffer interpolation of the sliding block and the overhang
    /// trim-piece fall animation.
    let accAlpha: Double

    /// Active DesignKit theme. All block colors come from `theme.charts.*`
    /// and board surfaces from `theme.colors.*` — no raw color initializers.
    let theme: Theme

    /// When true: snap camera offset and block position (jump-cut); skip
    /// the trim-piece fall animation (vanish instantly).
    let reduceMotion: Bool

    // MARK: - Layout constant

    /// Number of block heights visible in the viewport (~12–16 per research).
    /// Determines `blockH = size.height / visibleBlocks`.
    private static let visibleBlocks: CGFloat = 14

    // MARK: - Body

    var body: some View {
        Canvas { ctx, size in
            let blockH = size.height / Self.visibleBlocks
            let cam = cameraOffset(size: size, blockH: blockH)

            // Backdrop — board surface token.
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(theme.colors.background)
            )

            // Placed tower blocks (bottom-to-top iteration; cull once above viewport).
            for (i, block) in placed.enumerated() {
                let rect = blockRect(block, atIndex: i, blockH: blockH, cam: cam, size: size)
                // Once a block's bottom edge leaves the top of the viewport, all
                // higher-index blocks are also off-screen — stop iterating.
                guard rect.maxY > 0 else { break }
                ctx.fill(Path(rect),
                         with: .color(StackPalette.color(forIndex: i, theme: theme)))
            }

            // Sliding block — hidden after game over.
            guard !frame.gameOver else { return }

            // Gaffer interpolation: lerp prevCenterX → currentCenterX using accAlpha.
            // Under Reduce Motion: snap to the engine's tick-boundary value (D-08).
            let renderCX = reduceMotion
                ? frame.currentCenterX
                : prevCenterX + (frame.currentCenterX - prevCenterX) * accAlpha

            let sliderRect = blockRect(
                PlacedBlock(centerX: renderCX, width: frame.currentWidth),
                atIndex: placed.count,
                blockH: blockH, cam: cam, size: size
            )
            ctx.fill(Path(sliderRect),
                     with: .color(StackPalette.color(forIndex: placed.count, theme: theme)))

            // Overhang trim piece — vanish instantly under Reduce Motion (D-08 / D-09).
            // Without Reduce Motion: fall two block-heights and fade to clear over the
            // tick duration (accAlpha 0 → 1). This animation is brief by design: the
            // trim event fires for exactly one engine tick (~1/60 s).
            guard case .trim(let overhangWidth) = frame.event,
                  !reduceMotion,
                  placed.count >= 2 else { return }

            let trimmedBlock = placed[placed.count - 1]
            let refBlock    = placed[placed.count - 2]

            // Determine overhang side: if the block was dropped to the right of the
            // reference, the trim piece is on the right (and vice versa).
            // All colors come from DesignKit semantic tokens only (no raw initializers).
            let isRightOverhang = prevCenterX >= refBlock.centerX
            let droppedWidth    = trimmedBlock.width + overhangWidth

            let oLeft: Double
            let oRight: Double
            if isRightOverhang {
                oLeft  = trimmedBlock.centerX + trimmedBlock.width / 2
                oRight = prevCenterX + droppedWidth / 2
            } else {
                oLeft  = prevCenterX - droppedWidth / 2
                oRight = trimmedBlock.centerX - trimmedBlock.width / 2
            }

            let oCenterX = (oLeft + oRight) / 2
            let fallOffset = CGFloat(accAlpha) * blockH * 2  // fall 2 block-heights
            let opacity    = Double(max(0, 1.0 - accAlpha))  // fade to clear

            let trimBase = blockRect(
                PlacedBlock(centerX: oCenterX, width: overhangWidth),
                atIndex: placed.count - 1,
                blockH: blockH, cam: cam, size: size
            )
            let trimRect = trimBase.offsetBy(dx: 0, dy: fallOffset)

            let trimColor = StackPalette.color(forIndex: placed.count - 1, theme: theme)
                .opacity(opacity)
            ctx.fill(Path(trimRect), with: .color(trimColor))
        }
    }

    // MARK: - Camera helpers

    /// Computes the upward scroll offset so the sliding block stays in the
    /// upper third of the viewport once the tower grows tall enough.
    ///
    /// Formula: start scrolling once `(placed.count + 1) * blockH` exceeds
    /// 2/3 of `size.height` — before that threshold the tower is short and
    /// the full board is visible without scrolling.
    ///
    /// Under Reduce Motion: this formula always snaps (no inter-tick
    /// interpolation is needed because placed.count only grows on tick
    /// boundaries, not between them).
    private func cameraOffset(size: CGSize, blockH: CGFloat) -> CGFloat {
        let target = CGFloat(placed.count + 1) * blockH - 2 * size.height / 3
        return max(0, target)
    }

    // MARK: - Coordinate mapping

    /// Maps a normalized `PlacedBlock` to a `CGRect` in canvas coordinates.
    ///
    /// Blocks are in normalised [0, 1] horizontal space; the canvas maps
    /// them linearly to `size.width`. Vertically, index 0 (base block) sits
    /// at the canvas bottom; higher indices stack upward.
    private func blockRect(_ block: PlacedBlock, atIndex i: Int,
                           blockH: CGFloat, cam: CGFloat, size: CGSize) -> CGRect {
        let x = CGFloat(block.centerX - block.width / 2) * size.width
        let y = size.height - CGFloat(i + 1) * blockH - cam
        return CGRect(x: x, y: y,
                      width: CGFloat(block.width) * size.width,
                      height: blockH)
    }
}
