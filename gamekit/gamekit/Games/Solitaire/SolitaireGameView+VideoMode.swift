import SwiftUI
import DesignKit

// Video Mode layout for Solitaire (Klondike).
//
// Solitaire has no lives, no mode-pill — compact row is:
//   Back · Undo · [spacer] · deal label · [spacer] · Menu
//
// Large zones: navbar hidden; compact control row at the edge furthest from PiP.
// Small zones: compact info header (timer + deal label); toolbar items repositioned.
//
// Drag coordinate discipline: solBoardBlock attaches no outer coordinate space
// (the "solitaire-tableau" named space lives on the HStack inside tableauArea),
// so drag math is identical to normalLayout — no headerHeight offset needed.

extension SolitaireGameView {

    // MARK: - Top-level Video Mode branch

    @ViewBuilder
    var videoModeLayout: some View {
        if videoModeStore.location == .largeTop {
            solLargeZoneLayout
                .toolbar(.hidden, for: .navigationBar)
        } else if videoModeStore.location.isTopSmall {
            solTopSmallZoneLayout
                .navigationBarBackButtonHidden(true)
                .toolbar { solSmallZoneToolbarContent }
        } else {
            // largeBottom + all bottom small zones — board layout unchanged
            normalLayout
                .toolbar { toolbarContent }
        }
    }

    // MARK: - Large-zone layout

    // MARK: - Large-zone layout (largeTop only — bottom zones use normalLayout)

    @ViewBuilder
    var solLargeZoneLayout: some View {
        GeometryReader { geo in
            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    solLargeZoneControlRow
                        .padding(.top, theme.spacing.s)
                    solBoardBlock(geo: geo).layoutPriority(1)
                }
                .padding(.bottom, theme.spacing.l)
            }
            .overlay(alignment: .center) {
                if vm.gameState == .won { winBanner }
                else if vm.gameState == .stuck { stuckBanner }
            }
        }
    }

    // MARK: - Top-small-zone layout

    @ViewBuilder
    var solTopSmallZoneLayout: some View {
        GeometryReader { geo in
            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    solSmallZoneInfoHeader(
                        chipsTrailing: videoModeStore.location == .smallTopLeft
                    )
                    solBoardBlock(geo: geo).layoutPriority(1)
                }
                .padding(.bottom, theme.spacing.l)
            }
            .overlay(alignment: .center) {
                if vm.gameState == .won { winBanner }
                else if vm.gameState == .stuck { stuckBanner }
            }
        }
    }

    // MARK: - Bottom-small-zone layout

    // MARK: - Shared shelf + board block
    //
    // Mirrors normalLayout's boardArea: shelf with background, tableau with
    // boardColor, drag overlay floating over both in a ZStack.

    @ViewBuilder
    func solBoardBlock(geo: GeometryProxy) -> some View {
        let pad:    CGFloat = 8
        let gap:    CGFloat = 6
        let cardW   = (geo.size.width - 2 * pad - 6 * gap) / 7
        let cardH   = cardW * 1.4
        let topRowH = theme.spacing.s * 2 + cardH

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                SolitaireTopRowView(
                    foundations: vm.board.foundations,
                    stock:       vm.board.stock,
                    waste:       vm.board.waste,
                    theme:       theme,
                    isClassic:   isClassic,
                    cardWidth:   cardW,
                    selectedIsWaste: vm.selection == .waste,
                    draggingFoundationSuit: dragIsFromFoundation ? dragFoundationSuit : nil,
                    onStockTap:       { vm.drawFromStock() },
                    onWasteTap:       { vm.tapWaste() },
                    onWasteDoubleTap: { vm.sendWasteToFoundation() },
                    onFoundationTap:  { vm.tapFoundation(suit: $0) },
                    onWasteDragChanged: { translation in
                        if !isDragging {
                            guard let topCard = vm.board.topWaste else { return }
                            dragCards       = [topCard]
                            dragIsFromWaste = true
                            isDragging      = true
                            vm.clearSelection()
                            pickUpTick     += 1
                        }
                        dragOffset    = translation
                        let wasteCX = geo.size.width - pad - 1.5 * cardW - gap
                        dropTargetCol = colAtBoardX(wasteCX + translation.width,
                                                    cardW: cardW, gap: gap, pad: pad)
                    },
                    onWasteDragEnded: { translation in
                        finalizeWasteDrop(translation: translation, cardW: cardW)
                    },
                    onFoundationDragChanged: { suit, translation in
                        if !isDragging {
                            guard let rank = vm.board.foundations[suit.foundationIndex] else { return }
                            dragCards            = [PlayingCard(rank: rank, suit: suit)]
                            dragIsFromFoundation = true
                            dragFoundationSuit   = suit
                            isDragging           = true
                            vm.clearSelection()
                            pickUpTick          += 1
                        }
                        dragOffset = translation
                        let fCX = pad + CGFloat(suit.foundationIndex) * (cardW + gap) + cardW / 2
                        dropTargetCol = colAtBoardX(fCX + translation.width,
                                                    cardW: cardW, gap: gap, pad: pad)
                    },
                    onFoundationDragEnded: { suit, translation in
                        finalizeFoundationDrop(suit: suit, translation: translation, cardW: cardW)
                    }
                )
                .padding(.horizontal, pad)
                .padding(.vertical, theme.spacing.s)
                .frame(maxWidth: .infinity)
                .background(theme.colors.background)

                tableauArea(cardW: cardW, gap: gap, pad: pad)
                    .padding(.top, theme.spacing.s)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(boardColor)
            }

            if isDragging {
                dragOverlay(cardW: cardW, gap: gap, pad: pad,
                            topRowH: topRowH, geoWidth: geo.size.width)
            }
        }
    }

    // MARK: - Compact control row (large zones)
    // Back · [spacer] · Timer · deal label · Undo · [spacer] · Menu

    @ViewBuilder
    var solLargeZoneControlRow: some View {
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

            Text("Deal #\(vm.dealNumber) · \(vm.difficulty.label)")
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
                ForEach(SolitaireDifficulty.allCases, id: \.self) { d in
                    Button("New \(d.label) Game") { vm.startNewGame(difficulty: d) }
                }
                Divider()
                Button("Restart This Deal") { vm.restartCurrentDeal() }
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
    func solSmallZoneInfoHeader(chipsTrailing: Bool) -> some View {
        HStack(spacing: theme.spacing.s) {
            if chipsTrailing { Spacer(minLength: 0) }
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: vm.timerAnchor,
                pausedElapsed: vm.pausedElapsed,
                compact: true
            )
            Text("Deal #\(vm.dealNumber) · \(vm.difficulty.label)")
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
    var solSmallZoneToolbarContent: some ToolbarContent {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        let backPlacement = Self.solToolbarPlacement(for: anchors.back)
        // Back + Undo grouped at the same edge, away from the PiP corner
        ToolbarItem(placement: backPlacement) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(theme.colors.textPrimary)
        }
        ToolbarItem(placement: backPlacement) {
            Button { vm.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(vm.canUndo ? theme.colors.accentPrimary : theme.colors.textSecondary)
            .disabled(!vm.canUndo)
        }
        ToolbarItem(placement: Self.solToolbarPlacement(for: anchors.settings)) {
            Menu {
                ForEach(SolitaireDifficulty.allCases, id: \.self) { d in
                    Button("New \(d.label) Game") { vm.startNewGame(difficulty: d) }
                }
                Divider()
                Button("Restart This Deal") { vm.restartCurrentDeal() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(theme.colors.accentPrimary)
            }
        }
    }

    static func solToolbarPlacement(for anchor: SlotAnchor) -> ToolbarItemPlacement {
        switch anchor {
        case .topLeading:            return .topBarLeading
        case .topTrailing:           return .topBarTrailing
        case .bottomLeading,
             .bottomTrailing:        return .bottomBar
        case .inCompactRow, .hidden: return .topBarLeading
        }
    }
}
