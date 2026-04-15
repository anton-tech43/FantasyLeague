import Foundation

// TODO: This team list needs updating before PL 2026/27 launch — Ipswich, Leicester, Southampton
// may be relegated. Preferred approach: fetch from Supabase `teams` table at runtime (see APIClient.fetchTeams).
enum Team: String, CaseIterable, Identifiable, Codable {
    case arsenal = "arsenal"
    case astonVilla = "aston_villa"
    case bournemouth = "bournemouth"
    case brentford = "brentford"
    case brighton = "brighton"
    case chelsea = "chelsea"
    case crystalPalace = "crystal_palace"
    case everton = "everton"
    case fulham = "fulham"
    case ipswich = "ipswich"
    case leicester = "leicester"
    case liverpool = "liverpool"
    case manCity = "man_city"
    case manUtd = "man_utd"
    case newcastle = "newcastle"
    case nottmForest = "nottm_forest"
    case southampton = "southampton"
    case spurs = "spurs"
    case westHam = "west_ham"
    case wolves = "wolves"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arsenal: return "Arsenal"
        case .astonVilla: return "Aston Villa"
        case .bournemouth: return "AFC Bournemouth"
        case .brentford: return "Brentford"
        case .brighton: return "Brighton & Hove Albion"
        case .chelsea: return "Chelsea"
        case .crystalPalace: return "Crystal Palace"
        case .everton: return "Everton"
        case .fulham: return "Fulham"
        case .ipswich: return "Ipswich Town"
        case .leicester: return "Leicester City"
        case .liverpool: return "Liverpool"
        case .manCity: return "Manchester City"
        case .manUtd: return "Manchester United"
        case .newcastle: return "Newcastle United"
        case .nottmForest: return "Nottingham Forest"
        case .southampton: return "Southampton"
        case .spurs: return "Tottenham Hotspur"
        case .westHam: return "West Ham United"
        case .wolves: return "Wolverhampton Wanderers"
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
        case .crystalPalace: return "Crystal Palace"
        case .everton: return "Everton"
        case .fulham: return "Fulham"
        case .ipswich: return "Ipswich"
        case .leicester: return "Leicester"
        case .liverpool: return "Liverpool"
        case .manCity: return "Man City"
        case .manUtd: return "Man Utd"
        case .newcastle: return "Newcastle"
        case .nottmForest: return "Nott'm Forest"
        case .southampton: return "Southampton"
        case .spurs: return "Spurs"
        case .westHam: return "West Ham"
        case .wolves: return "Wolves"
        }
    }

    var badgeImageName: String {
        rawValue + "_badge"
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
        case .crystalPalace: nicknames = "Eagles"
        case .everton: nicknames = "Toffees"
        case .fulham: nicknames = "Cottagers"
        case .ipswich: nicknames = "Tractor Boys"
        case .leicester: nicknames = "Foxes"
        case .liverpool: nicknames = "Reds"
        case .manCity: nicknames = "Citizens"
        case .manUtd: nicknames = "Red Devils"
        case .newcastle: nicknames = "Magpies Toon"
        case .nottmForest: nicknames = "Tricky Trees"
        case .southampton: nicknames = "Saints"
        case .spurs: nicknames = "Lilywhites"
        case .westHam: nicknames = "Hammers"
        case .wolves: nicknames = "Wanderers"
        }
        return "\(displayName) \(shortName) \(nicknames)".lowercased()
    }
}
