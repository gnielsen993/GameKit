import SwiftUI
import UIKit

// Disables UINavigationController's interactive pop gesture recognizer.
// Applied to every game view so an accidental left-edge drag can't dismiss
// mid-game. The back button in the toolbar still works normally.
private struct SwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ vc: UIViewController, context: Context) {
        DispatchQueue.main.async {
            vc.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
}

extension View {
    func disableInteractivePop() -> some View {
        background(SwipeBackDisabler())
    }
}
