//
//  NonogramBoardView+VideoMode.swift
//  gamekit
//
//  Phase 12 Plan 12-05 — Video-Mode-aware cell-size floor for NonogramBoardView.
//
//  Extension-only file because NonogramBoardView.swift is at the §8.5
//  500-line hard cap; adding the floor seam constants would push it past.
//  The @Environment(\.videoModeStore) env read stays on the host struct
//  (Swift restriction: extensions cannot add stored property wrappers);
//  the static floor constants + helper live here.
//
//  D-NG-15 contract: single-gate purely on videoModeStore.isEnabled — NO
//  location.isLarge, NO difficulty conditioning. The floor applies
//  regardless of PiP zone.
//
//  D-NG-17 contract: this extension adds ONLY a new static constant + a
//  new static helper. The host's slide gesture, super-cell rules, hint
//  geometry, fill/X mark rendering all stay byte-identical to git HEAD.
//

import SwiftUI
import DesignKit

extension NonogramBoardView {
    /// Video-Mode-aware floor for Hard 15×15 on Large PiP zones.
    ///
    /// The off-path floor `minCellSize: 14` is unchanged (host file). When
    /// Video Mode is On, Nonogram's hardest difficulty (15×15 Hard) needs
    /// to fit inside the available area between the reserved video band
    /// and the compact row — the working floor of 14pt pushes wider than
    /// the largeBottom container can accommodate.
    ///
    /// The locked value comes from the Plan 12-05 audit on iPhone 17 Pro
    /// Max simulator @ largeBottom × 15×15 Hard, evaluated on Dracula +
    /// Voltage per CLAUDE.md §8.12. Working number per CONTEXT D-NG-15 is
    /// ~11-12pt; final lock recorded in 12-05-SUMMARY.md + 12-06
    /// release-log.
    ///
    /// Rollback condition (mirror of P11-05 ADR §Rollback): if hint
    /// legibility fails §8.12 audit at every candidate floor, fall back
    /// to existingLayout on Large zones (instead of dropping the floor).
    ///
    /// TODO 12-05 audit: replace placeholder with the locked value before
    /// the human-verify checkpoint (Task 2) closes.
    static let minCellSizeVideoMode: CGFloat = 12   // PLACEHOLDER — locked at Task 2

    /// Returns the appropriate floor for the current Video Mode state.
    /// Off → minCellSize (v1.0 = 14). On → minCellSizeVideoMode.
    /// Single gate per D-NG-15 / CONTEXT line 80-91: no location.isLarge,
    /// no difficulty conditioning. The floor applies regardless of zone.
    static func minCellSize(videoModeOn: Bool) -> CGFloat {
        videoModeOn ? minCellSizeVideoMode : minCellSize
    }
}
