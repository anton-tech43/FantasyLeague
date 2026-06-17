import SwiftUI

/// Onboarding step 9 — final value-card before the Season Primer. Asks if
/// she wants his team's upcoming fixtures dropped into her iOS calendar.
///
/// The CalendarSyncService stack already exists (built for the Settings
/// toggle). This view is the first surface that exposes it during
/// onboarding. Permission strings live in Info.plist
/// (`NSCalendarsFullAccessUsageDescription`); no plist work required.
///
/// Data flow: tries three sources in order so we always have SOMETHING to
/// sync if any are populated:
///   1. `team_season_state.next_fixtures` (array — V1.2 migration 031,
///      written by the gd-season-state routine)
///   2. `team_season_state.next_fixture`  (singular — pre-V1.2 column)
///   3. `team_pages.cards.next_fixture`   (singular, ISO string — the
///      source SettingsView already uses today; populated for every team
///      that has a team_page row, which is "all 20 PL clubs")
///
/// On "Yes, add them": requests calendar permission, then syncs. On "Not
/// now": sets `calendarSyncEnabled = false` and advances. Either way the
/// user proceeds; we never block.
struct CalendarOptInView: View {
    @Environment(AppState.self) var appState
    let onComplete: () -> Void

    @State private var fixtures: [TeamSeasonState.NextFixture] = []
    @State private var isLoadingFixtures: Bool = true
    @State private var isSyncing: Bool = false
    @State private var syncErrorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.hotRose.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "calendar")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.hotRose)
            }
            .padding(.bottom, 8)

            Text("Want \(appState.pPossessive) matches\nin your calendar?")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            Text(bodyText)
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            if let syncErrorMessage {
                Text(syncErrorMessage)
                    .font(.jakarta(13, weight: .regular))
                    .foregroundColor(.hotRose)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Layout.screenPadding)
            }

            Spacer()

            VStack(spacing: 12) {
                if fixtures.isEmpty && !isLoadingFixtures {
                    // No fixtures known (pre-season / off-season / brand-new
                    // team). Asking for calendar permission and then syncing
                    // nothing would be confusing — she grants access, opens
                    // Calendar, sees no events. Skip the permission ask
                    // entirely; surface the toggle in Settings for later.
                    Button("Got it") {
                        appState.calendarSyncEnabled = false
                        onComplete()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button {
                        Task { await enableAndSync() }
                    } label: {
                        if isSyncing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Yes, add them")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSyncing)

                    Button("Not now") {
                        appState.calendarSyncEnabled = false
                        onComplete()
                    }
                    .font(.onboardingBody)
                    .foregroundColor(.textOnDark.opacity(0.6))
                    .disabled(isSyncing)
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 40)
        }
        .task { await loadFixtures() }
    }

    // MARK: - Derived copy

    private var bodyText: String {
        let count = fixtures.count
        if isLoadingFixtures {
            return "We'll add \(appState.pPossessive) upcoming matches so you know when \(appState.pWill) be glued to the TV."
        }
        if count == 0 {
            return "No matches scheduled yet. We'll add them automatically once the fixture list drops, just flip the calendar switch in Settings when you're ready."
        }
        if count == 1 {
            return "We'll add \(appState.pPossessive) next match so you know when \(appState.pWill) be glued to the TV."
        }
        return "We'll add \(appState.pPossessive) next \(count) matches so you know when \(appState.pWill) be glued to the TV."
    }

    // MARK: - Loading

    @MainActor
    private func loadFixtures() async {
        guard let teamId = appState.selectedTeam?.rawValue else {
            isLoadingFixtures = false
            return
        }
        // Try season-state first (richer — up to 10 fixtures once migration
        // 031 is live and routine has run). If that yields nothing, fall
        // back to the team page's singular next_fixture — the source
        // SettingsView uses today and which is reliably populated for all
        // 20 PL clubs.
        do {
            if let state = try await APIClient.shared.fetchTeamSeasonState(teamId: teamId) {
                fixtures = state.fixturesForSync
            }
        } catch {
            #if DEBUG
            print("⚠️ CalendarOptIn season-state fetch failed: \(error)")
            #endif
        }

        if fixtures.isEmpty {
            // Fall back to team_pages.cards.next_fixture (uses ISO string,
            // shape differs from TeamSeasonState.NextFixture — parse here).
            if let page = (try? await APIClient.shared.fetchTeamPage(teamId: teamId)),
               let raw = page.cards.nextFixture,
               let kickoff = Self.fixtureDateFormatter.date(from: raw.date) {
                fixtures = [
                    TeamSeasonState.NextFixture(
                        opponent: raw.opponent,
                        kickoffTime: kickoff,
                        venue: raw.venue.capitalized
                    )
                ]
            }
        }

        isLoadingFixtures = false
    }

    private static let fixtureDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Permission + sync

    @MainActor
    private func enableAndSync() async {
        isSyncing = true
        syncErrorMessage = nil
        defer { isSyncing = false }

        do {
            let granted = try await CalendarSyncService.shared.requestAccess()
            guard granted else {
                syncErrorMessage = "Calendar access was denied. You can enable it later in Settings."
                appState.calendarSyncEnabled = false
                // Brief pause so she sees the message, then advance.
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onComplete()
                return
            }

            // Sync BOTH followed entities (his WC country AND his PL club).
            // resync fetches each one's upcoming slate itself, so a missing
            // local `fixtures` preview (e.g. country picked but club fixtures
            // not loaded) no longer means his games get skipped.
            try await CalendarSyncService.shared.resync(
                teams: appState.selectedTeams,
                countries: appState.selectedCountries
            )
            appState.calendarSyncEnabled = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onComplete()
        } catch {
            syncErrorMessage = "Something went wrong adding the events. You can try again from Settings later."
            appState.calendarSyncEnabled = false
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            onComplete()
        }
    }
}
