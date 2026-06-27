//
//  StackHarnessView.swift
//  gamekit
//
//  THROWAWAY — deleted at Phase 16 start, replaced by StackGameView().
//
//  Live substrate harness for Phase 15 verification. Drives the real
//  .arcadeLoop(isRunning:onTick:) modifier and shows a visibly-moving
//  element so the full substrate (ArcadeLoopDriver + fixed-timestep
//  accumulator + scenePhase pause) is exercised end-to-end before any
//  Stack gameplay exists.
//
//  Phase 15 invariants (per CONTEXT D-01/D-03/D-05):
//    - .arcadeLoop is the only loop driver — no CADisplayLink, no Timer
//    - .inactive AND .background both call vm.pause() — notification
//      banners (.inactive) must stop the loop (PITFALL-P1)
//    - On resume (.active) vm.resume() only transitions from .paused;
//      avoids unintended start from .idle (guarded in StackHarnessVM)
//    - Fixed-timestep accumulator lives here in the VM, NOT in ArcadeLoopDriver
//    - No .videoModeAware() — exemption per CONTEXT D-10 / ADR ARCADE-08
//

import SwiftUI
import DesignKit

// MARK: - StackHarnessVM

@Observable @MainActor
final class StackHarnessVM {

    // MARK: State surface

    private(set) var state: ArcadeGameState = .idle
    /// Monotonic tick counter; drives the harness visual (oscillation offset).
    /// Counter-trigger shape per DESIGN.md §8 / ARCADE-06.
    private(set) var tickCount: Int = 0

    // MARK: Fixed-timestep accumulator (CONTEXT Claude's Discretion)

    private var accumulator: Double = 0
    private let fixedDt = 1.0 / 60.0

    // MARK: Actions

    func tick(dt: Double) {
        guard state == .running else { return }
        accumulator += dt
        while accumulator >= fixedDt {
            tickCount += 1
            accumulator -= fixedDt
        }
    }

    func start() {
        state = .running
    }

    func pause() {
        if state == .running { state = .paused }
    }

    func resume() {
        if state == .paused { state = .running }
    }

    func stop() {
        state = .idle
        accumulator = 0
    }
}

// MARK: - StackHarnessView

struct StackHarnessView: View {

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var vm = StackHarnessVM()

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            VStack(spacing: theme.spacing.l) {
                // Oscillating dot: horizontal sine wave derived from tickCount.
                // Visible motion confirms the loop is running.
                let angle = Double(vm.tickCount) * (2 * .pi / 120.0)
                let xOffset = CGFloat(sin(angle) * 100)
                Circle()
                    .fill(theme.colors.accentPrimary)
                    .frame(width: 40, height: 40)
                    .offset(x: xOffset)

                Text("Ticks: \(vm.tickCount)")
                    .font(theme.typography.body.monospacedDigit())
                    .foregroundStyle(theme.colors.textSecondary)

                Text("State: \(String(describing: vm.state))")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)

                if vm.state == .idle {
                    Button("Tap to Start") {
                        vm.start()
                    }
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.accentPrimary)
                }
            }
        }
        .navigationTitle(String(localized: "Stack"))
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
        }
        .arcadeLoop(isRunning: vm.state == .running) { dt in
            vm.tick(dt: dt)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                vm.resume()
            case .inactive, .background:
                // Both .inactive (notification banners) and .background must stop
                // the real-time loop — CONTEXT D-03/D-05, RESEARCH Pitfall 1.
                vm.pause()
            @unknown default:
                vm.pause()
            }
        }
    }
}
