//
//  MotionGate.swift
//  gamekit
//
//  Shared gate for feedback animations (DESIGN.md §10.2): any animation
//  that expresses delight or consequence must hard-cut when Reduce Motion
//  is on OR the user has disabled animations in Settings.
//
//  `feedbackAnimation(_:value:)` is the single idiom for implicit
//  animations — it reads both gates from the environment so props-only
//  leaf views stay prop-driven (the gate lives here, not in each view).
//  For imperative `withAnimation` call sites, read the same two
//  environment values and pass nil when gated.
//

import SwiftUI

struct FeedbackAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.settingsStore) private var settingsStore

    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(
            settingsStore.animationsEnabled && !reduceMotion ? animation : nil,
            value: value
        )
    }
}

extension View {
    /// `.animation(_:value:)` that hard-cuts to instant when Reduce Motion
    /// is on or the Settings animations toggle is off (DESIGN.md §10.2).
    func feedbackAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(FeedbackAnimationModifier(animation: animation, value: value))
    }
}
