import SwiftUI

/// Onboarding step 6 — shown right after the user grants notifications.
/// First time she sees something ABOUT his team, not something asked OF her.
///
/// Three quiet rows on one screen:
///   - Star player (top_players[0]) — photo (or initials), name, position,
///     one-line personality.
///   - Last result framed as mood — "They won. {hisName} was happy." —
///     omitted if no recent result.
///   - Table verdict in plain English — "Top of the league chase." /
///     "Mid-table, quietly fine." / "In a relegation fight." — omitted if
///     league position unavailable.
///
/// Data source: `APIClient.fetchTeamPage` (same fetch the Team tab uses).
/// Result is saved to `TeamPageCache` so the TeamPage tab opens instantly
/// later. On fetch failure, missing photo, or missing fields, the row
/// silently drops — never a broken state, never blocks onboarding.
struct MeetTeamView: View {
    @Environment(AppState.self) var appState
    /// The team_id (string) to load the team page for. Can be a PL club ID
    /// (`"arsenal"`) or a WC country ID (`"england"`) — both live in the
    /// same `team_pages` table and decode through the same TeamPageContent
    /// model. Caller (OnboardingFlow) decides which to pass based on what
    /// the user picked.
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
                    } else {
                        if let player = content?.cards.onesToKnow?.players.first {
                            playerCard(player: player)
                        }
                        if let middleLine = middleRowLine {
                            resultRow(text: middleLine)
                        }
                        if let verdict = tableVerdict {
                            verdictRow(text: verdict)
                        }
                    }
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.bottom, 24)
            }

            // V2.0: matches the actual next-screen (MeetManagerView) rather
            // than the old misleading "Show me how this works" copy.
            Button("Meet the boss") {
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
                Text("Meet \(appState.pPossessive) lot.")
                    .font(.onboardingTitle)
                    .foregroundColor(.textOnDark)
            }
            Text(appState.personalise(headerSubtitle))
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.8))
        }
    }

    /// Crest rendered from whichever entity the entityId matches. Falls
    /// back to the generic shield icon (via TeamCrestView's url initialiser
    /// with nil URL) when the ID doesn't match a known Team or Country.
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

    private var entityShortName: String? {
        if let team = Team(rawValue: entityId) { return team.shortName }
        if let country = Country(rawValue: entityId) { return country.shortName }
        return nil
    }

    private var headerSubtitle: String {
        if let name = entityShortName {
            return "Three things about \(name), so you've got something for the next time [his name] starts talking about them."
        }
        return "A few quick things about \(appState.pPossessive) team, so you've got something for the next time \(appState.pSubject) \(appState.usesHeVoice ? "starts" : "start") talking about them."
    }

    @ViewBuilder
    private func playerCard(player: TopPlayer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                playerAvatar(player: player)
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name)
                        .font(.feedHeadline)
                        .foregroundColor(.textPrimaryOnCard)
                    Text(player.position)
                        .font(.jakarta(13, weight: .regular))
                        .foregroundColor(.textSecondaryOnCard)
                }
                Spacer(minLength: 0)
            }

            if let oneLiner = player.oneLiner {
                Text(appState.personalise(oneLiner))
                    .font(.onboardingBody)
                    .foregroundColor(.textPrimaryOnCard)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func playerAvatar(player: TopPlayer) -> some View {
        let size: CGFloat = 72
        ZStack {
            Circle()
                .fill(Color.hotRose.opacity(0.15))
            if let urlString = player.photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        initialsLabel(for: player.name)
                    }
                }
            } else {
                initialsLabel(for: player.name)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func initialsLabel(for name: String) -> some View {
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
        return Text(initials)
            .font(.jakarta(22, weight: .bold))
            .foregroundColor(.hotRose)
    }

    @ViewBuilder
    private func resultRow(text: String) -> some View {
        infoRow(systemImage: "soccerball", tint: .hotRose, text: text)
    }

    @ViewBuilder
    private func verdictRow(text: String) -> some View {
        infoRow(systemImage: "chart.bar.fill", tint: .hotRose, text: text)
    }

    @ViewBuilder
    private func infoRow(systemImage: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundColor(tint)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)
            Text(text)
                .font(.onboardingBody)
                .foregroundColor(.textPrimaryOnCard)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var loadingSkeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .fill(Color.cardBackground.opacity(0.3))
                    .frame(height: 96)
            }
        }
        .redacted(reason: .placeholder)
    }

    // MARK: - Derived copy

    /// Map `post_match.state` to a one-line mood sentence. Returns nil when
    /// there's no post-match card OR it's expired so the row is dropped.
    /// Uses `[his name]` placeholders so empty names fall back to
    /// "your partner" via AppState.personalise (see AppState.swift:100).
    /// Middle row — prefers a fresh post-match mood line ("they won, he was
    /// happy"), but falls back to the routine-written `form_summary` when no
    /// recent match exists. Ensures the screen always shows 3 rows so the
    /// header "Three things about Arsenal" doesn't become a lie.
    private var middleRowLine: String? {
        if let post = content?.cards.postMatch,
           let expiresAt = Self.parseISO(post.expiresAt),
           expiresAt >= Date() {
            switch post.state {
            case .win:  return appState.personalise("They won their last match. [His name] was happy.")
            case .loss: return "They lost. Don't bring it up tomorrow."
            case .draw: return appState.personalise("They drew. [His name's] feelings are complicated.")
            }
        }
        // Fallback: form_summary is a personalised 1-sentence "they're on a
        // good run / wobbling lately" line written by the team-page-generator
        // routine, present whenever the form card exists.
        if let summary = content?.cards.form?.formSummary, !summary.isEmpty {
            return appState.personalise(summary)
        }
        return nil
    }

    /// Map `form.league_position` to a plain-English verdict. Returns nil
    /// when the form card or league position is missing.
    private var tableVerdict: String? {
        guard let position = content?.cards.form?.leaguePosition else { return nil }
        switch position {
        case 1...4:   return "Top of the league chase."
        case 5...8:   return "Pushing for Europe."
        case 9...14:  return "Mid-table, quietly fine."
        case 15...20: return appState.personalise("In a relegation fight. [His name] is stressed.")
        default:      return nil
        }
    }

    // MARK: - Loading

    @MainActor
    private func loadTeamPage() async {
        // V2.0: load via the entityId passed in by the caller — could be a
        // PL team ID or a WC country ID. Same `team_pages` table either way.
        let teamId = entityId
        // Prefer disk cache for instant render; refresh in the background.
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
            print("⚠️ MeetTeamView fetch failed: \(error)")
            #endif
        }
        isLoading = false
    }

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlainFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseISO(_ s: String) -> Date? {
        isoFractionalFormatter.date(from: s) ?? isoPlainFormatter.date(from: s)
    }
}
