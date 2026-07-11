import SwiftUI
import DesignKit

struct FreeCellGameView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) var dismiss
    @Environment(\.videoModeStore) var videoModeStore
    @Environment(\.settingsStore) var settingsStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var vm: FreeCellViewModel
    @State var showingDealEntry = false
    @State private var dealEntryText   = ""
    @State private var dealEntryError  = false
    @State private var didInjectStats = false
    @State var dragState:       FreeCellDragState?
    @State var dragTarget:      FreeCellDest? = nil
    @State var headerHeight:    CGFloat = 44
    @State private var hintDismissTask: Task<Void, Never>? = nil
    @State private var showWinFlash = false

    private let initialMode: FreeCellMode

    var theme:     Theme   { themeManager.theme(using: colorScheme) }
    var isClassic: Bool    { themeManager.preset == .classicMuted }
    var fxEnabled: Bool    { settingsStore.animationsEnabled && !reduceMotion }

    var boardColor: Color {
        SolitaireFelt.boardColor(theme: theme, isClassic: isClassic)
    }

    init(initialMode: FreeCellMode) {
        self.initialMode = initialMode
        self._vm = State(initialValue: FreeCellViewModel(mode: initialMode))
    }

    // MARK: - Drag state

    struct FreeCellDragState {
        let source:      FreeCellSelection
        let cards:       [PlayingCard]
        var location:    CGPoint
        let touchOffset: CGPoint    // finger position within first card's bounds
        let cardWidth:   CGFloat
        var cardHeight:  CGFloat { cardWidth * 1.4 }
        var fanOffset:   CGFloat { cardWidth * 0.28 }
    }

    // MARK: - Body

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
        .navigationTitle("FreeCell")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection,
                         trigger: settingsStore.hapticsEnabled ? vm.selectTick : 0)
        .sensoryFeedback(.success,
                         trigger: settingsStore.hapticsEnabled ? vm.dropTick : 0)
        .sensoryFeedback(.error,
                         trigger: settingsStore.hapticsEnabled ? vm.rejectTick : 0)
        .sheet(isPresented: $showingDealEntry)  { dealEntrySheet }
        .alert("Resume game?", isPresented: Binding(
            get: { vm.pendingSaveState != nil },
            set: { _ in }
        )) {
            Button("Continue") {
                if let saved = vm.pendingSaveState { vm.restoreState(saved) }
            }
            Button("New Deal", role: .destructive) { vm.discardSaveAndLoadNew() }
        } message: {
            if let s = vm.pendingSaveState {
                Text("You have an in-progress FreeCell deal #\(s.dealNumber).")
            }
        }
        .task {
            guard !didInjectStats else { return }
            didInjectStats = true
            vm.gameStats = GameStats(modelContext: modelContext)
            vm.checkAndLoadOrRestoreState()
            if initialMode == .enterDeal && vm.pendingSaveState == nil { showingDealEntry = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { vm.saveCurrentState(); vm.pause() }
            else if phase == .active { vm.resume() }
        }
        .onChange(of: vm.board.canAutoComplete) { _, canAC in
            if canAC { vm.beginAutoCompleteAnimation() }
        }
        .sensoryFeedback(.success,
                         trigger: settingsStore.hapticsEnabled ? vm.winTick : 0)
        .onChange(of: vm.hintText) { _, text in
            guard text != nil else { return }
            hintDismissTask?.cancel()
            hintDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.5))
                vm.dismissHint()
            }
        }
        .onChange(of: vm.winTick) { _, _ in
            guard fxEnabled else { return }
            withAnimation(.easeIn(duration: 0.05)) { showWinFlash = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.easeOut(duration: 0.5)) { showWinFlash = false }
            }
        }
        .overlay {
            if showWinFlash {
                theme.colors.success.opacity(0.30)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) { hintToast }
        .feedbackAnimation(.easeInOut(duration: 0.22), value: vm.hintText != nil)
    }

    @ViewBuilder private var hintToast: some View {
        if let hint = vm.hintText {
            Text(hint)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, theme.spacing.m)
                .padding(.vertical, theme.spacing.s)
                .background(Capsule().fill(theme.colors.textPrimary.opacity(0.72)))
                .padding(.top, theme.spacing.s)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Normal layout (off Video Mode path + .largeBottom / bottom
    // small zones — see FreeCellGameView+VideoMode.videoModeLayout)

    var normalLayout: some View {
        GeometryReader { geo in
            let boardPad: CGFloat  = 10
            let colGap: CGFloat    = 4
            let boardW  = geo.size.width - 2 * boardPad
            let cardW   = (boardW - CGFloat(8 - 1) * colGap) / 8
            let cardH   = cardW * 1.4
            let shelfH  = cardH + 20   // .padding(.vertical, 10) each side

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────
                FreeCellHeaderBar(
                    theme:         theme,
                    timerAnchor:   vm.timerAnchor,
                    pausedElapsed: vm.pausedElapsed,
                    dealNumber:    vm.dealNumber,
                    difficulty:    vm.difficulty
                )
                .background(theme.colors.background)
                .background(GeometryReader { g in
                    Color.clear.onAppear { headerHeight = g.size.height }
                })

                // ── Shelf ─────────────────────────────────────────────
                FreeCellTopRowView(
                    vm: vm, theme: theme, isClassic: isClassic,
                    cardWidth: cardW, colGap: colGap,
                    dragSource: dragState?.source
                )
                .padding(.horizontal, boardPad)
                .padding(.vertical, 10)
                .background(theme.colors.background)

                // ── Board (felt) ───────────────────────────────────────
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
        .overlay {
            if vm.gameState == .won && fxEnabled {
                GeometryReader { g in
                    FreeCellCascadeView(theme: theme, isClassic: isClassic, screenSize: g.size)
                }
                .ignoresSafeArea()
            }
        }
        .overlay(alignment: .bottom) { winLossBanner }
    }

    // MARK: - Drag logic
    //
    // onDragChanged / onDragEnded + the source/target hit-testing math live
    // in FreeCellGameView+DragLogic.swift.

    // MARK: - Drag overlay

    @ViewBuilder
    func dragOverlay(cardW: CGFloat) -> some View {
        if let ds = dragState {
            let stackH = ds.cardHeight + CGFloat(ds.cards.count - 1) * ds.fanOffset
            let cardLeft = ds.location.x - ds.touchOffset.x
            let cardTop  = ds.location.y - ds.touchOffset.y
            ZStack(alignment: .top) {
                ForEach(Array(ds.cards.enumerated()), id: \.element.id) { idx, card in
                    PlayingCardView(card, theme: theme, isClassic: isClassic, width: cardW)
                        .offset(y: CGFloat(idx) * ds.fanOffset)
                        .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
                }
            }
            .frame(width: cardW)
            .position(x: cardLeft + cardW / 2, y: cardTop + stackH / 2)
            .allowsHitTesting(false)
            .scaleEffect(1.04)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                vm.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(vm.canUndo ? theme.colors.accentPrimary : theme.colors.textSecondary)
            .disabled(!vm.canUndo)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("New Random Game") {
                    let mode = FreeCellMode.random(vm.difficulty ?? .easy)
                    vm.startNewGame(mode: mode)
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

    // MARK: - Deal entry sheet

    private var dealEntrySheet: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.l) {
                Text("Enter a deal number between 1 and 32,000 to play that specific game.")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Deal number", text: $dealEntryText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                if dealEntryError {
                    Text("Please enter a number between 1 and 32,000.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.danger)
                }

                Button {
                    guard let n = Int(dealEntryText), (1...32_000).contains(n) else {
                        dealEntryError = true; return
                    }
                    dealEntryError = false
                    showingDealEntry = false
                    vm.startNewGame(mode: .deal(n))
                } label: {
                    Text("Play Deal #\(dealEntryText.isEmpty ? "—" : dealEntryText)")
                        .font(theme.typography.body.weight(.semibold))
                        .foregroundStyle(theme.colors.surface)
                        .padding(.horizontal, theme.spacing.xl)
                        .padding(.vertical, theme.spacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                                .fill(theme.colors.accentPrimary)
                        )
                }
                .disabled(dealEntryText.isEmpty)
            }
            .padding(.top, theme.spacing.l)
            .navigationTitle("Choose a Deal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showingDealEntry = false }
                        .foregroundStyle(theme.colors.accentPrimary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Win / loss banner

    @ViewBuilder
    var winLossBanner: some View {
        switch vm.gameState {
        case .won:
            bannerCard(
                title:   "Solved!",
                detail:  "Deal #\(vm.dealNumber) · \(formattedTime(vm.frozenElapsed))",
                color:   theme.colors.success
            )
        case .lost:
            bannerCard(
                title:   "No moves left",
                detail:  "Deal #\(vm.dealNumber)",
                color:   theme.colors.danger
            )
        default:
            EmptyView()
        }
    }

    private func bannerCard(title: String, detail: String, color: Color) -> some View {
        VStack(spacing: theme.spacing.xs) {
            Text(title)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.surface)
            Text(detail)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.surface.opacity(0.80))

            HStack(spacing: theme.spacing.m) {
                Button("New Game") {
                    vm.startNewGame(mode: .random(vm.difficulty ?? .easy))
                }
                Button("Restart") { vm.reset() }
            }
            .font(theme.typography.body.weight(.semibold))
            .foregroundStyle(theme.colors.surface)
            .padding(.top, theme.spacing.xs)
        }
        .padding(theme.spacing.l)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .fill(color)
                .shadow(color: .black.opacity(0.20), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, theme.spacing.l)
        .padding(.bottom, theme.spacing.l)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .feedbackAnimation(
            .spring(response: 0.4, dampingFraction: 0.8),
            value: vm.gameState == .won
        )
    }

    // MARK: - Helpers

    private func formattedTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60; let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
