//
//  PressableButtonStyle.swift
//  gamekit
//
//  Shared press feedback for interactive game chrome (DESIGN.md §10.2):
//  a subtle scale-down while the finger is on the control, springing back
//  on release. Applied to number pads, keyboards, board-adjacent buttons,
//  and Home tiles so every press in the app answers with the same weight.
//
//  Gated on Reduce Motion + the Settings animations toggle — when off,
//  the control still dims slightly on press (functional affordance) but
//  never moves.
//

import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.settingsStore) private var settingsStore

    /// Scale applied while pressed. 0.94 reads as tactile without wobble;
    /// large surfaces (Home tiles) pass 0.97 so the shrink stays subtle.
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        let animated = settingsStore.animationsEnabled && !reduceMotion
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(animated && configuration.isPressed ? scale : 1)
            .animation(
                animated ? .spring(response: 0.22, dampingFraction: 0.7) : nil,
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// Standard press feedback (scale 0.94).
    static var pressable: PressableButtonStyle { PressableButtonStyle() }

    /// Gentler press feedback for large surfaces like Home tiles.
    static var pressableSubtle: PressableButtonStyle { PressableButtonStyle(scale: 0.97) }
}
