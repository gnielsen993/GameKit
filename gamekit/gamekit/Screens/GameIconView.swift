//
//  GameIconView.swift
//  gamekit
//
//  Canvas-based per-game glyphs. Translates v8 SVG shapes from
//  assets/v8-icons.jsx to GraphicsContext draws so icons scale to any
//  size with no image assets. All SVG coordinates are in a 40×40
//  viewBox; `s = canvasSize.width / 40` is the scale factor throughout.
//
//  `GameKind.accentColor` lives in Core/GameKind+AccentColor.swift.
//

import SwiftUI

struct GameIconView: View {
    let kind: GameKind
    var size: CGFloat = 40
    var color: Color = .white

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width / 40
            let sw = max(1.8, sz.width * 0.075)
            switch kind {
            case .minesweeper: drawMinesweeper(&ctx, s: s, sw: sw, color: color)
            case .merge:       drawMerge(&ctx, s: s, color: color)
            case .nonogram:    drawNonogram(&ctx, s: s, color: color)
            case .sudoku:      drawSudoku(&ctx, s: s, sw: sw, color: color)
            case .klondike:    drawSolitaire(&ctx, s: s, color: color)
            case .freeCell:    drawFreeCell(&ctx, s: s, sw: sw, color: color)
            case .fiveLetter:  drawFiveLetter(&ctx, s: s, color: color)
            case .wordGrid:    drawWordGrid(&ctx, s: s, color: color)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Drawing (private free functions, same-file access)

private func drawMinesweeper(_ ctx: inout GraphicsContext, s: CGFloat, sw: CGFloat, color: Color) {
    // Five-dot grid base at y=32
    for i in 0..<5 {
        let r = CGRect(x: CGFloat(6 + 6 * i) * s, y: 32 * s, width: 4 * s, height: 4 * s)
        ctx.fill(Path(roundedRect: r, cornerRadius: s * 0.8), with: .color(color.opacity(0.45)))
    }
    // Vertical pole
    var pole = Path()
    pole.move(to: CGPoint(x: 14 * s, y: 8 * s))
    pole.addLine(to: CGPoint(x: 14 * s, y: 32 * s))
    ctx.stroke(pole, with: .color(color), style: StrokeStyle(lineWidth: sw, lineCap: .round))
    // Triangular flag
    var flag = Path()
    flag.move(to: CGPoint(x: 14 * s, y: 8 * s))
    flag.addLine(to: CGPoint(x: 28 * s, y: 12 * s))
    flag.addLine(to: CGPoint(x: 14 * s, y: 16 * s))
    flag.closeSubpath()
    ctx.fill(flag, with: .color(color))
}

private func drawMerge(_ ctx: inout GraphicsContext, s: CGFloat, color: Color) {
    let back = CGRect(x: 6 * s, y: 6 * s, width: 18 * s, height: 18 * s)
    ctx.fill(Path(roundedRect: back, cornerRadius: s * 3.5), with: .color(color.opacity(0.42)))
    let front = CGRect(x: 16 * s, y: 16 * s, width: 18 * s, height: 18 * s)
    ctx.fill(Path(roundedRect: front, cornerRadius: s * 3.5), with: .color(color))
}

private func drawNonogram(_ ctx: inout GraphicsContext, s: CGFloat, color: Color) {
    let heart: [[Int]] = [
        [0, 1, 0, 1, 0],
        [1, 1, 1, 1, 1],
        [1, 1, 1, 1, 1],
        [0, 1, 1, 1, 0],
        [0, 0, 1, 0, 0],
    ]
    let cell: CGFloat = 5.6, gap: CGFloat = 0.6, ox: CGFloat = 6, oy: CGFloat = 7
    for row in 0..<5 {
        for col in 0..<5 {
            let x = (ox + CGFloat(col) * (cell + gap)) * s
            let y = (oy + CGFloat(row) * (cell + gap)) * s
            let r = CGRect(x: x, y: y, width: cell * s, height: cell * s)
            ctx.fill(Path(roundedRect: r, cornerRadius: s * 0.8),
                     with: .color(color.opacity(heart[row][col] == 1 ? 1.0 : 0.18)))
        }
    }
}

private func drawSudoku(_ ctx: inout GraphicsContext, s: CGFloat, sw: CGFloat, color: Color) {
    let box = CGRect(x: 4 * s, y: 4 * s, width: 32 * s, height: 32 * s)
    ctx.stroke(Path(roundedRect: box, cornerRadius: s * 3), with: .color(color),
               style: StrokeStyle(lineWidth: sw))
    let thin = StrokeStyle(lineWidth: sw * 0.5)
    let dim = color.opacity(0.55)
    for x: CGFloat in [14.7, 25.3] {
        var p = Path()
        p.move(to: CGPoint(x: x * s, y: 4 * s))
        p.addLine(to: CGPoint(x: x * s, y: 36 * s))
        ctx.stroke(p, with: .color(dim), style: thin)
    }
    for y: CGFloat in [14.7, 25.3] {
        var p = Path()
        p.move(to: CGPoint(x: 4 * s, y: y * s))
        p.addLine(to: CGPoint(x: 36 * s, y: y * s))
        ctx.stroke(p, with: .color(dim), style: thin)
    }
    ctx.draw(
        Text("9")
            .font(.system(size: 11 * s, weight: .black, design: .rounded))
            .foregroundStyle(color),
        at: CGPoint(x: 20 * s, y: 20 * s)
    )
}

private func drawSolitaire(_ ctx: inout GraphicsContext, s: CGFloat, color: Color) {
    // Three fanned cards, each rotated around pivot (20, 22).
    let px = 20 * s, py = 22 * s
    let cards: [(angle: CGFloat, x: CGFloat, y: CGFloat, op: CGFloat, pip: Bool)] = [
        (-14 * .pi / 180, 9,  11, 0.40, false),
        (  4 * .pi / 180, 12,  9, 0.65, false),
        ( 18 * .pi / 180, 14,  8, 1.00, true),
    ]
    for card in cards {
        ctx.drawLayer { c in
            c.transform = CGAffineTransform.identity
                .translatedBy(x: -px, y: -py)
                .rotated(by: card.angle)
                .translatedBy(x: px, y: py)
            let rect = CGRect(x: card.x * s, y: card.y * s, width: 14 * s, height: 20 * s)
            c.fill(Path(roundedRect: rect, cornerRadius: s * 2), with: .color(color.opacity(card.op)))
            if card.pip {
                // Heart pip — SVG bezier translated to absolute coordinates.
                var h = Path()
                h.move(to:       CGPoint(x: 17.5 * s, y: 12.5 * s))
                h.addCurve(to:   CGPoint(x: 14.8 * s, y: 12.7 * s),
                           control1: CGPoint(x: 16.8 * s, y: 11.4 * s),
                           control2: CGPoint(x: 15.2 * s, y: 11.4 * s))
                h.addCurve(to:   CGPoint(x: 17.0 * s, y: 15.8 * s),
                           control1: CGPoint(x: 14.5 * s, y: 13.7 * s),
                           control2: CGPoint(x: 15.6 * s, y: 14.9 * s))
                h.addCurve(to:   CGPoint(x: 19.2 * s, y: 12.7 * s),
                           control1: CGPoint(x: 18.4 * s, y: 14.9 * s),
                           control2: CGPoint(x: 19.5 * s, y: 13.7 * s))
                h.addCurve(to:   CGPoint(x: 17.5 * s, y: 12.5 * s),
                           control1: CGPoint(x: 18.8 * s, y: 11.4 * s),
                           control2: CGPoint(x: 17.2 * s, y: 11.4 * s))
                h.closeSubpath()
                c.fill(h, with: .color(.white.opacity(0.92)))
            }
        }
    }
}

private func drawFreeCell(_ ctx: inout GraphicsContext, s: CGFloat, sw: CGFloat, color: Color) {
    // Four free-cell outlines (second filled = occupied).
    let cells: [(x: CGFloat, w: CGFloat)] = [(4, 7), (13, 7), (22, 7), (31, 5)]
    for cell in cells {
        let r = CGRect(x: cell.x * s, y: 5 * s, width: cell.w * s, height: 9 * s)
        ctx.stroke(Path(roundedRect: r, cornerRadius: s * 1.4), with: .color(color),
                   style: StrokeStyle(lineWidth: sw * 0.85))
    }
    ctx.fill(Path(roundedRect: CGRect(x: 13 * s, y: 5 * s, width: 7 * s, height: 9 * s),
                  cornerRadius: s * 1.4), with: .color(color))
    // Fan of three cards around pivot (20, 28).
    // SVG: <g transform="translate(20 28)"> with cards at x=[-13,-5,3], y=-6, each 10×14.
    let px: CGFloat = 20 * s, py: CGFloat = 28 * s
    let fanCards: [(angle: CGFloat, x: CGFloat, op: CGFloat)] = [
        (-12 * .pi / 180, 7,  0.40),
        (  0,             15, 0.70),
        ( 12 * .pi / 180, 23, 1.00),
    ]
    for card in fanCards {
        ctx.drawLayer { c in
            c.transform = CGAffineTransform.identity
                .translatedBy(x: -px, y: -py)
                .rotated(by: card.angle)
                .translatedBy(x: px, y: py)
            let rect = CGRect(x: card.x * s, y: 22 * s, width: 10 * s, height: 14 * s)
            c.fill(Path(roundedRect: rect, cornerRadius: s * 1.6), with: .color(color.opacity(card.op)))
        }
    }
}

private func drawFiveLetter(_ ctx: inout GraphicsContext, s: CGFloat, color: Color) {
    let letters = Array("FIVE")
    for row in 0..<2 {
        for col in 0..<3 {
            let r = CGRect(
                x: CGFloat(5 + col * 10) * s,
                y: CGFloat(8 + row * 11) * s,
                width: 8 * s,
                height: 9 * s
            )
            ctx.fill(Path(roundedRect: r, cornerRadius: s * 1.4), with: .color(color.opacity(row == 0 ? 1 : 0.42)))
        }
    }
    for index in letters.indices {
        let x = CGFloat(9 + index * 7) * s
        ctx.draw(
            Text(String(letters[index]))
                .font(.system(size: 6 * s, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.95)),
            at: CGPoint(x: x, y: 13 * s)
        )
    }
}

private func drawWordGrid(_ ctx: inout GraphicsContext, s: CGFloat, color: Color) {
    for row in 0..<4 {
        for col in 0..<4 {
            let r = CGRect(
                x: CGFloat(5 + col * 8) * s,
                y: CGFloat(5 + row * 8) * s,
                width: 6 * s,
                height: 6 * s
            )
            ctx.fill(Path(roundedRect: r, cornerRadius: s), with: .color(color.opacity((row + col).isMultiple(of: 2) ? 1 : 0.4)))
        }
    }
    var path = Path()
    path.move(to: CGPoint(x: 8 * s, y: 8 * s))
    path.addLine(to: CGPoint(x: 16 * s, y: 16 * s))
    path.addLine(to: CGPoint(x: 24 * s, y: 16 * s))
    path.addLine(to: CGPoint(x: 32 * s, y: 24 * s))
    ctx.stroke(path, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: max(1.6, 2.4 * s), lineCap: .round, lineJoin: .round))
}
