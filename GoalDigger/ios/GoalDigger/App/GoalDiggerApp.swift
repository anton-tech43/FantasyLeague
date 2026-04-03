import SwiftUI
import UserNotifications

@main
struct GoalDiggerApp: App {
    @State private var appState = AppState.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            FeedView()
        } else {
            OnboardingFlow()
        }
    }
}

// MARK: - Onboarding Flow
// 6 steps: Welcome → Your Name → Partner Name → Team → Notifications → Celebration
//
// Design decisions for other agents:
// - Name inputs are inline views (not separate files) to avoid pbxproj registration
// - Celebration screen sets hasCompletedOnboarding (not NotificationPromptView)
// - Each step uses gradient background and serif fonts for editorial feel
// - NameInputView is reused for both user name and partner name

struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0

    var body: some View {
        Group {
            switch currentStep {
            case 0:
                WelcomeView {
                    withAnimation { currentStep = 1 }
                }
            case 1:
                NameInputView(
                    title: "What's your name?",
                    subtitle: "So we can make this feel personal.",
                    placeholder: "Your name",
                    onContinue: { name in
                        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
                        appState.userName = trimmed.isEmpty ? nil : trimmed
                        withAnimation { currentStep = 2 }
                    }
                )
            case 2:
                NameInputView(
                    title: "And his name?",
                    subtitle: "The football fan in your life.",
                    placeholder: "His name",
                    onContinue: { name in
                        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
                        appState.partnerName = trimmed.isEmpty ? nil : trimmed
                        withAnimation { currentStep = 3 }
                    }
                )
            case 3:
                TeamSelectionView {
                    withAnimation { currentStep = 4 }
                }
            case 4:
                NotificationPromptView {
                    withAnimation { currentStep = 5 }
                }
            case 5:
                OnboardingCelebrationView {
                    appState.hasCompletedOnboarding = true
                }
            default:
                EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        ))
    }
}

// MARK: - Name Input View (inline — used for both user and partner name)
// Kept inline in this file to avoid needing a new pbxproj entry.

private struct NameInputView: View {
    let title: String
    let subtitle: String
    let placeholder: String
    let onContinue: (String) -> Void
    @State private var name = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            Text(title)
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textSecondary)

            TextField(placeholder, text: $name)
                .font(Theme.detailTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isFocused)
                .padding(.vertical, 16)
                .overlay(
                    Rectangle()
                        .fill(Theme.accentPink)
                        .frame(height: 2),
                    alignment: .bottom
                )
                .padding(.horizontal, 40)

            Spacer()

            Button {
                onContinue(name)
            } label: {
                Text(name.isEmpty ? "Skip" : "Continue")
                    .gradientButton()
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .onAppear { isFocused = true }
    }
}

// MARK: - Onboarding Celebration View
// Final onboarding step — confirms setup and sets hasCompletedOnboarding.

private struct OnboardingCelebrationView: View {
    @Environment(AppState.self) private var appState
    let onComplete: () -> Void
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            // Animated celebration
            Text("🎉")
                .font(.system(size: 70))
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.5).repeatCount(1),
                    value: isAnimating
                )

            Text("You're all set!")
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)

            VStack(spacing: 8) {
                if let partner = appState.partnerName, let team = appState.selectedTeam {
                    Text("We'll keep you in the loop on \(partner)'s \(team.shortName).")
                        .font(Theme.onboardingBody)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("We'll keep you in the loop on \(appState.selectedTeam?.shortName ?? "your team").")
                        .font(Theme.onboardingBody)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Text("Time to impress.")
                    .font(Theme.conversationStarter)
                    .foregroundStyle(Theme.accentPink)
            }
            .frame(maxWidth: 300)

            Spacer()

            Button(action: onComplete) {
                Text("Let's go!")
                    .gradientButton()
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .onAppear { isAnimating = true }
    }
}

// MARK: - Profile View
// Replaces the old gear/settings. Contains:
// - Your details (name, partner, team)
// - Saved talking points link
// - Notification preferences per category
// - About section
// Kept inline to avoid pbxproj registration.

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var notificationsEnabled = false
    @State private var showingTeamChange = false
    @State private var savedCount = 0

    // Notification category preferences
    @State private var matchDayEnabled = true
    @State private var moodAlertEnabled = true
    @State private var headsUpEnabled = true
    @State private var conversationStarterEnabled = true
    @State private var generalUpdateEnabled = true

    private let prefsKey = "notificationCategories"

    var body: some View {
        List {
            // Your Details
            Section("Your details") {
                if let name = appState.userName {
                    detailRow("Your name", value: name)
                }
                if let partner = appState.partnerName {
                    detailRow("His name", value: partner)
                }
                Button {
                    showingTeamChange = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("His team")
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

            // Notification Preferences
            Section {
                notifToggle("Match Day", isOn: $matchDayEnabled, key: "matchday")
                notifToggle("Mood Alert", isOn: $moodAlertEnabled, key: "mood_alert")
                notifToggle("Heads Up", isOn: $headsUpEnabled, key: "heads_up")
                notifToggle("Conversation Starter", isOn: $conversationStarterEnabled, key: "conversation_starter")
                notifToggle("General Updates", isOn: $generalUpdateEnabled, key: "general_update")
            } header: {
                Text("Notifications")
            } footer: {
                Text("Choose which types of updates send you a push notification. You'll still see everything in your feed.")
                    .font(Theme.feedTimestamp)
            }

            // System notification status
            Section {
                HStack {
                    Text("System notifications")
                        .font(Theme.settingsItem)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    if notificationsEnabled {
                        Text("Enabled")
                            .font(Theme.feedTimestamp)
                            .foregroundStyle(Theme.accentGreen)
                    } else {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(Theme.feedTimestamp)
                        .foregroundStyle(Theme.accentPink)
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
        .navigationTitle("Profile")
        .sheet(isPresented: $showingTeamChange) {
            teamChangeSheet
        }
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationsEnabled = settings.authorizationStatus == .authorized
        }
        .onAppear {
            savedCount = SavedPointsService.shared.savedPoints.count
            loadNotifPrefs()
        }
    }

    // MARK: - Notification Toggle

    private func notifToggle(_ label: String, isOn: Binding<Bool>, key: String) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(Theme.settingsItem)
                .foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.accentPink)
        .onChange(of: isOn.wrappedValue) { _, _ in
            saveNotifPrefs()
        }
    }

    private func loadNotifPrefs() {
        let prefs = UserDefaults.standard.dictionary(forKey: prefsKey) as? [String: Bool] ?? [:]
        matchDayEnabled = prefs["matchday"] ?? true
        moodAlertEnabled = prefs["mood_alert"] ?? true
        headsUpEnabled = prefs["heads_up"] ?? true
        conversationStarterEnabled = prefs["conversation_starter"] ?? true
        generalUpdateEnabled = prefs["general_update"] ?? true
    }

    private func saveNotifPrefs() {
        let prefs: [String: Bool] = [
            "matchday": matchDayEnabled,
            "mood_alert": moodAlertEnabled,
            "heads_up": headsUpEnabled,
            "conversation_starter": conversationStarterEnabled,
            "general_update": generalUpdateEnabled
        ]
        UserDefaults.standard.set(prefs, forKey: prefsKey)
    }

    // MARK: - Helpers

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.settingsItem)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.feedHeadline)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private var teamChangeSheet: some View {
        NavigationStack {
            VStack(spacing: Theme.sectionSpacing) {
                Text("Change team")
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
                                        .foregroundStyle(Theme.accentPink)
                                }
                            }
                            .padding(Theme.cardPadding)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                                    .stroke(
                                        appState.selectedTeam == team ? Theme.accentPink : .clear,
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
                    .foregroundStyle(Theme.accentPink)
                }
            }
        }
    }

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
}
