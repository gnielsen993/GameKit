//
//  RoundedType.swift
//  gamekit
//
//  GameDrawer-local rounded type (D-06, D-07): rounded for titles, pad keys
//  and primary buttons only, regular everywhere else. DesignKit's tokens are
//  untouched because HabitTracker and FitnessTracker consume them too.
//
//  Spike A1 (19.1-SPIKES.md) failed `.fontDesign(.rounded)`: it overrides
//  explicit designs, which turns the `monoNumber` timer proportional. So
//  rounded type is an explicit-design Font applied at the label, never a
//  modifier on a container. It still scales with Dynamic Type.
//

import SwiftUI

enum RoundedType {
    static func font(_ style: Font.TextStyle, weight: Font.Weight) -> Font {
        Font.system(style, design: .rounded, weight: weight)
    }
}
