//
//  ArcadeLoopDriver.swift
//  gamekit
//
//  Shared real-time loop substrate for endless arcade games (Stack, Snake).
//  Phase 15 invariants (per CONTEXT D-01..D-05):
//    - drives the frame loop via TimelineView(.animation) — declarative pause,
//      ProMotion-adaptive, no CADisplayLink (ARCADE-01)
//    - clamps raw dt to min(rawDt, 0.1) — sole spiral-of-death guard for the
//      entire arcade subsystem; no VM or engine adds a second clamp
//      (ARCADE-02 / T-15-01 / SC1b)
//    - lastDate resets to nil on isRunning → false — no stale anchor on
//      resume; first tick after resume delivers dt=0 (PITFALL-P2)
//    - fixed-timestep accumulator lives in the per-game VM, NOT here
//      (CONTEXT Claude's Discretion)
//
//  Adoption (call-site shape for Plans 02+ and Phases 16/17):
//    someGameView
//        .arcadeLoop(isRunning: vm.state == .running) { dt in
//            vm.tick(dt: dt)
//        }
//
//  Reference: developer.apple.com/documentation/swiftui/timelineview
//

import SwiftUI

struct ArcadeLoopDriver: ViewModifier {
    let isRunning: Bool
    let onTick: (_ dt: Double) -> Void
    @State private var lastDate: Date? = nil

    func body(content: Content) -> some View {
        content
            .background {
                if isRunning {
                    TimelineView(.animation) { context in
                        Color.clear
                            .onChange(of: context.date) { _, newDate in
                                let rawDt = lastDate.map { newDate.timeIntervalSince($0) } ?? 0
                                lastDate = newDate
                                onTick(min(rawDt, 0.1))
                            }
                    }
                }
            }
            .onChange(of: isRunning) { _, running in
                if !running { lastDate = nil }
            }
    }
}

extension View {
    func arcadeLoop(isRunning: Bool, onTick: @escaping (_ dt: Double) -> Void) -> some View {
        modifier(ArcadeLoopDriver(isRunning: isRunning, onTick: onTick))
    }
}
