//
//  SurfaceDepth.swift
//  gamekit
//
//  Shared physical-depth treatments for interactive surfaces (DESIGN.md §3):
//  a soft drop shadow under chips/keys/tiles, a vertical sheen on raised
//  tiles, and an accent glow for actively-held elements.
//
//  These are lighting effects, not theme colors — light comes from the top
//  on every preset, so the white/black literals here are intentional and
//  identical across Classic and Dracula alike. That's why this lives in
//  Core/ (outside the Games/Screens token hook): game views consume the
//  helpers and never touch a color literal themselves. Do NOT reach for
//  these literals directly in a game view.
//

import SwiftUI

enum SurfaceDepth {
    /// Vertical sheen for raised interactive tiles: a whisper of light on
    /// the top edge, a whisper of shade at the bottom. Overlay on top of
    /// the tile's themed fill.
    static var raisedSheen: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.16), location: 0),
                .init(color: Color.white.opacity(0), location: 0.38),
                .init(color: Color.black.opacity(0), location: 0.62),
                .init(color: Color.black.opacity(0.08), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Ambient shadow color for chips, keys, and floating tiles.
    static let shadow = Color.black.opacity(0.10)
}

extension View {
    /// Soft ambient shadow for chip-sized surfaces (info chips, mode pills,
    /// pad keys, board tiles). One treatment everywhere so elevation reads
    /// consistently across games.
    func chipShadow() -> some View {
        shadow(color: SurfaceDepth.shadow, radius: 5, x: 0, y: 2)
    }

    /// Accent-tinted glow for an element the player is actively holding or
    /// tracing (e.g. Word Grid tiles under the finger).
    func activeGlow(_ color: Color, active: Bool) -> some View {
        shadow(
            color: active ? color.opacity(0.45) : SurfaceDepth.shadow,
            radius: active ? 8 : 5,
            x: 0,
            y: active ? 3 : 2
        )
    }
}
