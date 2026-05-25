import SwiftUI
import DesignKit

// MARK: - PlayingCardView

struct PlayingCardView: View {
    let rank: CardRank
    let suit: CardSuit
    let theme: Theme
    let isClassic: Bool
    var width: CGFloat = 70
    var faceUp: Bool = true

    private var height: CGFloat     { width * 1.4 }
    private var radius: CGFloat     { width * 0.10 }
    private var suitColor: Color    { suit.isRed ? theme.colors.danger : theme.colors.textPrimary }

    // Below 44pt (video mode small zones) pack tighter so the top strip
    // stays readable without crowding the center suit.
    private var isCondensed: Bool   { width < 44 }
    private var rankSize:   CGFloat { width * (isCondensed ? 0.28 : 0.31) }
    private var suitCorner: CGFloat { width * (isCondensed ? 0.21 : 0.24) }
    private var hPad:       CGFloat { width * (isCondensed ? 0.08 : 0.09) }
    private var topPad:     CGFloat { width * (isCondensed ? 0.05 : 0.06) }
    private var suitCenter: CGFloat { width * 0.50 }

    init(_ card: PlayingCard, theme: Theme, isClassic: Bool, width: CGFloat = 70) {
        self.rank = card.rank; self.suit = card.suit
        self.theme = theme; self.isClassic = isClassic
        self.width = width; self.faceUp = card.isFaceUp
    }

    init(rank: CardRank, suit: CardSuit, theme: Theme, isClassic: Bool, width: CGFloat = 70) {
        self.rank = rank; self.suit = suit
        self.theme = theme; self.isClassic = isClassic
        self.width = width
    }

    var body: some View {
        ZStack {
            if faceUp {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.colors.surface)
                    .shadow(color: .black.opacity(0.13), radius: 4, x: 0, y: 2)

                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(suitColor.opacity(0.15), lineWidth: 1)

                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(rank.display)
                            .font(.system(size: rankSize, weight: .heavy, design: .rounded))
                            .foregroundStyle(suitColor)
                        Spacer(minLength: 0)
                        Image(systemName: suit.sfSymbol)
                            .font(.system(size: suitCorner, weight: .bold))
                            .foregroundStyle(suitColor)
                    }
                    .padding(.horizontal, hPad)
                    .padding(.top, topPad)

                    Spacer(minLength: 0)
                    centerContent
                    Spacer(minLength: 0)
                }
            } else {
                CardBackView(theme: theme, isClassic: isClassic, width: width)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    @ViewBuilder private var centerContent: some View {
        Image(systemName: suit.sfSymbol)
            .font(.system(size: rank == .ace ? width * 0.54 : suitCenter))
            .foregroundStyle(suitColor)
    }
}

// MARK: - CardBackView

struct CardBackView: View {
    let theme: Theme
    let isClassic: Bool
    var width: CGFloat = 70

    private var height: CGFloat { width * 1.4 }
    private var radius: CGFloat { width * 0.10 }
    private var backColor: Color {
        theme.colors.accentPrimary
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(backColor)
                .shadow(color: .black.opacity(0.13), radius: 4, x: 0, y: 2)
            Canvas { ctx, size in
                let step = width * 0.22
                var row: CGFloat = 0
                while row * step < size.height + step {
                    var col: CGFloat = 0
                    while col * step < size.width + step {
                        let x = col * step + (row.truncatingRemainder(dividingBy: 2) == 0 ? 0 : step * 0.5)
                        let y = row * step
                        let r = step * 0.13
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r*2, height: r*2)),
                                 with: .color(.white.opacity(0.25)))
                        col += 1
                    }
                    row += 1
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            RoundedRectangle(cornerRadius: radius - 3, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
                .padding(theme.spacing.xs)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - CardDesignShowcaseView

struct CardDesignShowcaseView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var theme: Theme   { themeManager.theme(using: colorScheme) }
    private var isClassic: Bool { themeManager.preset == .classicMuted }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    staticFacesSection
                    InteractiveTableauView(theme: theme, isClassic: isClassic)
                }
                .padding(theme.spacing.m)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Card Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.colors.accentPrimary)
                }
            }
        }
    }

    private var staticFacesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            label("Faces — Hearts & Spades")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.xs) {
                    ForEach(CardRank.allCases, id: \.rawValue) { rank in
                        PlayingCardView(rank: rank, suit: .hearts, theme: theme, isClassic: isClassic, width: 54)
                    }
                }
                .padding(.vertical, 4)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.xs) {
                    ForEach(CardRank.allCases, id: \.rawValue) { rank in
                        PlayingCardView(rank: rank, suit: .spades, theme: theme, isClassic: isClassic, width: 54)
                    }
                }
                .padding(.vertical, 4)
            }
            HStack(spacing: theme.spacing.s) {
                ForEach(CardSuit.allCases, id: \.sfSymbol) { suit in
                    PlayingCardView(rank: .queen, suit: suit, theme: theme, isClassic: isClassic, width: 72)
                }
            }
            HStack(spacing: theme.spacing.m) {
                CardBackView(theme: theme, isClassic: isClassic, width: 72)
                CardBackView(theme: theme, isClassic: isClassic, width: 56)
                CardBackView(theme: theme, isClassic: isClassic, width: 44)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textSecondary)
            .textCase(.uppercase)
    }
}
