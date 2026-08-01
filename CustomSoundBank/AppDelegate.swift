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
