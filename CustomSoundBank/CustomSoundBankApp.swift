import SwiftUI

@main
struct CustomSoundBankApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                appModel.instrumentRouter.allNotesOff()
            } else {
                appModel.recoverAudio()
            }
        }
    }
}
