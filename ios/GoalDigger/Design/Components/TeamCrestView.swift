import SwiftUI
import UIKit

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

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        // Decorative: every caller prints the name beside it, and VoiceOver
        // read the fallback as "shield". A caller where the crest is the only
        // label must give its container an accessibilityLabel.
        .accessibilityHidden(true)
        .task(id: url) { image = await CrestLoader.image(for: url) }
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

/// Crest images, kept once loaded. This used to be a bare AsyncImage: loading
/// and failure looked the same, a failure never retried, and every rebuild of
/// the view (the team page rebuilds several times while it loads) could drop
/// an image mid-flight — so Arsenal's crest sat as a grey shield on Arsenal's
/// own page while the feed showed it fine (Anton, 2026-10-27).
@MainActor
enum CrestLoader {
    private static var cache: [URL: UIImage] = [:]

    static func image(for url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if let hit = cache[url] { return hit }
        for attempt in 0..<3 {
            if attempt > 0 { try? await Task.sleep(for: .seconds(Double(attempt))) }
            if Task.isCancelled { return nil }
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let img = UIImage(data: data) {
                cache[url] = img
                return img
            }
        }
        return nil
    }
}
