import SwiftUI
import DesignKit

// Video Mode layout for FreeCell. Shape mirrors SudokuGameView+VideoMode.
//
// FreeCell has no numpad, no lives, no mode-pill — compact row is:
//   Back · Undo · [spacer] · deal label · [spacer] · Menu
//
// Large zones: navbar hidden; compact control row at the edge furthest from the
// PiP; timer chip overlays the top-trailing corner of the shelf+board block.
//
// Small zones: compact info header (timer + deal label) packed to the corner
// opposite the PiP; board fills the remaining space. Toolbar items reposition
// via VideoModeSlotRouter.
//
// Drag coordinate discipline: `fcVideoModeBoardBlock` attaches the "freecell"
// named coordinate space to the shelf+board block directly, so headerHeight
// must be 0 — the shelf is at y=0 within that space.

extension FreeCellGameView {

    // MARK: - Top-level Video Mode branch

    @ViewBuilder
    var videoModeLayout: some View {
        if videoModeStore.location.isLarge {
            largeZoneLayout
                .toolbar(.hidden, for: .navigationBar)
        } else if videoModeStore.location.isTopSmall {
            topSmallZoneLayout
                .toolbar { fcSmallZoneToolbarContent }
        } else {
            bottomSmallZoneLayout
                .toolbar { fcSmallZoneToolbarContent }
        }
    }

    // MARK: - Large-zone layout

    @ViewBuilder
    var largeZoneLayout: some View {
        GeometryReader { geo in
            let (cardW, cardH, shelfH, boardPad, colGap) = fcCardLayout(geo)

            ZStack {
                theme.colors.background.ignoresSafeArea()

                if videoModeStore.location == .largeTop {
                    // PiP at top → board first, control row at bottom
                    VStack(spacing: 0) {
                        fcVideoModeBoardBlock(
                            cardW: cardW, cardH: cardH, shelfH: shelfH,
                            boardPad: boardPad, colGap: colGap, geo: geo
                        )
                        .layoutPriority(1)

                        fcLargeZoneControlRow
                            .padding(.bottom, theme.spacing.l)
                    }
                } else {
                    // .largeBottom — PiP at bottom → control row at top
                    VStack(spacing: 0) {
                        fcLargeZoneControlRow
                            .padding(.top, theme.spacing.s)

                        fcVideoModeBoardBlock(
                            cardW: cardW, cardH: cardH, shelfH: shelfH,
                            boardPad: boardPad, colGap: colGap, geo: geo
                        )
                        .layoutPriority(1)
                    }
                    .padding(.bottom, theme.spacing.l)
                }

                fcCascadeOverlay
            }
            .overlay(alignment: .bottom) { winLossBanner }
        }
    }

    // MARK: - Top-small-zone layout

    @ViewBuilder
    var topSmallZoneLayout: some View {
        GeometryReader { geo in
            let (cardW, cardH, shelfH, boardPad, colGap) = fcCardLayout(geo)

            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // .smallTopLeft → PiP left → chips right (trailing)
                    // .smallTopRight → PiP right → chips left (leading)
                    fcSmallZoneInfoHeader(
                        chipsTrailing: videoModeStore.location == .smallTopLeft
                    )

                    fcVideoModeBoardBlock(
                        cardW: cardW, cardH: cardH, shelfH: shelfH,
                        boardPad: boardPad, colGap: colGap, geo: geo
                    )
                    .layoutPriority(1)
                }
                .padding(.bottom, theme.spacing.l)

                fcCascadeOverlay
            }
            .overlay(alignment: .bottom) { winLossBanner }
        }
    }

    // MARK: - Bottom-small-zone layout

    private static let fcPipFootprint: CGFloat = 200

    @ViewBuilder
    var bottomSmallZoneLayout: some View {
        GeometryReader { geo in
            let (cardW, cardH, shelfH, boardPad, colGap) = fcCardLayout(geo)

            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    fcVideoModeBoardBlock(
                        cardW: cardW, cardH: cardH, shelfH: shelfH,
                        boardPad: boardPad, colGap: colGap, geo: geo
                    )
                    .layoutPriority(1)

                    // .smallBottomLeft → PiP left → chips right (trailing)
                    // .smallBottomRight → PiP right → chips left (leading)
                    fcSmallZoneInfoHeader(
                        chipsTrailing: videoModeStore.location == .smallBottomLeft
                    )
                }
                .padding(.bottom, Self.fcPipFootprint)

                fcCascadeOverlay
            }
            .overlay(alignment: .bottom) { winLossBanner }
        }
    }

    // MARK: - Shared shelf + board block
    //
    // Attaches the "freecell" coordinate space here (not on an outer container)
    // so headerHeight is always 0 in video mode — the shelf is at y=0.

    @ViewBuilder
    func fcVideoModeBoardBlock(
        cardW: CGFloat, cardH: CGFloat, shelfH: CGFloat,
        boardPad: CGFloat, colGap: CGFloat, geo: GeometryProxy
    ) -> some View {
        VStack(spacing: 0) {
            FreeCellTopRowView(
                vm: vm, theme: theme, isClassic: isClassic,
                cardWidth: cardW, colGap: colGap,
                dragSource: dragState?.source
            )
            .padding(.horizontal, boardPad)
            .padding(.vertical, 10)
            .background(theme.colors.background)

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: colGap) {
                    ForEach(0..<8, id: \.self) { col in
                        FreeCellColumnView(
                            colIdx:    col,
                            cards:     vm.board.columns[col],
                            vm:        vm,
                            theme:     theme,
                            isClassic: isClassic,
                            cardWidth: cardW,
                            dragSource: dragState?.source,
                            dragTarget: dragTarget
                        )
                    }
                }
                .padding(.horizontal, boardPad)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDisabled(true)
            .layoutPriority(1)
        }
        .background(boardColor)
        .coordinateSpace(.named("freecell"))
        .onAppear { headerHeight = 0 }
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .named("freecell"))
                .onChanged { val in
                    onDragChanged(val,
                                  cardW: cardW, cardH: cardH, shelfH: shelfH,
                                  boardPad: boardPad, colGap: colGap,
                                  geoW: geo.size.width)
                }
                .onEnded { val in
                    onDragEnded(val,
                                cardW: cardW, shelfH: shelfH,
                                boardPad: boardPad, colGap: colGap,
                                geoW: geo.size.width)
                }
        )
        .overlay { dragOverlay(cardW: cardW) }
    }

    // MARK: - Compact control row (large zone)
    // Back · [spacer] · Timer · Deal label · Undo · [spacer] · Menu

    @ViewBuilder
    var fcLargeZoneControlRow: some View {
        HStack(spacing: theme.spacing.s) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                    .background(theme.colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.button,
                                               style: .continuous))
            }
            .accessibilityLabel(Text("Back"))

            Spacer(minLength: 0)

            VideoModeTimerChip(
                theme: theme,
                timerAnchor: vm.timerAnchor,
                pausedElapsed: vm.pausedElapsed,
                compact: true
            )
            .allowsHitTesting(false)

            Text(fcDealLabel)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)

            Button { vm.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        vm.canUndo ? theme.colors.accentPrimary : theme.colors.textSecondary
                    )
                    .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                    .background(theme.colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.button,
                                               style: .continuous))
            }
            .disabled(!vm.canUndo)
            .accessibilityLabel(Text("Undo"))

            Spacer(minLength: 0)

            Menu {
                Button("New Random Game") {
                    vm.startNewGame(mode: .random(vm.difficulty ?? .easy))
                }
                Button("Enter Deal #") { showingDealEntry = true }
                Divider()
                Button("Restart This Deal") { vm.reset() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.accentPrimary)
                    .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                    .background(theme.colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.button,
                                               style: .continuous))
            }
        }
        .padding(.horizontal, theme.spacing.m)
        .frame(height: theme.spacing.xl)
    }

    // MARK: - Compact info header (small zones)

    @ViewBuilder
    func fcSmallZoneInfoHeader(chipsTrailing: Bool) -> some View {
        HStack(spacing: theme.spacing.s) {
            if chipsTrailing { Spacer(minLength: 0) }
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: vm.timerAnchor,
                pausedElapsed: vm.pausedElapsed,
                compact: true
            )
            Text(fcDealLabel)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
            if !chipsTrailing { Spacer(minLength: 0) }
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }

    // MARK: - Small-zone toolbar

    @ToolbarContentBuilder
    var fcSmallZoneToolbarContent: some ToolbarContent {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        // Back — placed at the back anchor (moves away from PiP)
        ToolbarItem(placement: Self.fcToolbarPlacement(for: anchors.back)) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(theme.colors.textPrimary)
        }
        // Undo — also at the back anchor alongside back, mirrors other games' restart button
        ToolbarItem(placement: Self.fcToolbarPlacement(for: anchors.back)) {
            Button { vm.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(vm.canUndo ? theme.colors.accentPrimary : theme.colors.textSecondary)
            .disabled(!vm.canUndo)
        }
        // Settings menu — no undo here; it has its own button above
        ToolbarItem(placement: Self.fcToolbarPlacement(for: anchors.settings)) {
            Menu {
                Button("New Random Game") {
                    vm.startNewGame(mode: .random(vm.difficulty ?? .easy))
                }
                Button("Enter Deal #") { showingDealEntry = true }
                Divider()
                Button("Restart This Deal") { vm.reset() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(theme.colors.accentPrimary)
            }
        }
    }

    static func fcToolbarPlacement(for anchor: SlotAnchor) -> ToolbarItemPlacement {
        switch anchor {
        case .topLeading:              return .topBarLeading
        case .topTrailing:             return .topBarTrailing
        case .bottomLeading,
             .bottomTrailing:          return .bottomBar
        case .inCompactRow, .hidden:   return .topBarLeading
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var fcCascadeOverlay: some View {
        if vm.gameState == .won {
            GeometryReader { g in
                FreeCellCascadeView(theme: theme, isClassic: isClassic, screenSize: g.size)
            }
            .ignoresSafeArea()
        }
    }

    var fcDealLabel: String {
        if let d = vm.difficulty { return "Deal #\(vm.dealNumber) · \(d.label)" }
        return "Deal #\(vm.dealNumber)"
    }

    // Returns (cardW, cardH, shelfH, boardPad, colGap) from geo.
    func fcCardLayout(_ geo: GeometryProxy) -> (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) {
        let boardPad: CGFloat = 10
        let colGap:   CGFloat = 4
        let cardW = (geo.size.width - 2 * boardPad - CGFloat(7) * colGap) / 8
        let cardH = cardW * 1.4
        let shelfH = cardH + 20
        return (cardW, cardH, shelfH, boardPad, colGap)
    }
}
