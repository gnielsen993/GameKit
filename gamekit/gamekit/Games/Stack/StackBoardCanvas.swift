//
//  StackBoardCanvas.swift
//  gamekit
//
//  Immediate-mode `Canvas` render for the Stack tower: true isometric
//  (2:1 dimetric) projection of length × width × height blocks, the
//  sliding block, falling trim pieces, perfect-drop pulses, and landing
//  flashes. Camera/scroll lives here in the view layer — the engine never
//  reads geometry or motion state.
//
//  Projection: world (x, z) is the engine's normalized ground plane; h is
//  height in block units. screenX = midX + (x − z)·isoW, screenY = baseY −
//  h·blockH + (x + z − 1)·isoH + camPx. Fixed camera angle — no perspective,
//  exactly the classic Stack look. Three faces per box: top, +x (right),
//  +z (left).
//
//  Camera: the world scrolls DOWN as the tower grows so the sliding block
//  holds a fixed screen height once the tower is tall enough. Each
//  placement eases the camera one block-height over ~0.35s (snap under
//  Reduce Motion / animations-off).
//
//  Gaffer interpolation (non-RM): the sliding block's on-screen position is
//  linearly interpolated between the previous-tick centers and the
//  current-tick centers using `accAlpha` — both axes; the inactive axis is
//  constant so its lerp is a no-op.
//
//  Token discipline: all colors come from DesignKit semantic tokens via
//  `StackPalette` and `theme.colors.*`. Face shading (lighter top, two
//  distinct side darknesses) is produced by re-compositing the SAME token
//  color under .screen / .multiply blend modes — no raw color initializers
//  (CLAUDE.md §1, D-07).
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

    /// Slider centers at the previous engine tick (Gaffer interpolation).
    let prevCenterX: Double
    let prevCenterZ: Double

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

    /// Active perfect-drop settle glide (placed block eases to its snapped center).
    let settleGlide: SettleGlide?

    /// Height of the region at the canvas bottom that gameplay must stay
    /// above — the home-indicator inset in normal mode, plus the reserved
    /// video band in Video Mode large-bottom. The playfield anchors to the
    /// logical bottom (`size.height - bottomObscured`); the base pedestal
    /// keeps drawing past it so the tower fills the physical bottom instead
    /// of floating over a background strip.
    var bottomObscured: CGFloat = 0

    // MARK: - Layout constants (all geometry derives from blockH / isoW)

    /// Number of block heights visible in the viewport. Higher = slimmer
    /// tiers relative to the footprint — the tower leans slim, not bulky.
    private static let visibleBlocks: CGFloat = 16

    /// Screen slot (in block heights from the bottom) where the slider
    /// settles once the tower is tall enough to scroll. Just above center:
    /// the action line holds mid-screen and the tower fills the screen
    /// below it. Early game the camera clamps at 0 — the tower starts near
    /// the screen bottom and grows up to this slot before any scrolling.
    private static let sliderSlot: Double = 8.5

    /// Camera ease duration per placement.
    private static let cameraEase: TimeInterval = 0.35

    /// Half-width of one world unit on screen (fraction of canvas width).
    /// The playfield diagonal spans 2·isoW horizontally.
    private static let isoWidthFraction: CGFloat = 0.48

    // MARK: - Projection

    /// Fixed-camera isometric projection parameters for one draw pass.
    private struct Iso {
        let midX: CGFloat
        let baseY: CGFloat
        let isoW: CGFloat
        let isoH: CGFloat
        let blockH: CGFloat
        let camPx: CGFloat

        /// Projects world (x, z, height-in-blocks) to screen.
        func point(_ x: Double, _ z: Double, h: Double) -> CGPoint {
            CGPoint(x: midX + CGFloat(x - z) * isoW,
                    y: baseY - CGFloat(h) * blockH + CGFloat(x + z - 1) * isoH + camPx)
        }
    }

    // MARK: - Body

    var body: some View {
        Canvas { ctx, size in
            // Gameplay framing derives from the LOGICAL height (above any
            // obscured bottom band); the pedestal still paints the full
            // physical height below it.
            let logicalH = size.height - bottomObscured
            let blockH = logicalH / Self.visibleBlocks
            let isoW = size.width * Self.isoWidthFraction
            let iso = Iso(midX: size.width / 2,
                          baseY: logicalH - isoW * 0.5,
                          isoW: isoW,
                          isoH: isoW * 0.5,       // classic 2:1 dimetric
                          blockH: blockH,
                          camPx: cameraBlocks() * blockH)

            // Placed tower blocks (bottom-to-top; cull outside the viewport).
            for (i, block) in placed.enumerated() {
                var (cx, cz) = (block.centerX, block.centerZ)

                // Viewport cull: highest possible point vs lowest possible point.
                let topY = iso.point(cx - block.width / 2, cz - block.depth / 2,
                                     h: Double(i + 1)).y
                let botY = iso.point(cx + block.width / 2, cz + block.depth / 2,
                                     h: Double(i)).y
                if topY > size.height { continue }   // scrolled below viewport
                if botY < 0 { break }                // above viewport — all higher rows too

                // Perfect-drop settle: glide from the rendered drop position
                // to the snapped center (ease-out) instead of teleporting.
                if fxEnabled, let glide = settleGlide, glide.rowIndex == i,
                   !glide.isExpired(at: now) {
                    let p = glide.age(at: now) / SettleGlide.lifetime
                    let eased = 1 - pow(1 - p, 3)
                    cx = glide.fromCenterX + (block.centerX - glide.fromCenterX) * eased
                    cz = glide.fromCenterZ + (block.centerZ - glide.fromCenterZ) * eased
                }

                // Base block renders as a pedestal column extending below the
                // screen — the tower is never a lone slab floating mid-air.
                let hBottom = i == 0 ? -Double(Self.visibleBlocks) : Double(i)

                let layer = StackPalette.layer(forIndex: i, theme: theme)
                drawShadedBox(ctx, iso: iso, cx: cx, cz: cz,
                              width: block.width, depth: block.depth,
                              hBottom: hBottom, hTop: Double(i + 1), layer: layer)

                if fxEnabled, let flash = landingFlash, flash.rowIndex == i,
                   !flash.isExpired(at: now) {
                    drawLandingFlash(ctx, iso: iso, cx: cx, cz: cz,
                                     width: block.width, depth: block.depth,
                                     row: i, layer: layer, age: flash.age(at: now))
                }
            }

            // Falling trim pieces — on top of the tower, below the slider.
            if fxEnabled {
                for piece in fallingPieces where !piece.isExpired(at: now) {
                    drawFallingPiece(ctx, piece, iso: iso)
                }
                for pulse in perfectPulses where !pulse.isExpired(at: now) {
                    guard pulse.rowIndex < placed.count else { continue }
                    drawPerfectPulse(ctx, iso: iso, block: placed[pulse.rowIndex],
                                     row: pulse.rowIndex, age: pulse.age(at: now))
                }
            }

            // Sliding block — hidden after game over.
            guard !frame.gameOver else { return }

            // Gaffer interpolation: lerp prev → current centers (snap under RM).
            let renderCX = reduceMotion
                ? frame.currentCenterX
                : prevCenterX + (frame.currentCenterX - prevCenterX) * accAlpha
            let renderCZ = reduceMotion
                ? frame.currentCenterZ
                : prevCenterZ + (frame.currentCenterZ - prevCenterZ) * accAlpha

            let row = placed.count
            drawShadedBox(ctx, iso: iso, cx: renderCX, cz: renderCZ,
                          width: frame.currentWidth, depth: frame.currentDepth,
                          hBottom: Double(row), hTop: Double(row + 1),
                          layer: StackPalette.layer(forIndex: row, theme: theme))
        }
    }

    // MARK: - Camera

    /// Camera offset in block heights, clamped at 0. Early game the tower
    /// grows up from the screen bottom with no scrolling; once the slider
    /// would pass `sliderSlot`, each placement scrolls the world down one
    /// block-height so the action line holds that slot. The scroll eases
    /// over `cameraEase` seconds (snap when FX are gated off).
    private func cameraBlocks() -> CGFloat {
        let target = max(0, Double(placed.count + 1) - Self.sliderSlot)
        guard fxEnabled, let t0 = lastPlacementAt else { return CGFloat(target) }
        let from = max(0, Double(placed.count) - Self.sliderSlot)
        guard from < target else { return CGFloat(target) }   // still below the slot — nothing to ease
        let progress = now.timeIntervalSince(t0) / Self.cameraEase
        guard progress < 1 else { return CGFloat(target) }
        let eased = 1 - pow(1 - max(progress, 0), 3)   // ease-out cubic
        return CGFloat(from + (target - from) * eased)
    }

    // MARK: - Box rendering (isometric, token-only shading)

    /// Ground-plane footprint corners, far-to-near:
    /// A = (x0, z0) far, B = (x1, z0) right, C = (x1, z1) near, D = (x0, z1) left.
    private struct Corners {
        let x0, x1, z0, z1: Double
        init(cx: Double, cz: Double, width: Double, depth: Double) {
            x0 = cx - width / 2; x1 = cx + width / 2
            z0 = cz - depth / 2; z1 = cz + depth / 2
        }
    }

    private func topFace(_ iso: Iso, _ c: Corners, hTop: Double) -> Path {
        polygon([iso.point(c.x0, c.z0, h: hTop), iso.point(c.x1, c.z0, h: hTop),
                 iso.point(c.x1, c.z1, h: hTop), iso.point(c.x0, c.z1, h: hTop)])
    }

    private func rightFace(_ iso: Iso, _ c: Corners, hBottom: Double, hTop: Double) -> Path {
        polygon([iso.point(c.x1, c.z0, h: hTop), iso.point(c.x1, c.z1, h: hTop),
                 iso.point(c.x1, c.z1, h: hBottom), iso.point(c.x1, c.z0, h: hBottom)])
    }

    private func leftFace(_ iso: Iso, _ c: Corners, hBottom: Double, hTop: Double) -> Path {
        polygon([iso.point(c.x0, c.z1, h: hTop), iso.point(c.x1, c.z1, h: hTop),
                 iso.point(c.x1, c.z1, h: hBottom), iso.point(c.x0, c.z1, h: hBottom)])
    }

    /// Draws one box as three visible faces: top (lightened via .screen
    /// self-blend), +x right side (mildly darkened), +z left side (darker) —
    /// the two distinct side shades are what sells the volume. The
    /// `layer.next`-over-`layer.base` composite is an alpha-blend lerp
    /// between adjacent chart tokens — the smooth tower gradient.
    private func drawShadedBox(_ ctx: GraphicsContext, iso: Iso,
                               cx: Double, cz: Double,
                               width: Double, depth: Double,
                               hBottom: Double, hTop: Double,
                               layer: StackPalette.Layer) {
        let c = Corners(cx: cx, cz: cz, width: width, depth: depth)
        let top = topFace(iso, c, hTop: hTop)
        let right = rightFace(iso, c, hBottom: hBottom, hTop: hTop)
        let left = leftFace(iso, c, hBottom: hBottom, hTop: hTop)

        for path in [top, right, left] {
            ctx.fill(path, with: .color(layer.base))
            if layer.blend > 0.001 {
                ctx.fill(path, with: .color(layer.next.opacity(layer.blend)))
            }
        }

        // Face shading — same token color re-composited, never a raw color.
        var light = ctx
        light.blendMode = .screen
        light.fill(top, with: .color(layer.base.opacity(0.55)))

        var midDark = ctx
        midDark.blendMode = .multiply
        midDark.fill(right, with: .color(layer.base.opacity(0.4)))

        var dark = ctx
        dark.blendMode = .multiply
        dark.fill(left, with: .color(layer.base.opacity(0.65)))
    }

    // MARK: - FX rendering

    /// Severed piece: gentle gravity fall (world height), outward drift along
    /// the trim axis, and a slow screen-space tumble. Opacity holds full for
    /// the first 40% of the lifetime, then fades — the piece visibly
    /// detaches and drops instead of darting away.
    private func drawFallingPiece(_ ctx: GraphicsContext, _ piece: FallingTrimPiece,
                                  iso: Iso) {
        let t = piece.age(at: now)
        let dir: Double = piece.fallsPositive ? 1 : -1
        let fallBlocks = 0.5 * 18 * t * t              // gravity, block-heights/s²
        let drift = dir * t * 0.22                     // world units along the trim axis

        let cx = piece.centerX + (piece.axis == .x ? drift : 0)
        let cz = piece.centerZ + (piece.axis == .z ? drift : 0)
        let hBottom = Double(piece.rowIndex) - fallBlocks

        let life = t / FallingTrimPiece.lifetime
        let fade = max(0, 1 - max(0, life - FallingTrimPiece.fadeStart)
                            / (1 - FallingTrimPiece.fadeStart))

        // Screen-space tumble about the piece's projected center.
        let pivot = iso.point(cx, cz, h: hBottom + 0.5)
        var pctx = ctx
        pctx.opacity = fade
        pctx.translateBy(x: pivot.x, y: pivot.y)
        pctx.rotate(by: .radians(dir * t * 0.9))
        pctx.translateBy(x: -pivot.x, y: -pivot.y)
        drawShadedBox(pctx, iso: iso, cx: cx, cz: cz,
                      width: piece.width, depth: piece.depth,
                      hBottom: hBottom, hTop: hBottom + 1,
                      layer: StackPalette.layer(forIndex: piece.rowIndex, theme: theme))
    }

    /// Perfect drop: the block's top-face outline expanding outward from its
    /// centroid and fading. `textPrimary` guarantees contrast against the
    /// tower on every preset.
    private func drawPerfectPulse(_ ctx: GraphicsContext, iso: Iso,
                                  block: PlacedBlock, row: Int, age: TimeInterval) {
        let tt = age / PerfectPulse.lifetime
        let eased = 1 - pow(1 - tt, 2)                          // ease-out quad
        let scale = 1 + eased * 0.35
        let c = Corners(cx: block.centerX, cz: block.centerZ,
                        width: block.width * scale, depth: block.depth * scale)
        let ring = topFace(iso, c, hTop: Double(row + 1))
        var rctx = ctx
        rctx.opacity = (1 - tt) * 0.9
        rctx.stroke(ring, with: .color(theme.colors.textPrimary),
                    lineWidth: iso.blockH * 0.06)
    }

    /// Landing impact: brief brightness flash across all three faces,
    /// produced by .screen self-blending the block's own token color.
    private func drawLandingFlash(_ ctx: GraphicsContext, iso: Iso,
                                  cx: Double, cz: Double,
                                  width: Double, depth: Double, row: Int,
                                  layer: StackPalette.Layer, age: TimeInterval) {
        let strength = (1 - age / LandingFlash.lifetime) * 0.6
        let c = Corners(cx: cx, cz: cz, width: width, depth: depth)
        var flash = ctx
        flash.blendMode = .screen
        flash.fill(topFace(iso, c, hTop: Double(row + 1)),
                   with: .color(layer.base.opacity(strength)))
        flash.fill(rightFace(iso, c, hBottom: Double(row), hTop: Double(row + 1)),
                   with: .color(layer.base.opacity(strength)))
        flash.fill(leftFace(iso, c, hBottom: Double(row), hTop: Double(row + 1)),
                   with: .color(layer.base.opacity(strength)))
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
