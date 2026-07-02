//
//  StackBoardCanvas.swift
//  gamekit
//
//  Immediate-mode `Canvas` render for the Stack tower: pseudo-3D shaded
//  blocks, the sliding block, falling trim pieces, perfect-drop pulses,
//  and landing flashes. Camera/scroll lives here in the view layer — the
//  engine never reads geometry or motion state.
//
//  Camera: the world scrolls DOWN as the tower grows so the sliding block
//  holds a fixed screen height once the tower is tall enough. Each
//  placement eases the camera one block-height over ~0.35s (snap under
//  Reduce Motion / animations-off).
//
//  Gaffer interpolation (non-RM): the sliding block's on-screen position is
//  linearly interpolated between the previous-tick center (`prevCenterX`)
//  and the current-tick center (`frame.currentCenterX`) using `accAlpha`.
//
//  Token discipline: all colors come from DesignKit semantic tokens via
//  `StackPalette` and `theme.colors.*`. Face shading (lighter top, darker
//  side) is produced by re-compositing the SAME token color under .screen /
//  .multiply blend modes — no raw color initializers (CLAUDE.md §1, D-07).
//
//  Pitfall 18 guard: no SwiftUI implicit-animation modifier is applied to
//  board state in this file. All motion is computed inside the draw closure
//  from `now` (TimelineView date) and engine snapshots.
//

import SwiftUI
import DesignKit

/// Immediate-mode `Canvas` board view for Stack. **Props-only.**
struct StackBoardCanvas: View {

    // MARK: - Props

    /// Tower blocks from the engine snapshot (index 0 = base block).
    let placed: [PlacedBlock]

    /// Latest engine frame — sliding block position + game-state.
    let frame: StackFrame

    /// Sliding block center at the previous engine tick (Gaffer interpolation).
    let prevCenterX: Double

    /// Accumulator remainder ÷ fixedDt, in [0, 1].
    let accAlpha: Double

    /// Active DesignKit theme — all colors derive from its tokens.
    let theme: Theme

    /// Timeline date driving time-based FX (camera ease, falls, pulses).
    let now: Date

    /// True when time-based motion is allowed
    /// (`animationsEnabled && !reduceMotion`). False → everything snaps.
    let fxEnabled: Bool

    /// When true, the slider snaps to the engine's tick-boundary value (D-08).
    let reduceMotion: Bool

    /// Timestamp of the most recent block placement — drives the camera ease.
    let lastPlacementAt: Date?

    /// Severed overhang pieces currently falling (spawned by the view).
    let fallingPieces: [FallingTrimPiece]

    /// Active perfect-drop pulse rings.
    let perfectPulses: [PerfectPulse]

    /// Brightness flash on the block that just landed.
    let landingFlash: LandingFlash?

    // MARK: - Layout constants (all geometry derives from blockH)

    /// Number of block heights visible in the viewport.
    private static let visibleBlocks: CGFloat = 12

    /// Screen slot (in block heights from the bottom) where the slider
    /// settles once the tower is tall enough to scroll.
    private static let sliderSlot: Double = 7

    /// Camera ease duration per placement.
    private static let cameraEase: TimeInterval = 0.35

    // MARK: - Body

    var body: some View {
        Canvas { ctx, size in
            let blockH = size.height / Self.visibleBlocks
            let depthX = blockH * 0.55
            let depthY = blockH * 0.32
            let playW  = size.width - depthX
            let camPx  = cameraBlocks() * blockH

            func rowRect(_ block: PlacedBlock, row: Int) -> CGRect {
                CGRect(x: CGFloat(block.centerX - block.width / 2) * playW,
                       y: size.height - CGFloat(row + 1) * blockH + camPx,
                       width: CGFloat(block.width) * playW,
                       height: blockH)
            }

            // Placed tower blocks (bottom-to-top; cull outside the viewport).
            for (i, block) in placed.enumerated() {
                let rect = rowRect(block, row: i)
                if rect.minY > size.height { continue }   // scrolled below viewport
                if rect.maxY < 0 { break }                // above viewport — all higher rows too
                let layer = StackPalette.layer(forIndex: i, theme: theme)
                drawShadedBlock(ctx, rect: rect, depthX: depthX, depthY: depthY, layer: layer)

                if fxEnabled, let flash = landingFlash, flash.rowIndex == i,
                   !flash.isExpired(at: now) {
                    drawLandingFlash(ctx, rect: rect, depthX: depthX, depthY: depthY,
                                     layer: layer, age: flash.age(at: now))
                }
            }

            // Falling trim pieces — on top of the tower, below the slider.
            if fxEnabled {
                for piece in fallingPieces where !piece.isExpired(at: now) {
                    drawFallingPiece(ctx, piece, blockH: blockH, playW: playW,
                                     camPx: camPx, depthX: depthX, depthY: depthY,
                                     size: size)
                }
                for pulse in perfectPulses where !pulse.isExpired(at: now) {
                    guard pulse.rowIndex < placed.count else { continue }
                    drawPerfectPulse(ctx, rect: rowRect(placed[pulse.rowIndex],
                                                        row: pulse.rowIndex),
                                     blockH: blockH, age: pulse.age(at: now))
                }
            }

            // Sliding block — hidden after game over.
            guard !frame.gameOver else { return }

            // Gaffer interpolation: lerp prevCenterX → currentCenterX (snap under RM).
            let renderCX = reduceMotion
                ? frame.currentCenterX
                : prevCenterX + (frame.currentCenterX - prevCenterX) * accAlpha

            let sliderRect = rowRect(
                PlacedBlock(centerX: renderCX, width: frame.currentWidth),
                row: placed.count
            )
            drawShadedBlock(ctx, rect: sliderRect, depthX: depthX, depthY: depthY,
                            layer: StackPalette.layer(forIndex: placed.count, theme: theme))
        }
    }

    // MARK: - Camera

    /// Camera offset in block heights. Target keeps the slider at
    /// `sliderSlot` block heights above the viewport bottom; each placement
    /// eases the last block-height of travel over `cameraEase` seconds.
    private func cameraBlocks() -> CGFloat {
        let target = max(0, Double(placed.count + 1) - Self.sliderSlot)
        guard fxEnabled, target > 0, let t0 = lastPlacementAt else {
            return CGFloat(target)
        }
        let progress = now.timeIntervalSince(t0) / Self.cameraEase
        guard progress < 1 else { return CGFloat(target) }
        let from = max(0, target - 1)
        let eased = 1 - pow(1 - max(progress, 0), 3)   // ease-out cubic
        return CGFloat(from + (target - from) * eased)
    }

    // MARK: - Block rendering (pseudo-3D, token-only shading)

    /// Draws one block as three faces: front (flat), top (lightened via
    /// .screen self-blend), right side (darkened via .multiply self-blend).
    /// The `layer.next`-over-`layer.base` composite is an alpha-blend lerp
    /// between adjacent chart tokens — the smooth tower gradient.
    private func drawShadedBlock(_ ctx: GraphicsContext, rect: CGRect,
                                 depthX: CGFloat, depthY: CGFloat,
                                 layer: StackPalette.Layer) {
        let front = Path(rect)
        let top = polygon([
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.minX + depthX, y: rect.minY - depthY),
            CGPoint(x: rect.maxX + depthX, y: rect.minY - depthY),
            CGPoint(x: rect.maxX, y: rect.minY),
        ])
        let side = polygon([
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX + depthX, y: rect.minY - depthY),
            CGPoint(x: rect.maxX + depthX, y: rect.maxY - depthY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ])

        for path in [front, top, side] {
            ctx.fill(path, with: .color(layer.base))
            if layer.blend > 0.001 {
                ctx.fill(path, with: .color(layer.next.opacity(layer.blend)))
            }
        }

        // Face shading — same token color re-composited, never a raw color.
        var light = ctx
        light.blendMode = .screen
        light.fill(top, with: .color(layer.base.opacity(0.55)))

        var dark = ctx
        dark.blendMode = .multiply
        dark.fill(side, with: .color(layer.base.opacity(0.6)))
    }

    // MARK: - FX rendering

    /// Severed overhang: gravity fall + outward drift + rotation + fade.
    private func drawFallingPiece(_ ctx: GraphicsContext, _ piece: FallingTrimPiece,
                                  blockH: CGFloat, playW: CGFloat, camPx: CGFloat,
                                  depthX: CGFloat, depthY: CGFloat, size: CGSize) {
        let t = piece.age(at: now)
        let dir: CGFloat = piece.fallsRight ? 1 : -1
        let fall  = CGFloat(0.5 * 26 * t * t) * blockH          // gravity, blockH/s²
        let drift = dir * CGFloat(t) * blockH * 1.2
        let rect = CGRect(
            x: CGFloat(piece.centerX - piece.width / 2) * playW + drift,
            y: size.height - CGFloat(piece.rowIndex + 1) * blockH + camPx + fall,
            width: CGFloat(piece.width) * playW,
            height: blockH
        )

        var pctx = ctx
        pctx.opacity = max(0, 1 - t / FallingTrimPiece.lifetime)
        pctx.translateBy(x: rect.midX, y: rect.midY)
        pctx.rotate(by: .radians(Double(dir) * t * 2.0))
        pctx.translateBy(x: -rect.midX, y: -rect.midY)
        drawShadedBlock(pctx, rect: rect, depthX: depthX, depthY: depthY,
                        layer: StackPalette.layer(forIndex: piece.rowIndex, theme: theme))
    }

    /// Perfect drop: outline ring expanding out from the block and fading.
    /// `textPrimary` guarantees contrast against the tower on every preset.
    private func drawPerfectPulse(_ ctx: GraphicsContext, rect: CGRect,
                                  blockH: CGFloat, age: TimeInterval) {
        let tt = age / PerfectPulse.lifetime
        let eased = 1 - pow(1 - tt, 2)                          // ease-out quad
        let grow = CGFloat(eased) * blockH * 0.7
        let ring = Path(roundedRect: rect.insetBy(dx: -grow, dy: -grow),
                        cornerRadius: blockH * 0.15, style: .continuous)
        var rctx = ctx
        rctx.opacity = (1 - tt) * 0.9
        rctx.stroke(ring, with: .color(theme.colors.textPrimary),
                    lineWidth: blockH * 0.06)
    }

    /// Landing impact: brief brightness flash on the front + top faces,
    /// produced by .screen self-blending the block's own token color.
    private func drawLandingFlash(_ ctx: GraphicsContext, rect: CGRect,
                                  depthX: CGFloat, depthY: CGFloat,
                                  layer: StackPalette.Layer, age: TimeInterval) {
        let strength = (1 - age / LandingFlash.lifetime) * 0.8
        let top = polygon([
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.minX + depthX, y: rect.minY - depthY),
            CGPoint(x: rect.maxX + depthX, y: rect.minY - depthY),
            CGPoint(x: rect.maxX, y: rect.minY),
        ])
        var flash = ctx
        flash.blendMode = .screen
        flash.fill(Path(rect), with: .color(layer.base.opacity(strength)))
        flash.fill(top, with: .color(layer.base.opacity(strength)))
    }

    // MARK: - Path helper

    private func polygon(_ points: [CGPoint]) -> Path {
        var p = Path()
        p.move(to: points[0])
        for pt in points.dropFirst() { p.addLine(to: pt) }
        p.closeSubpath()
        return p
    }
}
