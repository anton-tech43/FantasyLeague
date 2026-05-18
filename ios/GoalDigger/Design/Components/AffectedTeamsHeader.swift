import SwiftUI

/// Renders 1-2 team crests above the headline on ContentDetailView. Tells
/// the user at a glance which teams are involved in this news item.
///
/// Rules:
/// - 1 valid team id  → 1 crest, left-aligned
/// - 2 valid team ids → 2 crests, side-by-side with 8pt gap
/// - 3+ valid ids OR empty/nil → renders nothing (matchday-wide stories,
///   "everyone's talking" cross-team items get no crest header)
/// - Unresolvable ids (typos, retired clubs) are filtered out before
///   counting — so an array of ["arsenal", "<bogus>"] renders just the
///   Arsenal crest.
struct AffectedTeamsHeader: View {
    let teamIds: [String]?

    var body: some View {
        let resolved = (teamIds ?? []).compactMap(resolve)
        if resolved.count == 1 || resolved.count == 2 {
            HStack(spacing: 8) {
                ForEach(resolved, id: \.self) { crest in
                    crestView(for: crest)
                }
            }
            .padding(.bottom, 12)
        }
    }

    /// Resolves a teamId string to a stable token (the same string) iff
    /// it matches either a PL Team enum or a WC Country enum. Returns nil
    /// for unknown ids — they're filtered out before render.
    private func resolve(_ id: String) -> String? {
        if Team(rawValue: id) != nil { return id }
        if Country(rawValue: id) != nil { return id }
        return nil
    }

    @ViewBuilder
    private func crestView(for id: String) -> some View {
        if let team = Team(rawValue: id) {
            TeamCrestView(team: team, size: 32)
        } else if let country = Country(rawValue: id) {
            TeamCrestView(country: country, size: 32)
        } else {
            EmptyView()
        }
    }
}
