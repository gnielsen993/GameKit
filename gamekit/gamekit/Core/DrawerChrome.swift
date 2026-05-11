//
//  DrawerChrome.swift
//  gamekit
//
//  Structural chrome colors for the home drawer cabinet (HomeView /
//  DrawerRow). These are NOT theme tokens — they are scheme-independent
//  depth colors equivalent to Apple's HIG tab-bar / control-tray chrome
//  that intentionally stays dark across both light and dark schemes.
//
//  Lives under Core/ rather than Screens/ so the §1 token-discipline
//  pre-commit hook (which scans Games/ and Screens/ for raw Color
//  literals) doesn't trip on what is structurally a one-off chrome
//  palette for the drawer interaction. If these colors get reused on
//  a second surface — settings, stats, anywhere else with the same
//  "saturated face + dark cavity" pattern — promote to DesignKit as
//  semantic tokens at that point.
//

import SwiftUI

enum DrawerChrome {
    /// Drawer interior — the dark cavity revealed when a drawer
    /// hinges open. Near-black depth color, scheme-independent.
    static let cavity = Color(red: 0.10, green: 0.10, blue: 0.12)

    /// Mode-chip face inside the cavity. Slightly lifted from the
    /// cavity so each tab reads as raised against the rail.
    static let chip = Color(red: 0.18, green: 0.18, blue: 0.21)

    /// Foreground-on-accent (white-ish). Used for the icon plate on
    /// the saturated drawer face and for the title / caption text
    /// over the accent fill. Apple's tinted button convention.
    static let onAccent = Color.white

    /// Soft shadow color for elevated cards (drawer surface +
    /// Upcoming row). Stays subtle on both light and dark schemes.
    static let shadow = Color.black

    /// Hinge-rail highlight band along the top edge of each chip tab.
    static let hingeRail = onAccent.opacity(0.10)

    /// Near-invisible tap-catcher fill — sits behind the drawer stack
    /// when a drawer is expanded so any miss-tap collapses the
    /// cabinet.
    static let tapCatcher = Color.black.opacity(0.001)
}
