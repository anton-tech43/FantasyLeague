import SwiftUI
import UserNotifications

// MARK: - SettingsView (DEPRECATED)
// Replaced by ProfileView in GoalDiggerApp.swift.
// ProfileView adds notification category preferences and improved layout.
// This file is kept to avoid pbxproj churn — safe to delete in a future cleanup.

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var notificationsEnabled = false
    @State private var showingTeamChange = false
    @State private var savedCount = 0

    var body: some View {
        List {
            // Names Section
            if appState.userName != nil || appState.partnerName != nil {
                Section("Your details") {
                    if let name = appState.userName {
                        HStack {
                            Text("Your name")
                                .font(Theme.settingsItem)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(name)
                                .font(Theme.feedHeadline)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    if let partner = appState.partnerName {
                        HStack {
                            Text("His name")
                                .font(Theme.settingsItem)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(partner)
                                .font(Theme.feedHeadline)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
            }

            // Your Team
            Section {
                Button {
                    showingTeamChange = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Team")
                                .font(Theme.settingsItem)
                                .foregroundStyle(Theme.textSecondary)
                            Text(appState.selectedTeam?.displayName ?? "None")
                                .font(Theme.feedHeadline)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            // Saved Talking Points
            Section {
                NavigationLink {
                    SavedPointsView()
                } label: {
                    HStack {
                        Text("Saved talking points")
                            .font(Theme.settingsItem)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if savedCount > 0 {
                            Text("\(savedCount)")
                                .font(Theme.feedTimestamp)
                                .foregroundStyle(Theme.accentPink)
                        }
                    }
                }
            }

            // Notifications
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notifications")
                            .font(Theme.settingsItem)
                            .foregroundStyle(Theme.textSecondary)
                        if notificationsEnabled {
                            Text("Enabled")
                                .font(Theme.feedHeadline)
                                .foregroundStyle(Theme.accentGreen)
                        } else {
                            Text("Disabled")
                                .font(Theme.feedHeadline)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    Spacer()
                    if !notificationsEnabled {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(Theme.feedTimestamp)
                        .foregroundStyle(Theme.accentWarm)
                    }
                }
            }

            // About
            Section {
                NavigationLink {
                    aboutView
                } label: {
                    Text("About Goal Digger")
                        .font(Theme.settingsItem)
                        .foregroundStyle(Theme.textPrimary)
                }

                if let url = URL(string: "mailto:hello@goaldigger.app") {
                    Link(destination: url) {
                        HStack {
                            Text("Contact Us")
                                .font(Theme.settingsItem)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }

            // Version
            Section {
                HStack {
                    Text("Version")
                        .font(Theme.settingsItem)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("1.0")
                        .font(Theme.feedTimestamp)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingTeamChange) {
            teamChangeSheet
        }
        .task {
            await checkNotificationStatus()
        }
        .onAppear {
            savedCount = SavedPointsService.shared.savedPoints.count
        }
    }

    // MARK: - Team Change Sheet

    private var teamChangeSheet: some View {
        NavigationStack {
            VStack(spacing: Theme.sectionSpacing) {
                Text("Change your team")
                    .font(Theme.detailTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, Theme.sectionSpacing)

                VStack(spacing: Theme.cardSpacing) {
                    ForEach(Team.allCases) { team in
                        Button {
                            appState.selectedTeam = team
                            NotificationService.shared.handleTeamChange(newTeam: team)
                            showingTeamChange = false
                        } label: {
                            HStack {
                                Text(team.displayName)
                                    .font(Theme.feedHeadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if appState.selectedTeam == team {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.accentWarm)
                                }
                            }
                            .padding(Theme.cardPadding)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                                    .stroke(
                                        appState.selectedTeam == team ? Theme.accentWarm : .clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)

                Spacer()
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingTeamChange = false
                    }
                    .foregroundStyle(Theme.accentWarm)
                }
            }
        }
    }

    // MARK: - About View

    private var aboutView: some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                Text("Goal Digger")
                    .font(Theme.onboardingTitle)
                    .foregroundStyle(Theme.textPrimary)

                Text("Your relationship translator for football season.")
                    .font(Theme.onboardingBody)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Built for partners, friends, and anyone who wants to connect through football without needing a degree in sports science.")
                    .font(Theme.detailBody)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.screenPadding)
            }
            .padding(Theme.screenPadding)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("About")
    }

    // MARK: - Notification Check

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
    }
}
