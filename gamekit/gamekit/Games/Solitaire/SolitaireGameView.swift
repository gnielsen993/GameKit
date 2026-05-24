import SwiftUI
import SwiftData
import DesignKit

struct SolitaireGameView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.videoModeStore) var videoModeStore

    @State var vm: SolitaireViewModel
    @State var showingNewGame = false
    @State private var didInjectStats = false

    // Drag state
    @State var isDragging      = false
    @State var dragIsFromWaste = false
    @State var dragSourceCol   = 0
    @State var dragFromIdx     = 0
    @State var dragCards: [PlayingCard] = []
    @State var dragOffset      = CGSize.zero
    @State var dropTargetCol: Int? = nil

    // Haptic counter-triggers (DESIGN.md §8)
    @State var pickUpTick = 0
    @State var dropTick   = 0
    @State var rejectTick = 0

    var theme:     Theme { themeManager.theme(using: colorScheme) }
    var isClassic: Bool  { themeManager.preset == .classicMuted }

    var boardColor: Color {
        isClassic
            ? Color(hue: 0.426, saturation: 0.576, brightness: 0.416)
            : theme.colors.fillSelected.opacity(0.35)
    }

    init(initialDifficulty: SolitaireDifficulty = .easy) {
        _vm = State(initialValue: SolitaireViewModel(difficulty: initialDifficulty))
    }

    var body: some View {
        Group {
            if !videoModeStore.isEnabled {
                normalLayout
                    .toolbar { toolbarContent }
            } else {
                videoModeLayout
            }
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Solitaire")
        .alert("Resume game?", isPresented: Binding(
            get: { vm.pendingSaveState != nil },
            set: { _ in }
        )) {
            Button("Continue") {
                if let saved = vm.pendingSaveState { vm.restoreState(saved) }
            }
            Button("New Game", role: .destructive) { vm.discardSaveAndLoadNew() }
        } message: {
            if let s = vm.pendingSaveState {
                Text("You have an in-progress \(s.difficulty.label) Solitaire game.")
            }
        }
        .task {
            guard !didInjectStats else { return }
            didInjectStats = true
            vm.wire(stats: GameStats(modelContext: modelContext))
            vm.checkAndLoadOrRestoreState()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { vm.saveCurrentState(); vm.pause() }
            else if phase == .active { vm.resume() }
        }
        .confirmationDialog("New Game", isPresented: $showingNewGame) {
            ForEach(SolitaireDifficulty.allCases, id: \.self) { d in
                Button("\(d.label) — \(d.detail)") { vm.startNewGame(difficulty: d) }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pickUpTick)
        .sensoryFeedback(.success, trigger: dropTick)
        .sensoryFeedback(.error, trigger: rejectTick)
    }

    var normalLayout: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    headerBar
                        .background(theme.colors.background)
                    boardArea(geo: geo)
                        .layoutPriority(1)
                    if vm.board.canAutoComplete && vm.gameState == .playing {
                        autoCompleteBar
                            .background(boardColor)
                    }
                }
                if vm.gameState == .won {
                    winBanner
                }
            }
        }
    }

    // MARK: - Header

    var headerBar: some View {
        HStack(spacing: theme.spacing.s) {
            VideoModeTimerChip(theme: theme,
                               timerAnchor: vm.timerAnchor,
                               pausedElapsed: vm.pausedElapsed)
            Spacer()
            Text("Deal #\(vm.dealNumber) · \(vm.difficulty.label)")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }

    // MARK: - Board
    //
    // The outer ZStack covers both the top row and the tableau so the drag
    // overlay can float above either area regardless of where the drag started.

    func boardArea(geo: GeometryProxy) -> some View {
        let pad:    CGFloat = 8
        let gap:    CGFloat = 6
        let cardW   = (geo.size.width - 2 * pad - 6 * gap) / 7
        let cardH   = cardW * 1.4
        let topRowH = theme.spacing.s * 2 + cardH    // vertical padding + one card height

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                SolitaireTopRowView(
                    foundations: vm.board.foundations,
                    stock:       vm.board.stock,
                    waste:       vm.board.waste,
                    theme:       theme,
                    isClassic:   isClassic,
                    cardWidth:   cardW,
                    selectedIsWaste: vm.selection == .waste,
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
                        // Waste top card center x in board-ZStack space.
                        // Stock is flush-right inside pad; waste is one cardW+gap to its left.
                        let wasteCX = geo.size.width - pad - 1.5 * cardW - gap
                        dropTargetCol = colAtBoardX(wasteCX + translation.width,
                                                    cardW: cardW, gap: gap, pad: pad)
                    },
                    onWasteDragEnded: { translation in
                        finalizeWasteDrop(translation: translation, cardW: cardW)
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

    // MARK: - Tableau (tap + drag gesture)

    func tableauArea(cardW: CGFloat, gap: CGFloat, pad: CGFloat) -> some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(0..<7, id: \.self) { col in
                SolitaireColumnView(
                    cards:        vm.board.tableau[col],
                    theme:        theme,
                    isClassic:    isClassic,
                    cardWidth:    cardW,
                    selectedFrom: selectedFrom(col: col),
                    ghostFromIdx: isDragging && !dragIsFromWaste && dragSourceCol == col
                                    ? dragFromIdx : nil,
                    isDragTarget: isDragging
                        && dropTargetCol == col
                        && !dragCards.isEmpty
                        && SolitaireRules.canPlaceOnTableau(dragCards, onto: vm.board.tableau[col]),
                    onTap:       { idx in vm.tap(column: col, cardIndex: idx) },
                    onDoubleTap: { _   in vm.sendToFoundation(column: col) }
                )
            }
        }
        .coordinateSpace(.named("solitaire-tableau"))
        .padding(.horizontal, pad)
        .gesture(tableauDragGesture(cardW: cardW, gap: gap))
        .padding(.bottom, theme.spacing.xl)
    }

    // MARK: - Drag overlay
    //
    // Positioned in the board-level ZStack so it can float over both the
    // top row (waste drag) and the tableau (column drag).

    func dragOverlay(cardW: CGFloat, gap: CGFloat, pad: CGFloat,
                             topRowH: CGFloat, geoWidth: CGFloat) -> some View {
        let faceUpOff = cardW * 0.46

        let x: CGFloat
        let y: CGFloat
        if dragIsFromWaste {
            // Waste top card left edge: geoWidth - pad - stock(cardW) - gap - cardW
            x = geoWidth - pad - 2 * cardW - gap + dragOffset.width
            y = theme.spacing.s + dragOffset.height
        } else {
            let cardY = columnYOffset(col: dragSourceCol, fromIdx: dragFromIdx, cardW: cardW)
            x = pad + CGFloat(dragSourceCol) * (cardW + gap) + dragOffset.width
            y = topRowH + theme.spacing.s + cardY + dragOffset.height
        }

        return ZStack(alignment: .top) {
            ForEach(0..<dragCards.count, id: \.self) { i in
                PlayingCardView(dragCards[i], theme: theme, isClassic: isClassic, width: cardW)
                    .offset(y: CGFloat(i) * faceUpOff)
                    .zIndex(Double(i))
            }
        }
        .frame(width: cardW)
        .scaleEffect(1.04, anchor: .top)
        .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 6)
        .offset(x: x, y: y)
        .zIndex(999)
        .allowsHitTesting(false)
        .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.9), value: dragOffset)
    }

    // MARK: - Drag gesture (tableau columns)

    func tableauDragGesture(cardW: CGFloat, gap: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("solitaire-tableau"))
            .onChanged { value in
                if !isDragging {
                    guard
                        let col = colAt(x: value.startLocation.x, cardW: cardW, gap: gap),
                        let idx = cardAt(y: value.startLocation.y, col: col, cardW: cardW),
                        vm.board.tableau[col][idx].isFaceUp
                    else { return }

                    let seq = SolitaireRules.pickableSequence(
                        from: vm.board.tableau[col], startingAt: idx
                    )
                    guard !seq.isEmpty else { return }

                    dragSourceCol   = col
                    dragFromIdx     = idx
                    dragCards       = seq
                    dragIsFromWaste = false
                    isDragging      = true
                    vm.clearSelection()
                    pickUpTick     += 1
                }
                dragOffset    = value.translation
                dropTargetCol = colAt(x: value.location.x, cardW: cardW, gap: gap)
            }
            .onEnded { val in finalizeDrop(value: val, cardW: cardW) }
    }

    func finalizeDrop(value: DragGesture.Value, cardW: CGFloat) {
        defer {
            isDragging      = false
            dragOffset      = .zero
            dropTargetCol   = nil
            dragCards       = []
            dragIsFromWaste = false
        }
        // Drop above the tableau → try to send single card to foundation
        if value.location.y < 0 && dragCards.count == 1 {
            if vm.sendToFoundation(column: dragSourceCol) {
                dropTick += 1
            } else {
                rejectTick += 1
            }
            return
        }
        guard
            let target = dropTargetCol,
            target != dragSourceCol,
            SolitaireRules.canPlaceOnTableau(dragCards, onto: vm.board.tableau[target])
        else {
            rejectTick += 1
            return
        }
        vm.commitDrag(fromColumn: dragSourceCol, fromIdx: dragFromIdx, toColumn: target)
        dropTick += 1
    }

    func finalizeWasteDrop(translation: CGSize, cardW: CGFloat) {
        defer {
            isDragging      = false
            dragOffset      = .zero
            dropTargetCol   = nil
            dragCards       = []
            dragIsFromWaste = false
        }
        // Drag stayed in the shelf row (< one card height down) → try foundation
        if translation.height < cardW * 1.4 {
            if vm.sendWasteToFoundation() {
                dropTick += 1
                return
            }
        }
        guard
            let target = dropTargetCol,
            let topCard = vm.board.topWaste,
            SolitaireRules.canPlaceOnTableau([topCard], onto: vm.board.tableau[target])
        else {
            rejectTick += 1
            return
        }
        vm.commitWasteDrag(toColumn: target)
        dropTick += 1
    }

    // MARK: - Coordinate helpers

    // x is in "solitaire-tableau" space (HStack local, before horizontal pad).
    func colAt(x: CGFloat, cardW: CGFloat, gap: CGFloat) -> Int? {
        guard x >= 0 else { return nil }
        let col = Int(x / (cardW + gap))
        guard col < 7 else { return nil }
        let colStart = CGFloat(col) * (cardW + gap)
        guard x < colStart + cardW else { return nil }
        return col
    }

    // x is in board-ZStack space (includes left pad); subtracts pad before col lookup.
    func colAtBoardX(_ x: CGFloat, cardW: CGFloat, gap: CGFloat, pad: CGFloat) -> Int? {
        colAt(x: x - pad, cardW: cardW, gap: gap)
    }

    func cardAt(y: CGFloat, col: Int, cardW: CGFloat) -> Int? {
        let column = vm.board.tableau[col]
        guard !column.isEmpty, y >= 0 else { return nil }
        let faceDownOff = cardW * 0.20
        let faceUpOff   = cardW * 0.46
        var offsets: [CGFloat] = [0]
        for i in 1..<column.count {
            offsets.append(offsets[i-1] + (column[i-1].isFaceUp ? faceUpOff : faceDownOff))
        }
        for idx in stride(from: column.count - 1, through: 0, by: -1) {
            if y >= offsets[idx] { return idx }
        }
        return 0
    }

    func columnYOffset(col: Int, fromIdx: Int, cardW: CGFloat) -> CGFloat {
        let column = vm.board.tableau[col]
        guard fromIdx > 0 else { return 0 }
        let faceDownOff = cardW * 0.20
        let faceUpOff   = cardW * 0.46
        return (0..<fromIdx).reduce(CGFloat(0)) { acc, i in
            acc + (column[i].isFaceUp ? faceUpOff : faceDownOff)
        }
    }

    func selectedFrom(col: Int) -> Int? {
        guard case .column(let c, let from) = vm.selection, c == col else { return nil }
        return from
    }

    // MARK: - Auto-complete

    var autoCompleteBar: some View {
        Button("Auto-Complete") { withAnimation { vm.autoComplete() } }
            .buttonStyle(.borderedProminent)
            .tint(theme.colors.accentPrimary)
            .padding(.bottom, theme.spacing.m)
    }

    // MARK: - Win banner

    var winBanner: some View {
        VStack(spacing: theme.spacing.m) {
            Text("You won!")
                .font(theme.typography.title)
                .foregroundStyle(theme.colors.textPrimary)
            Text("\(vm.moveCount) moves")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
            Button("New Game") { showingNewGame = true }
                .buttonStyle(.borderedProminent)
                .tint(theme.colors.accentPrimary)
        }
        .padding(theme.spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(theme.colors.surface)
                .shadow(color: .black.opacity(0.2), radius: 20)
        )
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { vm.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(vm.canUndo ? theme.colors.accentPrimary : theme.colors.textSecondary)
            .disabled(!vm.canUndo)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(SolitaireDifficulty.allCases, id: \.self) { d in
                    Button("New \(d.label) Game") { vm.startNewGame(difficulty: d) }
                }
                Divider()
                Button("Restart This Deal") {
                    vm.restartCurrentDeal()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(theme.colors.accentPrimary)
            }
        }
    }
}
