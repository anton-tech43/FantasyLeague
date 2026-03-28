import SwiftUI

// TODO: Implement in I10
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("Your Team") {
                    Text(appState.selectedTeam?.displayName ?? "None selected")
                        .font(Theme.settingsItem)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
