import SwiftUI

/// User settings: change team, notification preferences, about.
/// Full implementation in task I10.
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("Your Team") {
                    Text(appState.selectedTeam?.displayName ?? "None")
                }
                Section("About") {
                    Text("Goal Digger v1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
