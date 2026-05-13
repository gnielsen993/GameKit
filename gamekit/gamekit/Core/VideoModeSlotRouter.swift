//
//  VideoModeSlotRouter.swift
//  gamekit
//
//  Pure helper exposing per-zone slot-anchor data derived from
//  .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md "Where controls
//  go" columns. Consumed by Phase 11/12 game views.
//
//  CONTEXT D-02 lock: slot reposition lives in the GAME VIEW, not the modifier.
//  Every Phase 11/12 adopting game view calls
//  `VideoModeSlotRouter.anchors(for: store.location)` and arranges its own
//  subviews per the returned SlotAnchorMap. Phase 10 ships zero adoption — only
//  this helper + the Plan 10-03 ViewModifier.
//
//  Phase 10 invariants (per CONTEXT D-02 + D-08 + D-11):
//    - Large zones (.largeTop / .largeBottom) → all 4 slots consolidate into
//      .inCompactRow (the VideoCompactControlRow swallows the chrome when the
//      band reservation eats the top or bottom).
//    - Small zones (.smallTL / .smallTR / .smallBL / .smallBR) → slots place
//      opposite the covered corner (board stays at normal size).
//    - Switch is exhaustive on VideoModeLocation — adding a 7th case in v1.3+
//      produces a compile error here (project safety net).
//
//  Foundation-only — no SwiftUI import keeps this helper reusable from any
//  context (engine layer, tests, snapshot rigs).
//
//  Phase 13 forward-compat NOTE: the future banner-placement table in
//  .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md encodes the
//  same "opposite-of-PiP" geometry. If Phase 13 chooses to share, extend
//  SlotAnchorMap with a `banner: SlotAnchor` field and update the switch with
//  anchors from 08-BANNER-PLACEMENT.md. Don't pre-extend now (CLAUDE.md §2 —
//  needs 2+ consumers for promotion).
//

import Foundation

/// Where a single slot lives on the screen for a given PiP zone.
/// Conceptual (not coordinate) — game views translate this to layout intent.
///
/// `.inCompactRow` = the slot is demoted into VideoCompactControlRow (Large zones).
/// `.hidden` = the slot is not rendered at all for this zone (currently unused;
/// reserved for future per-game adoption decisions in P11+P12).
enum SlotAnchor: Sendable, Equatable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case inCompactRow
    case hidden
}

/// The 4 movable slots that every Phase 11/12 game view arranges per PiP zone.
///
/// Named fields (vs. `[SlotID: SlotAnchor]` dictionary) give the compiler
/// exhaustiveness — call sites can't typo a key, every slot is statically
/// guaranteed to be present. Per CONTEXT Claude's Discretion: planner picks
/// named-fields shape based on call-site ergonomics; this is the locked choice.
///
/// Slot semantics:
/// - `back`     — Back / dismiss affordance (every game has one)
/// - `settings` — Settings / overflow menu affordance (every game has one)
/// - `picker`   — Mines: Reveal/Flag mode picker · Merge: difficulty picker ·
///                Nonogram: Fill/Mark mode picker
/// - `fab`      — Mines: Reveal/Flag FAB (06.1-02 / MINES-12) · Merge: (none;
///                games without a FAB still receive an anchor — game view simply
///                does not render at that anchor) · Nonogram: (none)
struct SlotAnchorMap: Equatable, Sendable {
    let back: SlotAnchor
    let settings: SlotAnchor
    let picker: SlotAnchor
    let fab: SlotAnchor
}

/// Pure helper exposing slot-anchor data for each PiP zone.
///
/// Data source: per-game "Where controls go" columns in
/// .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md.
/// Cross-game variation (Mines vs Merge vs Nonogram) is NOT encoded here —
/// the table reflects the COMMON anchor pattern; per-game divergences (e.g.
/// Merge has no FAB) are handled by the game view choosing not to render at
/// the returned anchor for unused slots.
enum VideoModeSlotRouter {
    /// Returns where each of the 4 movable slots anchors for the given PiP zone.
    ///
    /// The switch is exhaustive on VideoModeLocation — a future 7th case
    /// (v1.3+) produces a compile error here (intentional safety net per
    /// CONTEXT §code_context).
    static func anchors(for location: VideoModeLocation) -> SlotAnchorMap {
        switch location {
        case .largeTop:
            // Compact row at bottom edge; all slots move INTO the compact row.
            return SlotAnchorMap(
                back: .inCompactRow,
                settings: .inCompactRow,
                picker: .inCompactRow,
                fab: .inCompactRow
            )
        case .largeBottom:
            // Compact row at top edge; same slot consolidation.
            return SlotAnchorMap(
                back: .inCompactRow,
                settings: .inCompactRow,
                picker: .inCompactRow,
                fab: .inCompactRow
            )
        case .smallTopLeft:
            // PiP covers TL → move all affordances toward trailing edge.
            return SlotAnchorMap(
                back: .topTrailing,
                settings: .topTrailing,
                picker: .bottomTrailing,
                fab: .bottomTrailing
            )
        case .smallTopRight:
            // PiP covers TR → move all affordances toward leading edge.
            return SlotAnchorMap(
                back: .topLeading,
                settings: .topLeading,
                picker: .bottomLeading,
                fab: .bottomLeading
            )
        case .smallBottomLeft:
            // PiP covers BL → top row distributes (back leading / settings
            // trailing); bottom-right keeps picker + fab clear of the covered
            // corner.
            return SlotAnchorMap(
                back: .topLeading,
                settings: .topTrailing,
                picker: .bottomTrailing,
                fab: .bottomTrailing
            )
        case .smallBottomRight:
            // PiP covers BR → top row distributes; bottom-left keeps picker
            // + fab clear of the covered corner.
            return SlotAnchorMap(
                back: .topLeading,
                settings: .topTrailing,
                picker: .bottomLeading,
                fab: .bottomLeading
            )
        }
    }
}
