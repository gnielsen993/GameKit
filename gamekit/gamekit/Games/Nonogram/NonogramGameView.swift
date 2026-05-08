//
//  NonogramGameView.swift
//  gamekit
//
//  Top-level Nonogram scene. Currently in GALLERY MODE — every puzzle is
//  shown pre-completed so reviewers can eyeball the picture before the
//  seed set is locked in. Once greenlit, the play-mode follow-up phase
//  swaps `isInteractive: false` for the live tap pipeline + adds the
//  end-state card.
//
//  Owns @EnvironmentObject themeManager + @Environment(\.colorScheme).
//  Child views (HeaderBar, BoardView, CellView, ModePill, ToolbarMenu)
//  receive `theme: Theme` as a let parameter, mirroring Minesweeper +
//  Merge for cross-game consistency.
//

import SwiftUI
import DesignKit

struct NonogramGameView: View {
    @State private var viewModel = NonogramViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    /// Gallery mode is the only state that ships in this phase.
    private var isInteractive: Bool { viewModel.state != .gallery }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                NonogramHeaderBar(
                    theme: theme,
                    title: viewModel.currentPuzzle?.title ?? String(localized: "Nonogram"),
                    positionLabel: viewModel.positionLabel,
                    onPrevious: { viewModel.previous() },
                    onNext: { viewModel.next() }
                )

                if viewModel.currentPuzzle != nil {
                    NonogramBoardView(
                        board: viewModel.board,
                        rowHints: viewModel.rowHints,
                        columnHints: viewModel.columnHints,
                        theme: theme,
                        isInteractive: isInteractive,
                        onTap: { _, _ in /* gallery: no-op */ },
                        onLongPress: { _, _ in /* gallery: no-op */ }
                    )
                    .padding(.horizontal, theme.spacing.s)
                } else {
                    Spacer()
                    Text(String(localized: "No puzzles bundled yet"))
                        .font(.callout)
                        .foregroundStyle(theme.colors.textSecondary)
                    Spacer()
                }

                NonogramModePill(
                    theme: theme,
                    mode: viewModel.interactionMode,
                    isInteractive: isInteractive,
                    onSelect: { viewModel.setInteractionMode($0) }
                )
                .padding(.top, theme.spacing.s)
                .opacity(isInteractive ? 1 : 0.45)
            }
            .padding(.bottom, theme.spacing.l)
        }
        .navigationTitle(String(localized: "Nonogram"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Back to The Drawer"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                NonogramToolbarMenu(
                    theme: theme,
                    currentDifficulty: viewModel.difficulty,
                    onSelect: { viewModel.setDifficulty($0) }
                )
            }
        }
    }
}
