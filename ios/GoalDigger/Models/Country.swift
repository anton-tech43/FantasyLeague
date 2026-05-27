import Foundation

/// World Cup 2026 national teams. Parallel to `Team` (the PL clubs).
/// Both share the same downstream pipeline — the `id` (rawValue) is what
/// gets persisted to `device_tokens.team_id`, queried in `content_items`,
/// and looked up in `team_pages` / `team_season_state`.
///
/// `api_football_id` values verified against `/teams?league=1&season=2026`
/// on 2026-05-16 and match what's in the Supabase `teams` table (where
/// entity_type='country', league_id=1). If the qualifier list changes after
/// the March 2026 intercontinental playoffs, update both this enum AND the
/// `teams` table simultaneously.
enum Country: String, CaseIterable, Identifiable, Codable {
    case algeria
    case argentina
    case australia
    case austria
    case belgium
    case bosniaHerzegovina = "bosnia_herzegovina"
    case brazil
    case canada
    case capeVerde = "cape_verde"
    case colombia
    case congoDR = "congo_dr"
    case croatia
    case curacao
    case czechRepublic = "czech_republic"
    case ecuador
    case egypt
    case england
    case france
    case germany
    case ghana
    case haiti
    case iran
    case iraq
    case ivoryCoast = "ivory_coast"
    case japan
    case jordan
    case mexico
    case morocco
    case netherlands
    case newZealand = "new_zealand"
    case norway
    case panama
    case paraguay
    case portugal
    case qatar
    case saudiArabia = "saudi_arabia"
    case scotland
    case senegal
    case southAfrica = "south_africa"
    case southKorea = "south_korea"
    case spain
    case sweden
    case switzerland
    case tunisia
    case turkiye
    case uruguay
    case usa
    case uzbekistan

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .algeria:           return "Algeria"
        case .argentina:         return "Argentina"
        case .australia:         return "Australia"
        case .austria:           return "Austria"
        case .belgium:           return "Belgium"
        case .bosniaHerzegovina: return "Bosnia & Herzegovina"
        case .brazil:            return "Brazil"
        case .canada:            return "Canada"
        case .capeVerde:         return "Cape Verde"
        case .colombia:          return "Colombia"
        case .congoDR:           return "DR Congo"
        case .croatia:           return "Croatia"
        case .curacao:           return "Curaçao"
        case .czechRepublic:     return "Czech Republic"
        case .ecuador:           return "Ecuador"
        case .egypt:             return "Egypt"
        case .england:           return "England"
        case .france:            return "France"
        case .germany:           return "Germany"
        case .ghana:             return "Ghana"
        case .haiti:             return "Haiti"
        case .iran:              return "Iran"
        case .iraq:              return "Iraq"
        case .ivoryCoast:        return "Ivory Coast"
        case .japan:             return "Japan"
        case .jordan:            return "Jordan"
        case .mexico:            return "Mexico"
        case .morocco:           return "Morocco"
        case .netherlands:       return "Netherlands"
        case .newZealand:        return "New Zealand"
        case .norway:            return "Norway"
        case .panama:            return "Panama"
        case .paraguay:          return "Paraguay"
        case .portugal:          return "Portugal"
        case .qatar:             return "Qatar"
        case .saudiArabia:       return "Saudi Arabia"
        case .scotland:          return "Scotland"
        case .senegal:           return "Senegal"
        case .southAfrica:       return "South Africa"
        case .southKorea:        return "South Korea"
        case .spain:             return "Spain"
        case .sweden:            return "Sweden"
        case .switzerland:       return "Switzerland"
        case .tunisia:           return "Tunisia"
        case .turkiye:           return "Türkiye"
        case .uruguay:           return "Uruguay"
        case .usa:               return "USA"
        case .uzbekistan:        return "Uzbekistan"
        }
    }

    var shortName: String {
        switch self {
        case .bosniaHerzegovina: return "Bosnia"
        case .czechRepublic:     return "Czechia"
        case .congoDR:           return "DR Congo"
        case .newZealand:        return "NZ"
        case .saudiArabia:       return "Saudi"
        case .southAfrica:       return "S. Africa"
        case .southKorea:        return "Korea"
        case .switzerland:       return "Swiss"
        case .ivoryCoast:        return "Ivory Coast"
        case .capeVerde:         return "Cape Verde"
        default:                 return displayName
        }
    }

    /// API-Football team_id. Used to build the flag URL from the team CDN
    /// (same pattern as Team.crestURL).
    var apiFootballId: Int {
        switch self {
        case .belgium:           return 1
        case .france:            return 2
        case .croatia:           return 3
        case .sweden:            return 5
        case .brazil:            return 6
        case .uruguay:           return 7
        case .colombia:          return 8
        case .spain:             return 9
        case .england:           return 10
        case .panama:            return 11
        case .japan:             return 12
        case .senegal:           return 13
        case .switzerland:       return 15
        case .mexico:            return 16
        case .southKorea:        return 17
        case .australia:         return 20
        case .iran:              return 22
        case .saudiArabia:       return 23
        case .germany:           return 25
        case .argentina:         return 26
        case .portugal:          return 27
        case .tunisia:           return 28
        case .morocco:           return 31
        case .egypt:             return 32
        case .czechRepublic:     return 770
        case .austria:           return 775
        case .turkiye:           return 777
        case .norway:            return 1090
        case .scotland:          return 1108
        case .bosniaHerzegovina: return 1113
        case .netherlands:       return 1118
        case .ivoryCoast:        return 1501
        case .ghana:             return 1504
        case .congoDR:           return 1508
        case .southAfrica:       return 1531
        case .algeria:           return 1532
        case .capeVerde:         return 1533
        case .jordan:            return 1548
        case .iraq:              return 1567
        case .uzbekistan:        return 1568
        case .qatar:             return 1569
        case .paraguay:          return 2380
        case .ecuador:           return 2382
        case .usa:               return 2384
        case .haiti:             return 2386
        case .newZealand:        return 4673
        case .canada:            return 5529
        case .curacao:           return 5530
        }
    }

    /// Crest URL used everywhere a country team's emblem is rendered
    /// (team page header, context switcher, picker grid, AffectedTeams,
    /// etc). Prefers the country's FEDERATION CREST when we have one —
    /// the Three Lions for England, CBF for Brazil, AFA for Argentina,
    /// etc. — over API-Football's CDN URL (which returns the country
    /// flag for national teams, not the football federation badge).
    ///
    /// Falls back to the API-Football flag for countries we haven't
    /// sourced a federation-crest URL for yet. iOS AsyncImage handles
    /// both PNG/JPG/SVG; we standardise on PNG.
    var crestURL: URL? {
        if let override = federationCrestURL { return override }
        return URL(string: "https://media.api-sports.io/football/teams/\(apiFootballId).png")
    }

    /// Hand-curated federation-crest URL per country. Returns nil for
    /// any country we haven't sourced a stable URL for yet — `crestURL`
    /// falls back to the API-Football flag in that case (graceful, no
    /// broken image). URLs are Wikipedia upload-CDN thumb URLs.
    ///
    /// FAST-FOLLOW: only England is wired for the launch (UK is the
    /// launch-screenshot audience). The other 47 WC countries fall back
    /// to the flag until their crest URLs are sourced + validated. See
    /// STATUS.md / Lesson 79 for the fast-follow plan.
    ///
    /// To add a country: GET the infobox image from the Wikipedia REST
    /// API — `https://en.wikipedia.org/api/rest_v1/page/summary/<X>_
    /// national_football_team` returns `.originalimage.source`, which is
    /// already a valid upload-CDN URL. Use that verbatim (do NOT
    /// hand-build a `/thumb/.../<N>px-` URL — Wikipedia rejects
    /// arbitrary thumbnail widths with a 400; only sizes the REST API
    /// hands back are guaranteed served). Verify it returns a PNG.
    private var federationCrestURL: URL? {
        switch self {
        case .england:
            // Three Lions crest. Verified PNG (330x516) via the REST API.
            return URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/8/8b/England_national_football_team_crest.svg/330px-England_national_football_team_crest.svg.png")
        default:
            return nil
        }
    }

    /// FIFA confederation. Used for grouping countries in the picker
    /// (European nations together, South American together, etc.) which
    /// gives the 48-item list visual structure.
    enum Confederation: String, CaseIterable {
        case uefa      = "UEFA"        // Europe
        case conmebol  = "CONMEBOL"    // South America
        case concacaf  = "CONCACAF"    // North/Central America + Caribbean
        case afc       = "AFC"         // Asia
        case caf       = "CAF"         // Africa
        case ofc       = "OFC"         // Oceania

        var displayLabel: String {
            switch self {
            case .uefa:     return "Europe"
            case .conmebol: return "South America"
            case .concacaf: return "North & Central America"
            case .afc:      return "Asia"
            case .caf:      return "Africa"
            case .ofc:      return "Oceania"
            }
        }
    }

    var confederation: Confederation {
        switch self {
        // UEFA
        case .austria, .belgium, .bosniaHerzegovina, .croatia, .czechRepublic,
             .england, .france, .germany, .netherlands, .norway,
             .portugal, .scotland, .spain, .sweden, .switzerland, .turkiye:
            return .uefa
        // CONMEBOL
        case .argentina, .brazil, .colombia, .ecuador, .paraguay, .uruguay:
            return .conmebol
        // CONCACAF
        case .canada, .curacao, .haiti, .mexico, .panama, .usa:
            return .concacaf
        // AFC
        case .australia, .iran, .iraq, .japan, .jordan, .qatar, .saudiArabia,
             .southKorea, .uzbekistan:
            return .afc
        // CAF
        case .algeria, .capeVerde, .congoDR, .egypt, .ghana, .ivoryCoast,
             .morocco, .senegal, .southAfrica, .tunisia:
            return .caf
        // OFC
        case .newZealand:
            return .ofc
        }
    }

    /// Search tokens for the country picker filter. Lowercase, includes
    /// short name and common alternate spellings.
    var searchableText: String {
        let extras: String
        switch self {
        case .usa:               extras = "united states america us"
        case .southKorea:        extras = "korea republic"
        case .bosniaHerzegovina: extras = "bih"
        case .czechRepublic:     extras = "czechia"
        case .ivoryCoast:        extras = "cote ivoire"
        case .netherlands:       extras = "holland dutch"
        case .turkiye:           extras = "turkey"
        case .congoDR:           extras = "congo democratic"
        default:                 extras = ""
        }
        return "\(displayName) \(shortName) \(extras)".lowercased()
    }
}
