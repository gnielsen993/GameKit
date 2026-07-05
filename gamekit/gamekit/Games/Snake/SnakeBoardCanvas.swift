//
//  SnakeBoardCanvas.swift
//  gamekit
//
//  Immediate-mode `Canvas` render for Snake: board well (D-03), continuous
//  rounded body path with head-to-tail ArcadePalette gradient (D-01/D-02),
//  head eye-dots, food circle, Gaffer interpolation between cell moves (D-04),
//  and the Reduce Motion jump-cut path (SNAKE-07). Props-only — all state
//  lives in SnakeViewModel.
//
//  Drawing order inside the Canvas closure:
//    1. Board well — rounded border-stroke (D-03, flat, no sheen, no grid lines)
//    2. Body segments tail→head; each pair is a separate sub-path colored from
//       ArcadePalette (D-01/D-02). Head segment stroke scales by headPulse (D-08).
//    3. Head eye dots — two background-colored circles toward travel direction (D-01).
//    4. Food circle — filled with theme.colors.success.
//
//  Wrap-boundary guard (Common Pitfall 1 / 17-RESEARCH §5): segment pairs whose
//  endpoints span more than half the grid in either axis (toroidal wrap artifact)
//  are skipped. The rounded caps at the edge serve as the visual "exits one side,
//  re-enters the other" cue — correct toroidal metaphor with no diagonal streak.
//
//  Token discipline: all colors come from theme.colors.*, theme.charts.*, or
//  ArcadePalette.layer(forIndex:theme:). No raw color initializers or system
//  color names (CLAUDE.md §1, SNAKE-06).
//
//  NAMING NOTE: the snake body prop is named `snakeBody` (not `body`) to avoid
//  a Swift compile-error conflict with SwiftUI's required `var body: some View`.
//  Plan spec said `body: [SnakeCell]`; renamed here per Rule 1 auto-fix.
//

import SwiftUI
import DesignKit

/// Immediate-mode `Canvas` board view for Snake. **Props-only** (no @State, no @Environment).
///
/// The parent view (`SnakeGameView`, Plan 17-05) owns all state and passes it in as props
/// on every 60 Hz frame tick. The Gaffer alpha (`cellMoveAlpha`) drives smooth segment
/// interpolation between cell moves; setting `reduceMotion: true` forces alpha to 1.0,
/// producing a jump-cut teleport each tick (SNAKE-07).
struct SnakeBoardCanvas: View {

    // MARK: - Props

    /// Current snake body. `snakeBody[0]` = head; last element = tail.
    let snakeBody: [SnakeCell]
    /// Body snapshot BEFORE the most-recent cell move — Gaffer interpolation anchor.
    let prevBody: [SnakeCell]
    /// Gaffer alpha in [0, 1]. Forced to 1.0 under Reduce Motion (SNAKE-07 jump-cut).
    let cellMoveAlpha: Double
    /// Current food cell.
    let food: SnakeCell
    /// Snake's current travel direction — drives head eye-dot placement (D-01).
    let currentDirection: SnakeDirection
    /// Active DesignKit theme — all colors come from its tokens only (SNAKE-06).
    let theme: Theme
    /// When true, `alpha` is clamped to 1.0 → jump-cut teleport per cell move (SNAKE-07).
    let reduceMotion: Bool
    /// True when time-based FX are allowed (animationsEnabled && !reduceMotion).
    let fxEnabled: Bool
    /// Grid column count — used for cellSize computation and wrap-boundary detection.
    let cols: Int
    /// Grid row count — used for wrap-boundary detection.
    let rows: Int
    /// D-08 head pulse: 0 = rest, 1 = pulse peak (0.25× stroke-width amplification).
    ///
    /// The parent animates this 1→0 over ~150ms on `eatCount` change when `fxEnabled`.
    /// Stays 0.0 when `!fxEnabled` or `reduceMotion` so the pulse is fully gated by
    /// the feedbackAnimation setting and Reduce Motion (SNAKE-07).
    let headPulse: Double

    // MARK: - Body

    var body: some View {
        Canvas { ctx, size in
            let cellSize = size.width / CGFloat(cols)

            // SNAKE-07: Reduce Motion → force alpha 1.0 (jump-cut, no interpolation).
            // alpha = 1.0 resolves segPos to the CURRENT body position. 0.0 would
            // resolve to prevBody — the pre-move snapshot — leaving RM users one
            // cell move behind the engine on every frame (CR-01).
            let alpha = reduceMotion ? 1.0 : cellMoveAlpha

            // ── 1. Board well (D-03) ─────────────────────────────────────────────
            // Flat border-tinted rounded rectangle — no fill, no sheen, no grid lines
            // (DESIGN.md §3.0). Inset by 0.5pt so the 1pt stroke doesn't clip.
            let boardPath = Path(
                roundedRect: CGRect(x: 0.5, y: 0.5,
                                    width: size.width - 1,
                                    height: size.height - 1),
                cornerRadius: theme.radii.card,
                style: .continuous
            )
            ctx.stroke(boardPath, with: .color(theme.colors.border), lineWidth: 1)

            guard snakeBody.count >= 1 else { return }

            // ── 2. Body segments (D-01 / D-02) ──────────────────────────────────
            // Iterate tail-adjacent to head so the head pair is painted last (= on top),
            // ensuring the head and eye dots read correctly during any brief overlap.
            // ArcadePalette index 0 = head/most-saturated (chart1) per D-02.
            let segCount = snakeBody.count - 1
            for i in stride(from: segCount - 1, through: 0, by: -1) {
                let headSideCell = snakeBody[i]       // closer to head
                let tailSideCell = snakeBody[i + 1]   // further from head

                // Wrap-boundary guard (Common Pitfall 1 / 17-RESEARCH §5):
                // In toroidal mode the snake head can jump from col 0 → col 19.
                // The prev/curr lerp would then streak a line across the board.
                // Detect jumps > half the grid and skip the connecting stroke;
                // each segment's rounded cap provides the clean edge exit/entry cue.
                let colJump = abs(headSideCell.col - tailSideCell.col)
                let rowJump = abs(headSideCell.row - tailSideCell.row)
                guard colJump <= cols / 2 && rowJump <= rows / 2 else { continue }

                let tailPt = segPos(i + 1, cellSize: cellSize, alpha: alpha)
                let headPt = segPos(i,     cellSize: cellSize, alpha: alpha)

                var seg = Path()
                seg.move(to: tailPt)
                seg.addLine(to: headPt)

                let layer = ArcadePalette.layer(forIndex: i, theme: theme)

                // D-08 head pulse: scale head-segment stroke width by (1 + 0.25 × headPulse).
                // Stays 0.0 when fxEnabled is false or reduceMotion is true (prop contract).
                let lineWidth: CGFloat = i == 0
                    ? cellSize * 0.78 * CGFloat(1.0 + 0.25 * headPulse)
                    : cellSize * 0.78

                let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

                // Base token color, then overlay next-stop token at blend opacity for the
                // smooth head-to-tail gradient (alpha-blend lerp with token-only colors).
                ctx.stroke(seg, with: .color(layer.base), style: style)
                if layer.blend > 0.001 {
                    ctx.stroke(seg, with: .color(layer.next.opacity(layer.blend)), style: style)
                }
            }

            // ── 3. Head eye dots (D-01) ──────────────────────────────────────────
            // Two small background-colored circles offset toward the travel direction.
            // Drawn after all body segments so they're never obscured.
            let headCenter = segPos(0, cellSize: cellSize, alpha: alpha)
            drawEyes(ctx, at: headCenter, cellSize: cellSize)

            // ── 4. Food circle ───────────────────────────────────────────────────
            // Filled circle in theme.colors.success. Shape (circle) and color (success)
            // contrast with the body stroke so it reads on all presets (SNAKE-06/§8.12).
            let foodX = (CGFloat(food.col) + 0.5) * cellSize
            let foodY = (CGFloat(food.row) + 0.5) * cellSize
            let foodR = cellSize * 0.30
            ctx.fill(
                Path(ellipseIn: CGRect(x: foodX - foodR, y: foodY - foodR,
                                       width: foodR * 2, height: foodR * 2)),
                with: .color(theme.colors.success)
            )
        }
    }

    // MARK: - Gaffer interpolation helper

    /// Lerps `prevBody[i]` → `snakeBody[i]` at `alpha`, returning the cell-center CGPoint.
    ///
    /// - `alpha = 0.0` → returns the pre-move (`prevBody`) position.
    /// - `alpha = 1.0` → returns the fully advanced post-move position (SNAKE-07 RM jump-cut).
    /// - Falls back to `snakeBody[i]` as `prev` when `prevBody` is shorter than `snakeBody`
    ///   (growth step: the engine appended a new tail cell this move).
    private func segPos(_ i: Int, cellSize: CGFloat, alpha: Double) -> CGPoint {
        let curr = snakeBody[i]
        let prev = i < prevBody.count ? prevBody[i] : curr
        let lerpCol = Double(prev.col) + (Double(curr.col) - Double(prev.col)) * alpha
        let lerpRow = Double(prev.row) + (Double(curr.row) - Double(prev.row)) * alpha
        return CGPoint(x: (lerpCol + 0.5) * cellSize,
                       y: (lerpRow + 0.5) * cellSize)
    }

    // MARK: - Eye dot rendering

    /// Draws two small eye dots on the head, offset toward the direction of travel (D-01).
    ///
    /// Eyes are filled with `theme.colors.background` to remain legible against any body
    /// fill color, across all presets (SNAKE-06 token discipline).
    private func drawEyes(_ ctx: GraphicsContext, at headPt: CGPoint, cellSize: CGFloat) {
        let eyeRadius = cellSize * 0.11
        let forwardOffset = cellSize * 0.14   // shift toward the direction of travel
        let lateralOffset = cellSize * 0.14   // perpendicular spacing between the two eyes

        // Decompose currentDirection into (forward, lateral) CGFloat offsets.
        let (fX, fY, lX, lY): (CGFloat, CGFloat, CGFloat, CGFloat)
        switch currentDirection {
        case .right: (fX, fY, lX, lY) = ( forwardOffset,          0,           0, lateralOffset)
        case .left:  (fX, fY, lX, lY) = (-forwardOffset,          0,           0, lateralOffset)
        case .up:    (fX, fY, lX, lY) = (            0, -forwardOffset, lateralOffset,          0)
        case .down:  (fX, fY, lX, lY) = (            0,  forwardOffset, lateralOffset,          0)
        }

        // Draw each eye by mirroring the lateral offset with +1 / -1.
        for sign: CGFloat in [1, -1] {
            let center = CGPoint(x: headPt.x + fX + lX * sign,
                                 y: headPt.y + fY + lY * sign)
            ctx.fill(
                Path(ellipseIn: CGRect(x: center.x - eyeRadius,
                                       y: center.y - eyeRadius,
                                       width:  eyeRadius * 2,
                                       height: eyeRadius * 2)),
                with: .color(theme.colors.background)
            )
        }
    }
}
