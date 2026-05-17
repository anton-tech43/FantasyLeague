import SwiftUI

/// Renders a team's crest (or country's flag) from API-Football's CDN with
/// a graceful fallback. Both clubs and countries use the same CDN shape
/// (`media.api-sports.io/football/teams/{id}.png`) so this single component
/// handles both via two convenience initialisers.
///
/// While loading or on failure, falls back to a soft-blush circle with a
/// shield SF Symbol so the layout doesn't pop.
///
/// Usage:
/// ```swift
/// TeamCrestView(team: .arsenal, size: 32)        // PL club
/// TeamCrestView(country: .england, size: 32)     // WC national team
/// TeamCrestView(url: someURL, size: 32)          // any URL
/// ```
struct TeamCrestView: View {
    let url: URL?
    let size: CGFloat

    init(team: Team, size: CGFloat = 32) {
        self.url = team.crestURL
        self.size = size
    }

    init(country: Country, size: CGFloat = 32) {
        self.url = country.crestURL
        self.size = size
    }

    init(url: URL?, size: CGFloat = 32) {
        self.url = url
        self.size = size
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            default:
                fallback
            }
        }
        .frame(width: size, height: size)
    }

    private var fallback: some View {
        ZStack {
            Circle()
                .fill(Color.mutedText.opacity(0.1))
            Image(systemName: "shield.fill")
                .font(.system(size: size * 0.5))
                .foregroundColor(.mutedText.opacity(0.5))
        }
    }
}
