import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) var modelContext
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showTeamPicker = false
    @State private var showTierPicker = false
    @State private var showDeleteConfirmation = false
    @State private var showDeleteSuccess = false
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Layout.cardSpacing) {
                    // Your Team
                    settingsCard {
                        Button {
                            showTeamPicker = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your Team")
                                        .font(.feedTimestamp)
                                        .foregroundColor(.textSecondaryOnCard)
                                    Text(appState.selectedTeam?.displayName ?? "None")
                                        .font(.feedHeadline)
                                        .foregroundColor(.textPrimaryOnCard)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textSecondaryOnCard)
                            }
                        }
                    }

                    // Your Tier
                    settingsCard {
                        Button {
                            showTierPicker = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your Level")
                                        .font(.feedTimestamp)
                                        .foregroundColor(.textSecondaryOnCard)
                                    Text(tierLabel(appState.selectedTier))
                                        .font(.feedHeadline)
                                        .foregroundColor(.textPrimaryOnCard)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textSecondaryOnCard)
                            }
                        }
                    }

                    // Notifications
                    settingsCard {
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
                                            .foregroundColor(.green)
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

                    // About
                    settingsCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About Goal Digger")
                                .font(.feedHeadline)
                                .foregroundColor(.textPrimaryOnCard)
                            Text("Football talk, simplified. Made for anyone who wants to connect with someone who loves the Premier League.")
                                .font(.feedTimestamp)
                                .foregroundColor(.textSecondaryOnCard)
                        }
                    }

                    // Contact Us
                    settingsCard {
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
                            }
                        }
                    }

                    // Privacy Policy
                    settingsCard {
                        Button {
                            if let url = URL(string: "https://goaldigger.app/privacy") {
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
                            }
                        }
                    }

                    // Delete My Data
                    settingsCard {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Text("Delete My Data")
                                    .font(.settingsItem)
                                    .foregroundColor(.red)
                                Spacer()
                                if isDeleting {
                                    ProgressView()
                                        .tint(.red)
                                }
                            }
                        }
                        .disabled(isDeleting)
                    }

                    // Version
                    Text("Version 1.0.0")
                        .font(.feedTimestamp)
                        .foregroundColor(.textTertiary)
                        .padding(.top, Layout.sectionSpacing)
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, 16)
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
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
        if let token = UserDefaults.standard.string(forKey: "apnsToken") {
            try? await APIClient.shared.deleteMyData(token: token)
        }
        isDeleting = false
        showDeleteSuccess = true
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

                VStack(spacing: Layout.cardSpacing) {
                    ForEach(Team.allCases) { team in
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
                    Spacer()
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, 16)
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
        (1, "Just enough to get by", "Match day heads-up and one key talking point."),
        (2, "Came to impress", "Regular news and talking points through the week."),
        (3, "The one he brags about", "Everything including deep news, stats context and transfer rumours.")
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
            .navigationTitle("Change Level")
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
