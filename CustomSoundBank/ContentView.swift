import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PerformView()
                .tabItem {
                    Label("Live", systemImage: "lightbulb.fill")
                }

            BrowsePadsView()
                .tabItem {
                    Label("Samples", systemImage: "square.grid.3x3")
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
