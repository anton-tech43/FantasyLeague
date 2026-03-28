import SwiftUI
import SwiftData

@main
struct GoalDiggerApp: App {
    @State private var appState = AppState.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

/// Root view — shows onboarding or main feed based on app state
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                Text("Feed — coming soon")
            } else {
                Text("Onboarding — coming soon")
            }
        }
    }
}
