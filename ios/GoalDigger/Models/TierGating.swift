import Foundation

/// Features whose visibility depends on the user's selected tier.
enum AppFeature {
    case insiderCard
    case matchDayLive
    case groupChatPrep
}

/// Maps `AppFeature` to a tier threshold. Views call `isAvailable(_:tier:)`
/// to decide whether to render the feature surface at all. No padlocks:
/// gated features are simply absent from the UI for users below the
/// required tier.
struct TierGating {
    static func isAvailable(_ feature: AppFeature, tier: Int) -> Bool {
        switch feature {
        case .insiderCard, .matchDayLive:
            return tier >= 2
        case .groupChatPrep:
            return tier >= 3
        }
    }
}
