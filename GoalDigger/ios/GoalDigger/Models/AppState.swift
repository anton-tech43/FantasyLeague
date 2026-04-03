import SwiftUI

@Observable
class AppState {
    /// Shared instance — used by AppDelegate and NotificationService which
    /// cannot access the SwiftUI environment. The same instance is also
    /// injected into the view hierarchy via .environment().
    static let shared = AppState()

    // MARK: - Persisted

    var selectedTeam: Team? {
        didSet {
            if let team = selectedTeam {
                UserDefaults.standard.set(team.rawValue, forKey: "selectedTeam")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedTeam")
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

    // MARK: - Personalization
    // User's name and their partner's name — used for greetings and onboarding.
    // Stored in UserDefaults (plain text only, no sensitive data).

    var userName: String? {
        didSet {
            if let userName {
                UserDefaults.standard.set(userName, forKey: "userName")
            } else {
                UserDefaults.standard.removeObject(forKey: "userName")
            }
        }
    }

    var partnerName: String? {
        didSet {
            if let partnerName {
                UserDefaults.standard.set(partnerName, forKey: "partnerName")
            } else {
                UserDefaults.standard.removeObject(forKey: "partnerName")
            }
        }
    }

    // MARK: - Navigation

    var deepLinkContentId: UUID?

    // MARK: - Init

    init() {
        let teamRaw = UserDefaults.standard.string(forKey: "selectedTeam")
        self.selectedTeam = teamRaw.flatMap { Team(rawValue: $0) }
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.notificationPermissionRequested = UserDefaults.standard.bool(forKey: "notificationPermissionRequested")
        self.userName = UserDefaults.standard.string(forKey: "userName")
        self.partnerName = UserDefaults.standard.string(forKey: "partnerName")
    }
}
