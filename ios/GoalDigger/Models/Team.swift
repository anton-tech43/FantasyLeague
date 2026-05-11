import Foundation

// 2025-26 PL roster. Promoted in: Leeds, Sunderland, Burnley. Relegated:
// Ipswich, Leicester, Southampton (kept in this enum so historical content
// items referencing them still decode — they just don't represent live PL
// teams anymore). Preferred long-term approach: fetch from Supabase `teams`
// table at runtime so the iOS app stays in sync without a release.
enum Team: String, CaseIterable, Identifiable, Codable {
    case arsenal = "arsenal"
    case astonVilla = "aston_villa"
    case bournemouth = "bournemouth"
    case brentford = "brentford"
    case brighton = "brighton"
    case burnley = "burnley"
    case chelsea = "chelsea"
    case crystalPalace = "crystal_palace"
    case everton = "everton"
    case fulham = "fulham"
    case ipswich = "ipswich"
    case leeds = "leeds"
    case leicester = "leicester"
    case liverpool = "liverpool"
    case manCity = "man_city"
    case manUtd = "man_utd"
    case newcastle = "newcastle"
    case nottmForest = "nottm_forest"
    case southampton = "southampton"
    case spurs = "spurs"
    case sunderland = "sunderland"
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
        case .burnley: return "Burnley"
        case .chelsea: return "Chelsea"
        case .crystalPalace: return "Crystal Palace"
        case .everton: return "Everton"
        case .fulham: return "Fulham"
        case .ipswich: return "Ipswich Town"
        case .leeds: return "Leeds United"
        case .leicester: return "Leicester City"
        case .liverpool: return "Liverpool"
        case .manCity: return "Manchester City"
        case .manUtd: return "Manchester United"
        case .newcastle: return "Newcastle United"
        case .nottmForest: return "Nottingham Forest"
        case .southampton: return "Southampton"
        case .spurs: return "Tottenham Hotspur"
        case .sunderland: return "Sunderland"
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
        case .burnley: return "Burnley"
        case .chelsea: return "Chelsea"
        case .crystalPalace: return "Crystal Palace"
        case .everton: return "Everton"
        case .fulham: return "Fulham"
        case .ipswich: return "Ipswich"
        case .leeds: return "Leeds"
        case .leicester: return "Leicester"
        case .liverpool: return "Liverpool"
        case .manCity: return "Man City"
        case .manUtd: return "Man Utd"
        case .newcastle: return "Newcastle"
        case .nottmForest: return "Nott'm Forest"
        case .southampton: return "Southampton"
        case .spurs: return "Spurs"
        case .sunderland: return "Sunderland"
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
        case .burnley: nicknames = "Clarets"
        case .chelsea: nicknames = "Blues"
        case .crystalPalace: nicknames = "Eagles"
        case .everton: nicknames = "Toffees"
        case .fulham: nicknames = "Cottagers"
        case .ipswich: nicknames = "Tractor Boys"
        case .leeds: nicknames = "Whites Peacocks"
        case .leicester: nicknames = "Foxes"
        case .liverpool: nicknames = "Reds"
        case .manCity: nicknames = "Citizens"
        case .manUtd: nicknames = "Red Devils"
        case .newcastle: nicknames = "Magpies Toon"
        case .nottmForest: nicknames = "Tricky Trees"
        case .southampton: nicknames = "Saints"
        case .spurs: nicknames = "Lilywhites"
        case .sunderland: nicknames = "Black Cats"
        case .westHam: nicknames = "Hammers"
        case .wolves: nicknames = "Wanderers"
        }
        return "\(displayName) \(shortName) \(nicknames)".lowercased()
    }
}
