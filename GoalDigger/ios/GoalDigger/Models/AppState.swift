import SwiftUI

/// Central app state, persisted via UserDefaults.
/// Shared instance used by AppDelegate and NotificationService which
/// cannot access the SwiftUI environment.
@Observable
class AppState {
    static let shared = AppState()

    // MARK: - Persisted State

    var selectedTeam: Team? {
        didSet {
            if let team = selectedTeam {
                UserDefaults.standard.set(team.rawValue, forKey: "selectedTeam")
            }
        }
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    var notificationPermissionRequested: Bool {
        didSet {
            UserDefaults.standard.set(notificationPermissionRequested, forKey: "notificationPermissionRequested")
        }
    }

    // MARK: - Navigation State

    var deepLinkContentId: UUID?

    // MARK: - Init

    init() {
        let teamRaw = UserDefaults.standard.string(forKey: "selectedTeam")
        self.selectedTeam = teamRaw.flatMap { Team(rawValue: $0) }
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.notificationPermissionRequested = UserDefaults.standard.bool(forKey: "notificationPermissionRequested")
    }
}
