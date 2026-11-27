//
//  PieceButtonStyle.swift
//  gamekit
//
//  The piece (DESIGN.md §3.8): a solid face over a visible lower edge. The
//  face sinks by `travel` under the finger and springs back. This is the
//  single source of depth for pressable controls converted in Phase 19.1;
//  PressableButtonStyle (the 1.6 scale press) stays for unconverted games.
//
//  Construction order matters (research "Piece Primitive Design"): face,
//  pressed cue, offset, edge as a background of the offset face, bottom
//  padding reserving the edge, and the hit region last on the un-offset
//  frame (spike A4). No branch on preset, appearance or Classic (D-11).
//

import SwiftUI
import DesignKit

enum PieceRole {
    case neutral
    case filled(Color)
}

enum PieceShape {
    case rounded(CGFloat)
    case capsule
    case circle

    var anyShape: AnyShape {
        switch self {
        case .rounded(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .capsule:
            return AnyShape(Capsule())
        case .circle:
            return AnyShape(Circle())
        }
    }
}

struct PieceButtonStyle: ButtonStyle {
    let theme: Theme
    var role: PieceRole = .neutral
    var shape: PieceShape
    var size: PieceSize = .regular

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.isEnabled) private var isEnabled

    #if DEBUG
    @AppStorage(PieceStrength.defaultsKey) private var strengthRaw: String = PieceStrength.medium.rawValue
    private var spec: PieceSpec { PieceSpec.resolved(strengthRaw: strengthRaw) }
    #else
    private var spec: PieceSpec { PieceSpec.current }
    #endif

    func makeBody(configuration: Configuration) -> some View {
        let depth = spec.depth(for: size)
        let travel = spec.travel(for: size)
        let motion = settingsStore.animationsEnabled && !reduceMotion
        let down = configuration.isPressed && isEnabled
        let anyShape = shape.anyShape
        let pressAnimation: Animation? = motion
            ? (down
                ? .easeOut(duration: spec.pressInDuration)
                : .spring(response: spec.releaseResponse, dampingFraction: spec.releaseDamping))
            : nil

        return configuration.label
            .background(faceFill(anyShape))
            .clipShape(anyShape)
            .overlay {
                if down { anyShape.fill(theme.colors.fillPressed) }
            }
            .offset(y: PieceGeometry.faceOffset(
                pressed: down, motion: motion, enabled: isEnabled, depth: depth, travel: travel
            ))
            .background(alignment: .top) {
                edge(anyShape, depth: depth)
            }
            .padding(.bottom, depth)
            .contentShape(Rectangle())
            .animation(pressAnimation, value: down)
    }

    @ViewBuilder
    private func faceFill(_ anyShape: AnyShape) -> some View {
        switch role {
        case .neutral:
            anyShape.fill(theme.colors.surface)
        case .filled(let color):
            anyShape.fill(color)
        }
    }

    /// The lower edge, drawn at the face's frame and pushed down by `depth`.
    /// Large pieces add a contact shadow, cast by a face-position layer
    /// behind the edge (no blurred shadow on the nine pad keys, pitfall 10).
    @ViewBuilder
    private func edge(_ anyShape: AnyShape, depth: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if size == .large {
                edgeFill(anyShape)
                    .pieceContactShadow(depth: depth)
            }
            edgeFill(anyShape)
                .offset(y: depth)
        }
    }

    @ViewBuilder
    private func edgeFill(_ anyShape: AnyShape) -> some View {
        switch role {
        case .neutral:
            ZStack {
                anyShape.fill(theme.colors.surface)
                anyShape.fill(theme.colors.textPrimary.opacity(SurfaceDepth.pieceNeutralEdgeInkOpacity))
            }
        case .filled(let color):
            ZStack {
                anyShape.fill(color)
                anyShape.fill(SurfaceDepth.pieceFilledEdgeShade)
            }
        }
    }
}

extension ButtonStyle where Self == PieceButtonStyle {
    /// The piece press style (DESIGN.md §3.8).
    static func piece(
        theme: Theme,
        role: PieceRole = .neutral,
        shape: PieceShape,
        size: PieceSize = .regular
    ) -> PieceButtonStyle {
        PieceButtonStyle(theme: theme, role: role, shape: shape, size: size)
    }
}
