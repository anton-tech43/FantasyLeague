import SwiftUI

/// Info-card screen #2 — "Meet the boss". Renders the manager card from
/// the team page (name + one-sentence summary written in GoalDigger voice).
///
/// Skipped silently when no manager card is available — the parent
/// OnboardingFlow auto-advances if `content?.cards.manager` is nil.
struct MeetManagerView: View {
    @Environment(AppState.self) var appState
    /// The team_id (string) to load the team page for. Can be a PL club ID
    /// or a WC country ID. Same `team_pages` table, same fetch.
    let entityId: String
    let onContinue: () -> Void

    @State private var content: TeamPageContent?
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                        .padding(.top, 24)

                    if isLoading {
                        loadingSkeleton
                    } else if let manager = content?.cards.manager {
                        managerCard(manager: manager)
                    } else {
                        // No manager card — render a soft fallback so the
                        // screen isn't blank. Parent flow could also choose
                        // to skip this step; for now we just show a one-line
                        // shrug rather than fail.
                        Text("No manager data yet. Check back later.")
                            .font(.onboardingBody)
                            .foregroundColor(.textOnDark.opacity(0.7))
                    }
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.bottom, 24)
            }

            Button("Got it") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onContinue()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 40)
        }
        .task { await loadTeamPage() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                entityCrest
                Text("Meet the boss.")
                    .font(.onboardingTitle)
                    .foregroundColor(.textOnDark)
            }
            Text(appState.personalise("The person [his name] either loves or wants fired this week. Depends on the last result."))
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.8))
        }
    }

    /// Crest from whichever entity the entityId matches.
    @ViewBuilder
    private var entityCrest: some View {
        if let team = Team(rawValue: entityId) {
            TeamCrestView(team: team, size: 44)
        } else if let country = Country(rawValue: entityId) {
            TeamCrestView(country: country, size: 44)
        } else {
            TeamCrestView(url: nil, size: 44)
        }
    }

    @ViewBuilder
    private func managerCard(manager: ManagerCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                managerAvatar(manager: manager)
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())

                Text(manager.name)
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimaryOnCard)
                Spacer(minLength: 0)
            }

            Text(appState.personalise(manager.summary))
                .font(.onboardingBody)
                .foregroundColor(.textPrimaryOnCard)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func managerAvatar(manager: ManagerCard) -> some View {
        ZStack {
            Circle()
                .fill(Color.hotRose.opacity(0.15))
            if let urlString = manager.photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        managerFallbackIcon
                    }
                }
            } else {
                managerFallbackIcon
            }
        }
    }

    private var managerFallbackIcon: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 28))
            .foregroundColor(.hotRose)
    }

    private var loadingSkeleton: some View {
        RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
            .fill(Color.cardBackground.opacity(0.3))
            .frame(height: 140)
            .redacted(reason: .placeholder)
    }

    // MARK: - Loading

    @MainActor
    private func loadTeamPage() async {
        // V2.0: load via the entityId passed in by the caller.
        let teamId = entityId
        if let cached = TeamPageCache.load(teamId: teamId)?.content {
            content = cached
            isLoading = false
        }
        do {
            if let fresh = try await APIClient.shared.fetchTeamPage(teamId: teamId) {
                content = fresh
                TeamPageCache.save(content: fresh, teamId: teamId)
            }
        } catch {
            #if DEBUG
            print("⚠️ MeetManagerView fetch failed: \(error)")
            #endif
        }
        isLoading = false
    }
}
