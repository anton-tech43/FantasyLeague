import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) var modelContext
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showTeamPicker = false
    @State private var showTierPicker = false
    @State private var showDeleteConfirmation = false
    @State private var showDeleteSuccess = false
    @State private var showDeleteError = false
    @State private var isDeleting = false
    @State private var editingHerName = false
    @State private var editingHisName = false
    @State private var herNameDraft = ""
    @State private var hisNameDraft = ""

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Layout.sectionSpacing) {
                    // FEED FORMAT
                    feedFormatSection

                    // YOUR SETUP
                    settingsSection(header: "YOUR SETUP") {
                        // Your Name
                        settingsRow {
                            Button {
                                herNameDraft = appState.herName
                                editingHerName = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Your Name")
                                            .font(.feedTimestamp)
                                            .foregroundColor(.textSecondaryOnCard)
                                        Text(appState.herName.isEmpty ? "Not set" : appState.herName)
                                            .font(.feedHeadline)
                                            .foregroundColor(.textPrimaryOnCard)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.textSecondaryOnCard)
                                        .font(.system(size: 12))
                                }
                            }
                        }

                        // His Name
                        settingsRow {
                            Button {
                                hisNameDraft = appState.hisName
                                editingHisName = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("His Name")
                                            .font(.feedTimestamp)
                                            .foregroundColor(.textSecondaryOnCard)
                                        Text(appState.hisName.isEmpty ? "Not set" : appState.hisName)
                                            .font(.feedHeadline)
                                            .foregroundColor(.textPrimaryOnCard)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.textSecondaryOnCard)
                                        .font(.system(size: 12))
                                }
                            }
                        }

                        // His Team
                        settingsRow {
                            Button { showTeamPicker = true } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(appState.hisName.isEmpty ? "His" : appState.hisName + "'s") Team")
                                            .font(.feedTimestamp)
                                            .foregroundColor(.textSecondaryOnCard)
                                        Text(appState.selectedTeam?.displayName ?? "None")
                                            .font(.feedHeadline)
                                            .foregroundColor(.textPrimaryOnCard)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.textSecondaryOnCard)
                                        .font(.system(size: 12))
                                }
                            }
                        }

                        // Your Mode
                        settingsRow {
                            Button { showTierPicker = true } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Your Mode")
                                            .font(.feedTimestamp)
                                            .foregroundColor(.textSecondaryOnCard)
                                        Text(tierLabel(appState.selectedTier))
                                            .font(.feedHeadline)
                                            .foregroundColor(.textPrimaryOnCard)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.textSecondaryOnCard)
                                        .font(.system(size: 12))
                                }
                            }
                        }
                    }

                    // NOTIFICATIONS
                    settingsSection(header: "NOTIFICATIONS") {
                        settingsRow {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Notifications")
                                        .font(.feedTimestamp)
                                        .foregroundColor(.textSecondaryOnCard)

                                    if notificationStatus == .authorized {
                                        HStack(spacing: 4) {
                                            Text("Enabled")
                                                .font(.feedHeadline)
                                                .foregroundColor(.textPrimaryOnCard)
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.hotRose)
                                                .font(.system(size: 14))
                                        }
                                    } else {
                                        Button {
                                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                                UIApplication.shared.open(url)
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text("Disabled")
                                                    .font(.feedHeadline)
                                                    .foregroundColor(.textPrimaryOnCard)
                                                Text("Open Settings")
                                                    .font(.feedTimestamp)
                                                    .foregroundColor(.hotRose)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                    }

                    // ABOUT
                    settingsSection(header: "ABOUT") {
                        settingsRow {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("GoalDigger")
                                    .font(.feedHeadline)
                                    .foregroundColor(.textPrimaryOnCard)
                                Text("For the girlfriend who's done nodding along. Made for her, not him.")
                                    .font(.feedTimestamp)
                                    .foregroundColor(.textSecondaryOnCard)
                            }
                        }
                    }

                    // FOOTER LINKS
                    VStack(spacing: Layout.cardSpacing) {
                        settingsRow {
                            Button {
                                if let url = URL(string: "mailto:hello@goaldigger.app") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Text("Contact Us")
                                        .font(.settingsItem)
                                        .foregroundColor(.textPrimaryOnCard)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.textSecondaryOnCard)
                                        .font(.system(size: 12))
                                }
                            }
                        }

                        settingsRow {
                            Button {
                                if let url = URL(string: "https://getgoaldigger.com/privacy") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Text("Privacy Policy")
                                        .font(.settingsItem)
                                        .foregroundColor(.textPrimaryOnCard)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.textSecondaryOnCard)
                                        .font(.system(size: 12))
                                }
                            }
                        }

                        // Restore Purchases removed: paid app on App Store, no IAP. The
                        // App Store handles redownload/restore automatically when a user
                        // reinstalls; an in-app button would just confuse them.

                        settingsRow {
                            Button { showDeleteConfirmation = true } label: {
                                HStack {
                                    Text("Delete My Data")
                                        .font(.settingsItem)
                                        .foregroundColor(.hotRose)
                                    Spacer()
                                    if isDeleting {
                                        ProgressView()
                                            .tint(.hotRose)
                                    }
                                }
                            }
                            .disabled(isDeleting)
                        }
                    }

                    // Version
                    Text("Version 1.0.0")
                        .font(.jakarta(11, weight: .regular))
                        .foregroundColor(.textTertiary.opacity(0.6))
                        .padding(.top, 8)
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            notificationStatus = await NotificationService.shared.checkNotificationStatus()
        }
        .sheet(isPresented: $showTeamPicker) {
            TeamPickerSheet()
        }
        .sheet(isPresented: $showTierPicker) {
            TierPickerSheet()
        }
        .alert("Edit Your Name", isPresented: $editingHerName) {
            TextField("Your name", text: $herNameDraft)
            Button("Save") {
                appState.herName = herNameDraft.trimmingCharacters(in: .whitespaces)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Edit His Name", isPresented: $editingHisName) {
            TextField("His name", text: $hisNameDraft)
            Button("Save") {
                appState.hisName = hisNameDraft.trimmingCharacters(in: .whitespaces)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete My Data", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deleteData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your data from our servers and you'll stop receiving notifications. This can't be undone.")
        }
        .alert("Data Deleted", isPresented: $showDeleteSuccess) {
            Button("OK") {
                appState.clearAllData()
                CacheService.shared.clearAll(in: modelContext)
            }
        } message: {
            Text("Your data has been deleted. You'll no longer receive notifications.")
        }
        .alert("Couldn't Delete", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't reach the server to delete your data. Check your connection and try again.")
        }
    }

    // MARK: - Feed Format Section

    @ViewBuilder
    private var feedFormatSection: some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            Text("FEED FORMAT")
                .font(.jakarta(11, weight: .semiBold))
                .tracking(1)
                .foregroundColor(.hotRose.opacity(0.7))
                .padding(.leading, 4)

            HStack(spacing: 0) {
                // Immersive option
                Button {
                    appState.feedStyle = .immersive
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 14))
                        Text("Immersive")
                            .font(.jakarta(17, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(appState.feedStyle == .immersive ? Color.hotRose : Color.softBlush)
                    .foregroundColor(appState.feedStyle == .immersive ? .warmWhite : .charcoal)
                    .cornerRadius(12)
                }

                // Classic option
                Button {
                    appState.feedStyle = .classic
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14))
                        Text("Classic")
                            .font(.jakarta(17, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(appState.feedStyle == .classic ? Color.hotRose : Color.softBlush)
                    .foregroundColor(appState.feedStyle == .classic ? .warmWhite : .charcoal)
                    .cornerRadius(12)
                }
            }
            .padding(4)
            .background(Color.softBlush.opacity(0.5))
            .cornerRadius(16)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsSection(header: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            Text(header)
                .font(.jakarta(11, weight: .semiBold))
                .tracking(1)
                .foregroundColor(.hotRose.opacity(0.7))
                .padding(.leading, 4)

            content()
        }
    }

    @ViewBuilder
    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .cardStyle()
    }

    private func tierLabel(_ tier: Int) -> String {
        switch tier {
        case 1: return "Just enough to get by"
        case 2: return "Came to impress"
        case 3: return "The one he brags about"
        default: return "Came to impress"
        }
    }

    private func deleteData() async {
        isDeleting = true
        defer { isDeleting = false }

        // Privacy-impact: a silent failure here would tell the user their data
        // is gone when it isn't. Surface server errors as an alert so the user
        // can retry.
        guard let token = UserDefaults.standard.string(forKey: "apnsToken") else {
            // No token registered (rare — user never granted notification
            // permission). Nothing to delete server-side; clearing local state
            // is enough.
            showDeleteSuccess = true
            return
        }

        do {
            try await APIClient.shared.deleteMyData(token: token)
            showDeleteSuccess = true
        } catch {
            #if DEBUG
            print("⚠️ deleteMyData failed: \(error)")
            #endif
            showDeleteError = true
        }
    }
}

// MARK: - Team Picker Sheet

struct TeamPickerSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var selected: Team?
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Layout.cardSpacing) {
                        ForEach(Team.allCases.sorted { $0.displayName < $1.displayName }) { team in
                            TeamPickerCard(
                                team: team,
                                isSelected: team == (selected ?? appState.selectedTeam)
                            ) {
                                if team != appState.selectedTeam {
                                    selected = team
                                    showConfirmation = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Change Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.hotRose)
                }
            }
            .alert("Switch to \(selected?.displayName ?? "")?", isPresented: $showConfirmation) {
                Button("Switch") {
                    guard let team = selected else { return }
                    appState.selectedTeam = team
                    CacheService.shared.clearAll(in: modelContext)
                    appState.activeContext = .team(team)
                    appState.isContextSwitcherOpen = false
                    if let token = UserDefaults.standard.string(forKey: "apnsToken") {
                        Task {
                            try? await APIClient.shared.updateTokenTeam(token, newTeamId: team.rawValue)
                        }
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) { selected = nil }
            } message: {
                Text("Your feed will update to show content for the new team.")
            }
        }
    }
}

// MARK: - Tier Picker Sheet

struct TierPickerSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var selected: Int = 2

    private let tiers: [(number: Int, label: String, description: String)] = [
        (1, "Just enough to get by", "Just the essentials. No overload."),
        (2, "Came to impress", "Enough to hold your own in any conversation."),
        (3, "The one he brags about", "She knows things he hasn't even googled yet.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: Layout.cardSpacing) {
                    ForEach(tiers, id: \.number) { tier in
                        Button {
                            selected = tier.number
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(tier.label)
                                        .font(.feedHeadline)
                                        .foregroundColor(.textPrimaryOnCard)
                                    Spacer()
                                    if selected == tier.number {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(tier.number == 3 ? .tierGold : .hotRose)
                                    }
                                }
                                Text(tier.description)
                                    .font(.onboardingBody)
                                    .foregroundColor(.textSecondaryOnCard)
                                    .multilineTextAlignment(.leading)
                            }
                            .cardStyle()
                            .overlay(
                                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                                    .stroke(
                                        selected == tier.number
                                            ? (tier.number == 3 ? Color.tierGold : Color.hotRose)
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, 16)
            }
            .navigationTitle("Change Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.hotRose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.selectedTier = selected
                        if let token = UserDefaults.standard.string(forKey: "apnsToken") {
                            Task {
                                try? await APIClient.shared.updateTokenTier(token, tier: selected)
                            }
                        }
                        dismiss()
                    }
                    .foregroundColor(.hotRose)
                }
            }
            .onAppear { selected = appState.selectedTier }
        }
    }
}
