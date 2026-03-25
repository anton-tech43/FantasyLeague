import SwiftUI
import SwiftData
import UserNotifications

/// Settings screen with team change, notification status, about, and contact.
struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var showTeamChange = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showConfirmation = false
    @State private var pendingTeam: Team?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showTeamChange = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your Team")
                                    .font(.settingsItem)
                                    .foregroundColor(.textSecondary)
                                Text(appState.selectedTeam?.displayName ?? "None")
                                    .font(.feedHeadline)
                                    .foregroundColor(.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.textTertiary)
                        }
                    }
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications")
                                .font(.settingsItem)
                                .foregroundColor(.textSecondary)

                            if notificationStatus == .authorized {
                                HStack(spacing: 4) {
                                    Text("Enabled")
                                        .font(.feedHeadline)
                                        .foregroundColor(.textPrimary)
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentGreen)
                                }
                            } else {
                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Disabled \u{2014} Open Settings")
                                            .font(.feedHeadline)
                                            .foregroundColor(.textPrimary)
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.textTertiary)
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("About Goal Digger")
                            .font(.settingsItem)
                            .foregroundColor(.textPrimary)
                    }

                    if let mailto = URL(string: "mailto:hello@goaldigger.app") {
                        Link(destination: mailto) {
                            HStack {
                                Text("Contact Us")
                                    .font(.settingsItem)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textTertiary)
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        Text("Version 1.0.0")
                            .font(.feedTimestamp)
                            .foregroundColor(.textTertiary)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showTeamChange) {
                teamChangeSheet
            }
            .confirmationDialog(
                "Switch to \(pendingTeam?.displayName ?? "")?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Switch Team") {
                    if let team = pendingTeam {
                        switchTeam(to: team)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your feed will update to show content for \(pendingTeam?.displayName ?? "the new team").")
            }
            .task {
                notificationStatus = await NotificationService.shared.checkAuthorizationStatus()
            }
        }
    }

    // MARK: - Team Change Sheet

    private var teamChangeSheet: some View {
        NavigationStack {
            VStack(spacing: Layout.cardSpacing) {
                Text("Switch Team")
                    .font(.detailTitle)
                    .foregroundColor(.textPrimary)
                    .padding(.top, Layout.sectionSpacing)

                ForEach(Team.allCases) { team in
                    TeamPickerCard(
                        team: team,
                        isSelected: appState.selectedTeam == team
                    ) {
                        if team != appState.selectedTeam {
                            pendingTeam = team
                            showTeamChange = false
                            showConfirmation = true
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Layout.screenPadding)
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showTeamChange = false }
                }
            }
        }
    }

    // MARK: - Team Switch Logic

    private func switchTeam(to team: Team) {
        let oldToken = UserDefaults.standard.string(forKey: "apnsToken")
        appState.selectedTeam = team

        if let token = oldToken {
            Task {
                try? await APIClient.shared.updateTokenTeam(token, newTeamId: team.rawValue)
            }
        }

        Task { @MainActor in
            CacheService.shared.clearAll(context: modelContext)
        }

        dismiss()
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                Text("Goal Digger")
                    .font(.detailTitle)
                    .foregroundColor(.textPrimary)

                Text("Stay in the loop. Win the conversation.")
                    .font(.detailBody)
                    .foregroundColor(.textSecondary)

                Text("Goal Digger helps you keep up with your partner's Premier League team \u{2014} without actually watching football. We send you the highlights, the talking points, and the things to say so you can connect over something he loves.")
                    .font(.detailBody)
                    .foregroundColor(.textPrimary)
                    .lineSpacing(4)

                Text("No jargon. No boring stats. Just the good stuff, explained like a friend would.")
                    .font(.detailBody)
                    .foregroundColor(.textSecondary)
                    .lineSpacing(4)
            }
            .padding(Layout.screenPadding)
        }
        .background(Color.appBackground)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environment(AppState.shared)
}
