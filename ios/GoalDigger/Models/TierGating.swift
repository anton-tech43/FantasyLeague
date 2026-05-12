import Foundation

/// Features whose visibility depends on the user's selected tier.
enum AppFeature {
    case sundayBrief
    case insiderCard
    case matchDayLive
    case saturdayQuiz
    case playerDossier
    case groupChatPrep
}

/// Maps `AppFeature` to a tier threshold. Views call `isAvailable(_:tier:)`
/// to decide whether to render the feature surface at all. No padlocks:
/// gated features are simply absent from the UI for users below the
/// required tier.
struct TierGating {
    static func isAvailable(_ feature: AppFeature, tier: Int) -> Bool {
        switch feature {
        case .sundayBrief, .insiderCard, .matchDayLive:
            return tier >= 2
        case .saturdayQuiz, .playerDossier, .groupChatPrep:
            return tier >= 3
        }
    }
}
