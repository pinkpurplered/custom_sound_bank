import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }
}

enum IdleTimerController {
    private static var lockCount = 0

    static func preventSleep() {
        DispatchQueue.main.async {
            lockCount += 1
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    static func allowSleep() {
        DispatchQueue.main.async {
            lockCount = max(0, lockCount - 1)
            if lockCount == 0 {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    static func reassertPreventSleep() {
        DispatchQueue.main.async {
            guard lockCount > 0 else { return }
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
}

final class KeepScreenAwakeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        IdleTimerController.preventSleep()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IdleTimerController.allowSleep()
    }
}

struct KeepScreenAwakeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> KeepScreenAwakeViewController {
        KeepScreenAwakeViewController()
    }

    func updateUIViewController(_ uiViewController: KeepScreenAwakeViewController, context: Context) {}
}

private struct KeepScreenAwakeModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .background(KeepScreenAwakeView())
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    IdleTimerController.reassertPreventSleep()
                }
            }
    }
}

extension View {
    func keepScreenAwake() -> some View {
        modifier(KeepScreenAwakeModifier())
    }
}

enum OrientationController {
    static func lockToLandscape() {
        AppDelegate.orientationLock = .landscape
        applyRotation(.landscape)
    }

    static func unlock() {
        AppDelegate.orientationLock = .portrait
        applyRotation(.portrait)
    }

    private static func applyRotation(_ mask: UIInterfaceOrientationMask) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
        windowScene.requestGeometryUpdate(preferences) { _ in }
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
