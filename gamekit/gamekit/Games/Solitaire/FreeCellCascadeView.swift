import SwiftUI
import DesignKit

// MARK: - Win cascade overlay

struct FreeCellCascadeView: View {
    let theme:      Theme
    let isClassic:  Bool
    let screenSize: CGSize

    // 16 particles: 4 suits × 4 ranks, mixed for visual variety
    private static let suits: [CardSuit] = [
        .spades, .hearts, .diamonds, .clubs,
        .clubs, .hearts, .spades, .diamonds,
        .hearts, .spades, .clubs, .diamonds,
        .diamonds, .clubs, .hearts, .spades
    ]
    private static let ranks: [CardRank] = [
        .king, .king, .king, .king,
        .queen, .queen, .queen, .queen,
        .jack, .jack, .jack, .jack,
        .ten, .ten, .ten, .ten
    ]

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                CascadeCardParticle(
                    rank:      Self.ranks[i],
                    suit:      Self.suits[i],
                    theme:     theme,
                    isClassic: isClassic,
                    cardWidth: 40,
                    delay:     Double(i) * 0.075,
                    peakOffset: peakOffset(i),
                    endOffset:  endOffset(i),
                    rotation:   Self.rotations[i]
                )
                .position(launchPoint(i))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Layout helpers

    // Deterministic angles (degrees, measured from +X axis, upward hemisphere)
    private static let angles: [Double] = [
        100, 115, 75, 130,  90, 120, 70, 145,
         95, 110, 80, 140, 105,  85, 135, 65
    ]
    private static let speeds: [CGFloat] = [
        170, 150, 195, 160,  185, 140, 205, 155,
        165, 145, 190, 175,  155, 180, 145, 200
    ]
    private static let rotations: [Double] = [
        270, -360,  180, -270,  360, -180,  270, -360,
        180, -270,  360, -180,  270, -360,  180, -270
    ]
    private static let endXFracs: [Double] = [
        -0.55,  0.05,  0.50, -0.30,  0.70, -0.75,  0.30, -0.10,
         0.80, -0.40,  0.15,  0.60, -0.65,  0.45, -0.20,  0.85
    ]
    private static let endYFacs: [Double] = [
        0.80,  0.90,  1.00,  0.75,  1.10,  0.85,  0.95,  0.70,
        1.00,  0.82,  0.92,  1.05,  0.88,  0.98,  0.78,  1.12
    ]
    private static let launchXFracs: [Double] = [
        0.00,  0.25,  0.50,  0.75,  1.00,  0.12,  0.38,  0.62,
        0.88,  0.06,  0.44,  0.69,  0.19,  0.56,  0.82,  0.31
    ]

    private func launchPoint(_ i: Int) -> CGPoint {
        let w = screenSize.width, h = screenSize.height
        let x = w * 0.68 + w * 0.28 * Self.launchXFracs[i]
        let y = h * 0.11 + CGFloat(i % 3) * 12
        return CGPoint(x: x, y: y)
    }

    private func peakOffset(_ i: Int) -> CGSize {
        let angle = Self.angles[i] * .pi / 180
        let speed = Self.speeds[i]
        return CGSize(
            width:  CGFloat(cos(angle)) * speed,
            height: -CGFloat(sin(angle)) * speed
        )
    }

    private func endOffset(_ i: Int) -> CGSize {
        let w = screenSize.width, h = screenSize.height
        return CGSize(
            width:  CGFloat(Self.endXFracs[i]) * w,
            height: CGFloat(Self.endYFacs[i]) * h
        )
    }
}

// MARK: - Single card particle

private struct CascadeCardParticle: View {
    let rank:       CardRank
    let suit:       CardSuit
    let theme:      Theme
    let isClassic:  Bool
    let cardWidth:  CGFloat
    let delay:      Double
    let peakOffset: CGSize
    let endOffset:  CGSize
    let rotation:   Double

    @State private var offset   = CGSize.zero
    @State private var rot      = 0.0
    @State private var opacity  = 1.0

    var body: some View {
        PlayingCardView(rank: rank, suit: suit, theme: theme, isClassic: isClassic, width: cardWidth)
            .rotationEffect(.degrees(rot))
            .opacity(opacity)
            .offset(offset)
            .task {
                try? await Task.sleep(for: .seconds(delay))
                // Phase 1 — launch upward
                withAnimation(.easeOut(duration: 0.50)) {
                    offset = peakOffset
                    rot    = rotation * 0.35
                }
                try? await Task.sleep(for: .seconds(0.52))
                // Phase 2 — fall and fade
                withAnimation(.easeIn(duration: 1.35)) {
                    offset  = endOffset
                    rot     = rotation
                    opacity = 0
                }
            }
    }
}
