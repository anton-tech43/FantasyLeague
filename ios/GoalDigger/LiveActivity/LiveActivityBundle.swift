import WidgetKit
import SwiftUI

/// Entry point for the GoalDiggerLiveActivity widget extension. Only the live
/// match activity for now; home-screen widgets could be added to the bundle
/// later.
@main
struct GoalDiggerLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        MatchLiveActivity()
    }
}
