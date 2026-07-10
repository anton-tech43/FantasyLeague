import Foundation

/// One niche fact about his team — the "Things he doesn't know" card.
/// Populated daily by the gd-insider cloud routine (one row per team per
/// day, type rotates: stat / anecdote / history / oddity). Shown on the
/// His Team tab and as a Feed empty-state surface for T2+ users.
struct InsiderItem: Codable, Identifiable, Equatable {
    enum ItemType: String, Codable {
        case stat, anecdote, history, oddity

        /// Uppercase tracker label shown in the card header.
        var label: String {
            switch self {
            case .stat:     return "STAT"
            case .anecdote: return "ANECDOTE"
            case .history:  return "HISTORY"
            case .oddity:   return "ODDITY"
            }
        }

        /// SF Symbol that goes next to the tracker label.
        var iconName: String {
            switch self {
            case .stat:     return "chart.bar.fill"
            case .anecdote: return "quote.opening"
            case .history:  return "book.closed.fill"
            case .oddity:   return "sparkles"
            }
        }
    }

    let id: UUID
    let teamId: String
    let type: ItemType
    let title: String
    let body: String
    let sourceUrl: String?
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, title, body
        case teamId = "team_id"
        case sourceUrl = "source_url"
        case publishedAt = "published_at"
    }
}
