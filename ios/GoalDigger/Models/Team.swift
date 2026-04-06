import Foundation

enum Team: String, CaseIterable, Identifiable, Codable {
    case arsenal = "arsenal"
    case manUtd = "man_utd"
    case westHam = "west_ham"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arsenal: return "Arsenal"
        case .manUtd: return "Manchester United"
        case .westHam: return "West Ham"
        }
    }

    var shortName: String {
        switch self {
        case .arsenal: return "Arsenal"
        case .manUtd: return "Man Utd"
        case .westHam: return "West Ham"
        }
    }
}
