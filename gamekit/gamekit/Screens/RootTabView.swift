//
//  RootTabView.swift
//  gamekit
//
//  Plan 06 ships this as a build-clean stub.
//  Plan 07 expands it to a 3-tab TabView (Home / Stats / Settings)
//  with NavigationStack roots per D-02.
//

import SwiftUI
import DesignKit

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        // Plan 07 replaces this body with the 3-tab TabView.
        Rectangle()
            .fill(theme.colors.background)
            .ignoresSafeArea()
    }
}
