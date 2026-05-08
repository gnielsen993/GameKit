//
//  ConfettiView.swift
//  gamekit
//
//  Pure-SwiftUI confetti emitter for Minesweeper win choreography.
//  Self-contained — no DesignKit token reads beyond the theme passed in
//  (each particle picks one of accent/highlight/success/textPrimary/danger
//  so colors track the active preset).
//
//  Driven by `TimelineView(.animation)` so SwiftUI hands us a continuous
//  date stream; we derive each particle's offset from elapsed seconds
//  using simple ballistic math (constant horizontal drift × random
//  per-particle rate, gravity-accelerated vertical fall).
//

import SwiftUI
import DesignKit

struct ConfettiView: View {
    let theme: Theme

    /// Particle count tuned for visible-but-not-laggy on iPhone SE-class.
    /// 60 particles × per-frame transform = well under the SwiftUI budget.
    private static let particleCount = 60

    /// One-shot per appearance — picked at view-construct time so each
    /// .onAppear / new instance gets a fresh random burst.
    private let particles: [Particle]

    init(theme: Theme) {
        self.theme = theme
        self.particles = (0..<Self.particleCount).map { _ in Particle.random(theme: theme) }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let t = elapsed - particle.startOffset
                    guard t > 0 else { continue }

                    // Ballistic position. x = drift × t (clamped). y = init +
                    // fall × t² (gravity). Wrap horizontally so particles
                    // that drift off-screen reappear from the opposite side.
                    let x = particle.startX * size.width
                        + CGFloat(particle.driftX * t)
                    let wrappedX = (x.truncatingRemainder(dividingBy: size.width) + size.width)
                        .truncatingRemainder(dividingBy: size.width)
                    let y = -20 + CGFloat(particle.driftY * t + 0.5 * 320 * t * t)

                    // Spin via rotation transform.
                    let rotation = Angle.degrees(particle.spinRate * t * 360)

                    var ctx = context
                    ctx.translateBy(x: wrappedX, y: y)
                    ctx.rotate(by: rotation)

                    let rect = CGRect(
                        x: -particle.size / 2,
                        y: -particle.size / 2,
                        width: particle.size,
                        height: particle.size * 0.45
                    )
                    ctx.fill(Path(rect), with: .color(particle.color))
                }
            }
        }
    }

    private struct Particle {
        let startX: CGFloat       // 0...1, fraction of screen width
        let startOffset: Double   // seconds before this particle starts (stagger)
        let driftX: Double        // px/s horizontal drift
        let driftY: Double        // px/s initial vertical (gravity adds quadratically)
        let spinRate: Double      // turns/s
        let size: CGFloat
        let color: Color

        static func random(theme: Theme) -> Particle {
            let palette: [Color] = [
                theme.colors.accentPrimary,
                theme.colors.highlight,
                theme.colors.success,
                theme.colors.warning,
                theme.colors.danger,
                theme.colors.accentSecondary
            ]
            return Particle(
                startX: CGFloat.random(in: 0...1),
                startOffset: Double.random(in: 0...0.4),
                driftX: Double.random(in: -60...60),
                driftY: Double.random(in: 60...160),
                spinRate: Double.random(in: -1.5...1.5),
                size: CGFloat.random(in: 8...14),
                color: palette.randomElement() ?? theme.colors.accentPrimary
            )
        }
    }
}
