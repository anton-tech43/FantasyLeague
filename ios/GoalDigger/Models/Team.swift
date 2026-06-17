import Foundation

// 2026-27 Premier League roster (the 20 current top-flight clubs).
// Promoted in for 2026-27: Coventry, Hull, Ipswich. Relegated out: West Ham,
// Burnley, Wolves — removed from the picker. The Supabase `teams` table keeps
// rows for relegated clubs (is_active=false, mig 074) so historical content
// decodes at the DB level; iOS just doesn't expose them as selectable.
// Long-term: fetch this list from the Supabase `teams` table at runtime so
// season rollovers don't require an app release.
enum Team: String, CaseIterable, Identifiable, Codable {
    case arsenal = "arsenal"
    case astonVilla = "aston_villa"
    case bournemouth = "bournemouth"
    case brentford = "brentford"
    case brighton = "brighton"
    case chelsea = "chelsea"
    case coventry = "coventry"
    case crystalPalace = "crystal_palace"
    case everton = "everton"
    case fulham = "fulham"
    case hull = "hull"
    case ipswich = "ipswich"
    case leeds = "leeds"
    case liverpool = "liverpool"
    case manCity = "man_city"
    case manUtd = "man_utd"
    case newcastle = "newcastle"
    case nottmForest = "nottm_forest"
    case spurs = "spurs"
    case sunderland = "sunderland"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arsenal: return "Arsenal"
        case .astonVilla: return "Aston Villa"
        case .bournemouth: return "AFC Bournemouth"
        case .brentford: return "Brentford"
        case .brighton: return "Brighton & Hove Albion"
        case .chelsea: return "Chelsea"
        case .coventry: return "Coventry City"
        case .crystalPalace: return "Crystal Palace"
        case .everton: return "Everton"
        case .fulham: return "Fulham"
        case .hull: return "Hull City"
        case .ipswich: return "Ipswich Town"
        case .leeds: return "Leeds United"
        case .liverpool: return "Liverpool"
        case .manCity: return "Manchester City"
        case .manUtd: return "Manchester United"
        case .newcastle: return "Newcastle United"
        case .nottmForest: return "Nottingham Forest"
        case .spurs: return "Tottenham Hotspur"
        case .sunderland: return "Sunderland"
        }
    }

    var shortName: String {
        switch self {
        case .arsenal: return "Arsenal"
        case .astonVilla: return "Aston Villa"
        case .bournemouth: return "Bournemouth"
        case .brentford: return "Brentford"
        case .brighton: return "Brighton"
        case .chelsea: return "Chelsea"
        case .coventry: return "Coventry"
        case .crystalPalace: return "Crystal Palace"
        case .everton: return "Everton"
        case .fulham: return "Fulham"
        case .hull: return "Hull"
        case .ipswich: return "Ipswich"
        case .leeds: return "Leeds"
        case .liverpool: return "Liverpool"
        case .manCity: return "Man City"
        case .manUtd: return "Man Utd"
        case .newcastle: return "Newcastle"
        case .nottmForest: return "Nott'm Forest"
        case .spurs: return "Spurs"
        case .sunderland: return "Sunderland"
        }
    }

    var badgeImageName: String {
        rawValue + "_badge"
    }

    /// API-Football team ID, used to fetch the team crest from the
    /// `media.api-sports.io/football/teams/{id}.png` CDN. Values match the
    /// `teams.api_football_id` column in Supabase (single source of truth);
    /// if these ever drift, regen the mapping from
    /// `SELECT id, api_football_id FROM teams;`.
    var apiFootballId: Int {
        switch self {
        case .arsenal:      return 42
        case .astonVilla:   return 66
        case .bournemouth:  return 35
        case .brentford:    return 55
        case .brighton:     return 51
        case .chelsea:      return 49
        case .coventry:     return 1346
        case .crystalPalace:return 52
        case .everton:      return 45
        case .fulham:       return 36
        case .hull:         return 64
        case .ipswich:      return 57
        case .leeds:        return 63
        case .liverpool:    return 40
        case .manCity:      return 50
        case .manUtd:       return 33
        case .newcastle:    return 34
        case .nottmForest:  return 65
        case .spurs:        return 47
        case .sunderland:   return 746
        }
    }

    /// CDN URL for the team's crest (PNG, transparent background, ~150x150).
    var crestURL: URL? {
        URL(string: "https://media.api-sports.io/football/teams/\(apiFootballId).png")
    }

    var searchableText: String {
        let nicknames: String
        switch self {
        case .arsenal: nicknames = "Gunners"
        case .astonVilla: nicknames = "Villans"
        case .bournemouth: nicknames = "Cherries"
        case .brentford: nicknames = "Bees"
        case .brighton: nicknames = "Seagulls"
        case .chelsea: nicknames = "Blues"
        case .coventry: nicknames = "Sky Blues"
        case .crystalPalace: nicknames = "Eagles"
        case .everton: nicknames = "Toffees"
        case .fulham: nicknames = "Cottagers"
        case .hull: nicknames = "Tigers"
        case .ipswich: nicknames = "Tractor Boys"
        case .leeds: nicknames = "Whites Peacocks"
        case .liverpool: nicknames = "Reds"
        case .manCity: nicknames = "Citizens"
        case .manUtd: nicknames = "Red Devils"
        case .newcastle: nicknames = "Magpies Toon"
        case .nottmForest: nicknames = "Tricky Trees"
        case .spurs: nicknames = "Lilywhites"
        case .sunderland: nicknames = "Black Cats"
        }
        return "\(displayName) \(shortName) \(nicknames)".lowercased()
    }
}
