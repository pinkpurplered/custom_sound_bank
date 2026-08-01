import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PerformView()
                .tabItem {
                    Label("Perform", systemImage: "pianokeys")
                }

            CreateSampleView()
                .tabItem {
                    Label("Record", systemImage: "mic.circle")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "square.stack.3d.up")
                }
        }
        .tint(AppTheme.accent)
    }
}
