//
//  PieceCTAButton.swift
//  gamekit
//
//  The piece call-to-action (DESIGN.md §3.8): a large piece with a rounded,
//  bold label. Primary is the accent-filled action; secondary is a neutral
//  piece. GameDrawer-local on purpose: DKButton (and DesignKit) stay as they
//  are (D-07, D-20) because HabitTracker and FitnessTracker consume them.
//  Lives in Core so Home (Phase 20) and the other games (Phase 20.1) reuse it.
//

import SwiftUI
import DesignKit

struct PieceCTAButton: View {
    enum Prominence {
        case primary
        case secondary
    }

    let title: String
    let theme: Theme
    var prominence: Prominence = .primary
    var identifier: String? = nil
    let action: () -> Void

    init(
        _ title: String,
        theme: Theme,
        prominence: Prominence = .primary,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.theme = theme
        self.prominence = prominence
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        let primary = prominence == .primary
        Button(action: action) {
            Text(title)
                .font(RoundedType.font(.headline, weight: .bold))
                .foregroundStyle(primary ? theme.colors.background : theme.colors.textPrimary)
                .multilineTextAlignment(.center)
                // At the largest text sizes a long label wraps instead of
                // truncating ("Back to th...").
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.m)
        }
        .buttonStyle(.piece(
            theme: theme,
            role: primary ? .filled(theme.colors.accentPrimary) : .neutral,
            shape: .rounded(theme.radii.button),
            size: .large
        ))
        .modifier(OptionalIdentifier(identifier: identifier))
    }
}

private struct OptionalIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
