//
//  VideoModeAware.swift
//  gamekit
//
//  v1.2 Video Mode layout primitive — wraps a game view at the outermost layer
//  and applies container-level Video Mode behavior:
//    - off-restore short-circuit (D-05) — byte-identical to un-wrapped on Off
//    - large-band reservation (D-08) — .safeAreaInset(.top/.bottom) for
//      .largeTop / .largeBottom; passthrough on .small* zones (D-11)
//    - compactness publication (D-12) — \.videoModeCompactness env value
//      derived from (proxy.size.height - bandHeight - compactRowHeight) vs
//      minBoardHeight per the D-14 0.85× threshold
//
//  Phase 10 invariants (per CONTEXT D-01..D-16):
//    - reads VideoModeStore via @Environment(\.videoModeStore) — NO new env key
//      for isEnabled / location (D-04). The store is the single source of truth.
//    - largeBandFraction = 0.32 is a private static let (D-10);
//      NOT promoted to a DesignKit token (CLAUDE.md §2 — single consumer; see
//      Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png).
//    - Small PiP zones do NOT touch board frame / safe area (D-11) — the
//      modifier only publishes compactness. Slot reposition is the GAME VIEW's
//      concern in Phases 11/12 via VideoModeSlotRouter.anchors(for:).
//    - Hard-Mines MagnifyGesture stack (06.1-03 / A11Y-05) is UNTOUCHED here
//      (D-15) — modifier wraps MinesweeperGameView at the outermost layer in
//      Phase 11, NOT MinesweeperBoardView.
//
//  Adoption (call-site shape for Phases 11/12 — P10 ships ZERO adoption):
//    MinesweeperGameView()
//        .videoModeAware(minBoardHeight: 480)
//
//  Reference: developer.apple.com/documentation/swiftui/viewmodifier
//

import SwiftUI
import DesignKit

struct VideoModeAware: ViewModifier {
    @Environment(\.videoModeStore) private var store
    let minBoardHeight: CGFloat

    // MARK: - Layout constants (CONTEXT D-10 — private static; not DesignKit tokens)

    /// Measured from Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png
    /// (worst case): bottom PiP pill ≈ 809px / 2556px = 0.317 fraction. Locked to
    /// 0.32 (rounded up) for safe symmetric reservation on both .largeTop and
    /// .largeBottom. iOS native PiP top-dock is smaller (~0.19) — modest
    /// over-reservation on Large top accepted in exchange for one constant.
    /// Device-portable: fraction applies to any screen height via
    /// geometry.size.height * largeBandFraction.
    ///
    /// CLAUDE.md §2: NOT promoted to a DesignKit token (single consumer).
    private static let largeBandFraction: CGFloat = 0.32

    /// Compact-row height anchor — equals `theme.spacing.xl` (24pt) per Phase 8
    /// 08-COMPACT-ROW-TOKENS.md and VideoCompactControlRow.swift:38-47 (which
    /// sets `.frame(height: theme.spacing.xl)`). Resolved as a CGFloat constant
    /// here per 10-RESEARCH.md §Open Question A1 — the modifier does not have
    /// direct access to a `theme` env on iOS 17 SwiftUI, and threading a theme
    /// parameter through would force every call site to pass it. The constant
    /// keeps the modifier API surface to one parameter.
    ///
    /// If DesignKit later exposes `@Environment(\.theme)`, the modifier can
    /// read `theme.spacing.xl` directly and this constant can be deleted.
    private static let compactRowHeight: CGFloat = 24

    /// Threshold ratio for the middle compactness level (CONTEXT D-14): when
    /// the available board height is below `minBoardHeight` but at or above
    /// `minBoardHeight * 0.85`, publish `.collapsedSettings`. Below 0.85×
    /// publishes `.reducedTime`.
    private static let collapsedSettingsRatio: CGFloat = 0.85

    // MARK: - body(content:)

    func body(content: Content) -> some View {
        // CONTEXT D-05: hard short-circuit. Off-path is byte-identical to the
        // un-wrapped view. Accepts AnyView type-erasure cost (negligible on a
        // single per-game wrap — see 10-RESEARCH.md §AnyView Anti-Patterns).
        //
        // CONTEXT D-04 + Pitfall 2: read store.isEnabled (and below, store.location)
        // at the top of the body so @Observable's per-property tracking sees the
        // read in this body's scope, not in a nested closure that may have stale
        // tracking.
        if !store.isEnabled { return AnyView(content) }
        return AnyView(onPath(content: content))
    }

    @ViewBuilder
    private func onPath(content: Content) -> some View {
        // CONTEXT D-08: GeometryReader to read proxy.size.height for the
        // dynamic band height computation. The .frame(maxWidth:maxHeight:)
        // on the GeometryReader keeps it from collapsing when applied at a
        // non-greedy parent (Pitfall 4).
        //
        // 10-RESEARCH.md A2 / Open Question 2: in a NavigationStack-pushed
        // adopter, proxy.size.height already excludes the nav bar. Available
        // board height = proxy.size.height - bandHeight - compactRowHeight.
        // No additional safeAreaInsets.top adjustment needed for the current
        // P11/P12 call sites (MinesweeperGameView et al. own their own
        // toolbar collapse in Video Mode — that's Phase 11 work).
        GeometryReader { proxy in
            let band = bandHeight(for: store.location, in: proxy)
            let available = proxy.size.height - band - Self.compactRowHeight
            let compactness = pickCompactness(available: available)

            applyBand(to: content, in: proxy)
                .environment(\.videoModeCompactness, compactness)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Band reservation (CONTEXT D-08 + D-11)

    @ViewBuilder
    private func applyBand(to view: Content, in proxy: GeometryProxy) -> some View {
        switch store.location {
        case .largeTop:
            view.safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: proxy.size.height * Self.largeBandFraction)
            }
        case .largeBottom:
            view.safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: proxy.size.height * Self.largeBandFraction)
            }
        case .smallTopLeft, .smallTopRight, .smallBottomLeft, .smallBottomRight:
            // CONTEXT D-11: Small zones do NOT reserve a band. The board
            // stays at normal size; slot reposition is handled by the game
            // view's VideoModeSlotRouter call.
            view
        }
    }

    private func bandHeight(for loc: VideoModeLocation, in proxy: GeometryProxy) -> CGFloat {
        switch loc {
        case .largeTop, .largeBottom: return proxy.size.height * Self.largeBandFraction
        case .smallTopLeft, .smallTopRight, .smallBottomLeft, .smallBottomRight: return 0
        }
    }

    // MARK: - Compactness threshold (CONTEXT D-13 + D-14)

    private func pickCompactness(available: CGFloat) -> VideoModeCompactness {
        if available >= minBoardHeight { return .normal }
        if available >= minBoardHeight * Self.collapsedSettingsRatio { return .collapsedSettings }
        return .reducedTime
    }
}

// MARK: - View extension (CONTEXT D-01 adoption surface)

extension View {
    /// Wrap a game view with Video Mode container behavior:
    /// - Off-path: byte-identical to un-wrapped view (D-05).
    /// - Large PiP zones (.largeTop / .largeBottom): reserve a top or bottom
    ///   band sized at `geometry.size.height * 0.32` via `.safeAreaInset`.
    /// - Small PiP zones: no inset; publish only the compactness env so the
    ///   game view's slot router can reposition controls.
    /// - Always (when On): publish `\.videoModeCompactness` env value so
    ///   descendants can react to "we're getting cramped — drop Settings into
    ///   the overflow menu / hide the time chip" per the v1.2 plan-doc
    ///   compromise order.
    ///
    /// - Parameter minBoardHeight: the smallest board height (in points) at
    ///   which this game remains at `.normal` compactness. Below this floor,
    ///   the modifier publishes progressively tighter compactness levels per
    ///   CONTEXT D-14. Default `320pt` (smallest device safe minimum); each
    ///   adopting game should override with its actual game-board floor.
    ///
    /// Adoption (Phases 11/12):
    /// ```
    /// MinesweeperGameView()
    ///     .videoModeAware(minBoardHeight: 480)
    /// ```
    func videoModeAware(minBoardHeight: CGFloat = 320) -> some View {
        modifier(VideoModeAware(minBoardHeight: minBoardHeight))
    }
}

// MARK: - VideoModeCompactness (CONTEXT D-12 + D-13)

/// Discrete compactness level the modifier publishes via env when Video Mode
/// is On. Game views in Phases 11/12 read this via
/// `@Environment(\.videoModeCompactness)` and reduce chrome accordingly.
///
/// Levels map to the compromise-order steps in
/// Docs/GameDrawer-v1.2-Video-Mode-Plan.md §Compromise order:
///   - `.normal`            — steps 1–3 satisfied; full chrome.
///   - `.collapsedSettings` — step 4 — Settings demotes into an overflow menu.
///   - `.reducedTime`       — step 5 — hide time / secondary stats.
///
/// Step 6 (board shrink) is the Hard-Mines smaller-cells path from
/// 08-HARD-MINES-ADR.md — gated on `videoModeStore.isEnabled` inside
/// `MinesweeperBoardView.cellSize` in Phase 11. NOT a primitive concern.
enum VideoModeCompactness: Sendable, Equatable {
    case normal
    case collapsedSettings
    case reducedTime
}

/// EnvironmentKey for `\.videoModeCompactness` — same shape as
/// `VideoModeStoreKey` in `VideoModeStore.swift:104-113` and `SettingsStoreKey`
/// in `SettingsStore.swift:144-155`.
///
/// Default value is `.normal` so descendants that read the env without a
/// VideoModeAware ancestor (or on the off-path) see "no compactness reaction
/// needed" — the safe baseline.
private struct VideoModeCompactnessKey: EnvironmentKey {
    static let defaultValue: VideoModeCompactness = .normal
}

extension EnvironmentValues {
    var videoModeCompactness: VideoModeCompactness {
        get { self[VideoModeCompactnessKey.self] }
        set { self[VideoModeCompactnessKey.self] = newValue }
    }
}
