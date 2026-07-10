import SwiftUI

/// Hero "next match" card for the World Championship tournament feed.
/// Rendered from a `ContentItem` when it's a pre-tournament / in-tournament
/// preview (`previewFixtureId != nil`) whose kickoff hasn't happened yet
/// (V2.0, Lesson 78). Shows the two country crests, a live countdown, and
/// the preview headline; tapping through opens the full match brief via
/// `onTap`. Falls back to a headline-only layout if `affectedTeamIds`
/// doesn't resolve to exactly two known countries.
struct WCNextMatchCard: View {
    let item: ContentItem
    let onTap: () -> Void

    /// Resolved crest countries. Nil (and the card drops the crest row)
    /// unless `affectedTeamIds` has exactly two entries that both map to
    /// a known `Country` case.
    private var countries: (home: Country, away: Country)? {
        guard let ids = item.affectedTeamIds, ids.count == 2,
              let home = Country(rawValue: ids[0]), let away = Country(rawValue: ids[1]) else {
            return nil
        }
        return (home, away)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let countries {
                    matchupRow(countries)
                }
                if let kickoffTime = item.kickoffTime {
                    TeamPageCountdown(targetDate: ISO8601DateFormatter().string(from: kickoffTime))
                }
                Text(item.headline)
                    .font(.jakarta(17, weight: .semiBold))
                    .foregroundColor(.warmWhite)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let hook = item.regularTalkingPoints.first, !hook.isEmpty {
                    talkingPointHook(hook)
                }
                readMoreRow
            }
            .padding(Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.deepMauve)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .stroke(Color.hotRose.opacity(0.4), lineWidth: 1.5)
            )
            .cornerRadius(Layout.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next match: \(item.headline). Tap to read the full match brief.")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("NEXT MATCH")
                .font(.jakarta(11, weight: .bold))
                .tracking(1.5)
                .foregroundColor(.hotRose)
            Text("·")
                .font(.jakarta(11, weight: .bold))
                .foregroundColor(.warmWhite.opacity(0.4))
            Text("WORLD CHAMPIONSHIP")
                .font(.jakarta(11, weight: .semiBold))
                .tracking(1)
                .foregroundColor(.warmWhite.opacity(0.6))
            Spacer()
        }
    }

    private func matchupRow(_ countries: (home: Country, away: Country)) -> some View {
        HStack(spacing: 24) {
            crestColumn(countries.home)
            Text("vs")
                .font(.jakarta(13, weight: .semiBold))
                .foregroundColor(.warmWhite.opacity(0.5))
            crestColumn(countries.away)
            Spacer()
        }
    }

    private func crestColumn(_ country: Country) -> some View {
        VStack(spacing: 6) {
            TeamCrestView(country: country, size: 44)
            Text(country.shortName)
                .font(.jakarta(12, weight: .semiBold))
                .foregroundColor(.warmWhite)
                .lineLimit(1)
        }
    }

    /// A conversational hook (the first talking point) so the pre-match card
    /// carries a talking point like every other feed card, not just a headline.
    private func talkingPointHook(_ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.hotRose)
                .frame(width: 3)
            Text(text)
                .font(.jakarta(14, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var readMoreRow: some View {
        HStack(spacing: 4) {
            Text("Read the full match brief")
                .font(.jakarta(13, weight: .medium))
                .foregroundColor(.hotRose)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.hotRose)
        }
        .padding(.top, 2)
    }
}

// MARK: - Preview

#Preview {
    let json = """
    {
        "id": "b2c3d4e5-f6a7-8901-bcde-000000000010",
        "team_id": "england",
        "type": "news",
        "headline": "England face France in a group decider that could settle top spot before the knockouts even start.",
        "body": "Preview body.",
        "talking_points": ["Group decider tonight."],
        "kickoff_time": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 30)))",
        "emotional_context": "exciting",
        "published_at": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800)))",
        "affected_team_ids": ["england", "france"],
        "preview_fixture_id": "england:2026-07-15:france"
    }
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let item = try! decoder.decode(ContentItem.self, from: json)

    return WCNextMatchCard(item: item, onTap: {})
        .padding()
        .background(Color.deepMauve)
}
