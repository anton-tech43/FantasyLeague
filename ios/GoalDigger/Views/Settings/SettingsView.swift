import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) var modelContext
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showTeamPicker = false
    @State private var showCountryPicker = false
    @State private var showTierPicker = false
    @State private var showDeleteConfirmation = false
    @State private var showDeleteSuccess = false
    @State private var showDeleteError = false
    @State private var isDeleting = false
    @State private var editingHerName = false
    @State private var editingHisName = false
    @State private var herNameDraft = ""
    @State private var hisNameDraft = ""
    @State private var isSyncingCalendar = false
    @State private var showCalendarRemoveConfirm = false
    @State private var calendarErrorMessage: String?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Layout.sectionSpacing) {
                    // 1. NOTIFICATIONS — always visible
                    settingsSection(header: "NOTIFICATIONS") {
                        notificationsRow
                    }

                    // 2. CALENDAR — always visible
                    settingsSection(header: "CALENDAR") {
                        calendarSyncRow
                    }

                    // 3. CHANGE YOUR SETUP — collapsed by default. Pushed
                    //    below the always-on rows so the top of the page
                    //    is "what's happening right now" (push state +
                    //    calendar sync); identity + mode editing is one
                    //    extra tap away.
                    CollapsibleSection(title: "Change your setup") {
                        VStack(spacing: Layout.cardSpacing) {
                            yourNameRow
                            hisNameRow
                            // V2.0: country is the PRIMARY entity (WC) and
                            // sits above PL club (optional secondary). Order
                            // mirrors the onboarding flow.
                            hisCountryRow
                            hisTeamRow
                            yourModeRow
                        }
                    }

                    // 4. ABOUT — collapsed by default. Absorbs the footer
                    //    links (Contact / Privacy / Delete My Data /
                    //    Version) so the entire app metadata lives in
                    //    one expand-on-tap section instead of trailing
                    //    rows that pad the page.
                    CollapsibleSection(title: "About") {
                        VStack(spacing: Layout.cardSpacing) {
                            aboutBlurbCard
                            contactRow
                            privacyRow
                            deleteRow
                            versionLabel
                        }
                    }
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
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet()
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
        .alert("Edit \(appState.pPossessiveCap) Name", isPresented: $editingHisName) {
            TextField("\(appState.pPossessiveCap) name", text: $hisNameDraft)
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
        .alert("Remove fixtures from your calendar?", isPresented: $showCalendarRemoveConfirm) {
            Button("Remove", role: .destructive) {
                Task { await removeCalendarSync() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the GoalDigger calendar and all its events. You can turn this back on anytime.")
        }
        .alert("Calendar sync", isPresented: Binding(
            get: { calendarErrorMessage != nil },
            set: { if !$0 { calendarErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarErrorMessage ?? "")
        }
    }

    // MARK: - Row components
    //
    // The Immersive/Classic toggle that used to live here was removed in
    // May 2026. Everyone runs the Immersive layout now (AppState.feedStyle
    // defaults to .immersive). FeedView still reads the flag but no UI
    // exposes it.

    @ViewBuilder private var yourNameRow: some View {
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
    }

    @ViewBuilder private var hisNameRow: some View {
        settingsRow {
            Button {
                hisNameDraft = appState.hisName
                editingHisName = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(appState.pPossessiveCap) Name")
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
    }

    @ViewBuilder private var hisTeamRow: some View {
        settingsRow {
            Button { showTeamPicker = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(appState.namePossessiveCap) Team")
                            .font(.feedTimestamp)
                            .foregroundColor(.textSecondaryOnCard)
                        Text(appState.selectedTeams.isEmpty
                            ? "None"
                            : appState.selectedTeams.map(\.displayName).joined(separator: ", "))
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

    @ViewBuilder private var hisCountryRow: some View {
        settingsRow {
            Button { showCountryPicker = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(appState.namePossessiveCap) Country")
                            .font(.feedTimestamp)
                            .foregroundColor(.textSecondaryOnCard)
                        Text(appState.selectedCountries.isEmpty
                            ? "None — tap to choose"
                            : appState.selectedCountries.map(\.displayName).joined(separator: ", "))
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

    @ViewBuilder private var yourModeRow: some View {
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

    @ViewBuilder private var notificationsRow: some View {
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

    @ViewBuilder private var calendarSyncRow: some View {
        settingsRow {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add \(appState.pPossessive) fixtures to your calendar")
                        .font(.feedTimestamp)
                        .foregroundColor(.textSecondaryOnCard)
                    Text(appState.calendarSyncEnabled ? "On" : "Off")
                        .font(.feedHeadline)
                        .foregroundColor(.textPrimaryOnCard)
                    // Explicit re-add for when the events were removed outside
                    // the app (the toggle stays On, so there's otherwise no way
                    // to put them back). Forces a fresh full re-sync.
                    if appState.calendarSyncEnabled && !isSyncingCalendar {
                        Button("Re-add fixtures") { Task { await enableCalendarSync() } }
                            .font(.feedTimestamp)
                            .foregroundColor(.hotRose)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                if isSyncingCalendar {
                    ProgressView().tint(.hotRose)
                } else {
                    Toggle("", isOn: Binding(
                        get: { appState.calendarSyncEnabled },
                        set: { newValue in
                            if newValue {
                                Task { await enableCalendarSync() }
                            } else {
                                showCalendarRemoveConfirm = true
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(.hotRose)
                }
            }
        }
    }

    @ViewBuilder private var aboutBlurbCard: some View {
        settingsRow {
            VStack(alignment: .leading, spacing: 8) {
                Text("GoalDigger")
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimaryOnCard)
                Text("For the girlfriend who's done nodding along. Made for her, not \(appState.pObject).")
                    .font(.feedTimestamp)
                    .foregroundColor(.textSecondaryOnCard)
            }
        }
    }

    @ViewBuilder private var contactRow: some View {
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
    }

    @ViewBuilder private var privacyRow: some View {
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
    }

    @ViewBuilder private var deleteRow: some View {
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

    @ViewBuilder private var versionLabel: some View {
        Text("Version 1.0.0")
            .font(.jakarta(11, weight: .regular))
            .foregroundColor(.textTertiary.opacity(0.6))
            .padding(.top, 8)
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
        case 3: return "The one \(appState.pSubject) \(appState.usesHeVoice ? "brags" : "brag") about"
        default: return "Came to impress"
        }
    }

    // MARK: - Calendar sync

    /// Toggle-on handler: request permission, fetch the next fixture, push to
    /// the system calendar. Reverts the toggle if anything fails.
    @MainActor
    private func enableCalendarSync() async {
        isSyncingCalendar = true
        defer { isSyncingCalendar = false }

        do {
            let granted = try await CalendarSyncService.shared.requestAccess()
            guard granted else {
                calendarErrorMessage = "Calendar access was denied. You can enable it in iOS Settings."
                return
            }
            // Sync BOTH followed entities (his WC country AND his PL club).
            // resync pulls each one's full upcoming slate, wipes stale/finished
            // games, and removes calendars for entities no longer followed.
            try await CalendarSyncService.shared.resync(
                teams: appState.selectedTeams,
                countries: appState.selectedCountries
            )
            appState.calendarSyncEnabled = true
        } catch {
            calendarErrorMessage = "Something went wrong adding the events. Try again in a sec."
            appState.calendarSyncEnabled = false
        }
    }

    /// Toggle-off handler invoked after the user confirms in the alert.
    @MainActor
    private func removeCalendarSync() async {
        isSyncingCalendar = true
        defer { isSyncingCalendar = false }
        do {
            try CalendarSyncService.shared.removeAllGoalDiggerCalendars()
        } catch {
            // Best-effort: even if remove fails, treat the toggle as off so
            // the UI does not lie.
        }
        appState.calendarSyncEnabled = false
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
    /// Local working set so Cancel discards; applied to AppState on Done.
    @State private var picks: [Team] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Layout.cardSpacing) {
                        Text("Follow up to 2 clubs.")
                            .font(.feedTimestamp)
                            .foregroundColor(.textSecondaryOnCard)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        ForEach(Team.allCases.sorted { $0.displayName < $1.displayName }) { team in
                            let isSelected = picks.contains(team)
                            let atCap = picks.count >= 2
                            TeamPickerCard(team: team, isSelected: isSelected) {
                                toggle(team, isSelected: isSelected, atCap: atCap)
                            }
                            .opacity(!isSelected && atCap ? 0.4 : 1)
                        }
                    }
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Your Clubs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.hotRose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { apply() }
                        .foregroundColor(.hotRose)
                }
            }
            .onAppear { picks = appState.selectedTeams }
        }
    }

    private func toggle(_ team: Team, isSelected: Bool, atCap: Bool) {
        if isSelected {
            picks.removeAll { $0 == team }
        } else if !atCap {
            picks.append(team)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func apply() {
        appState.selectedTeams = picks
        CacheService.shared.clearAll(in: modelContext)
        // Keep the active feed context valid if its club was removed.
        if case .team(let t) = appState.activeContext, !picks.contains(t) {
            appState.activeContext = appState.selectedCountries.first.map { FeedContext.country($0) }
                ?? picks.first.map { FeedContext.team($0) }
                ?? .everyoneTalking
        }
        appState.isContextSwitcherOpen = false
        NotificationService.shared.reregisterForFollowChange()
        dismiss()
    }
}

// MARK: - Country Picker Sheet
//
// V2.0: parallel to TeamPickerSheet but for the WC country. Reuses
// `CountrySelectionView` (the same grid used in onboarding +
// WCMigrationSheetView) so the picker UX stays consistent. The
// onContinue closure handles cache clear + active-context switch +
// device_token PATCH + dismiss.
struct CountryPickerSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                // CountrySelectionView writes the picked country to
                // appState.selectedCountry directly inside its Continue
                // button. By the time this closure fires, the new
                // country is already set — we just propagate the change
                // to active context + cache + the device_tokens row.
                CountrySelectionView(allowsSecond: true) {
                    guard let country = appState.selectedCountry else {
                        dismiss()
                        return
                    }
                    CacheService.shared.clearAll(in: modelContext)
                    appState.activeContext = .country(country)
                    appState.isContextSwitcherOpen = false
                    // Full re-register (UPSERT with the new country/team/tier) so the
                    // backend device_tokens row reflects the switch immediately.
                    // updateTokenCountry only PATCHed an existing row, which left a
                    // stale country when the row was keyed on an older APNs token.
                    NotificationService.shared.reregisterForFollowChange()
                    dismiss()
                }
            }
            .navigationTitle("Change Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.hotRose)
                }
            }
        }
    }
}

// MARK: - Tier Picker Sheet

struct TierPickerSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var selected: Int = 2

    private var tiers: [(number: Int, label: String, description: String)] {
        [
        (1, "Just enough to get by", "Just the essentials. No overload."),
        (2, "Came to impress", "Enough to hold your own in any conversation."),
        (3, "The one \(appState.pSubject) \(appState.usesHeVoice ? "brags" : "brag") about",
         "She knows things \(appState.pSubject) \(appState.usesHeVoice ? "hasn't" : "haven't") even googled yet.")
        ]
    }

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
