import SwiftUI

@Observable
class AppState {
    /// Shared instance — used by AppDelegate and NotificationService which
    /// cannot access the SwiftUI environment. The same instance is also
    /// injected into the view hierarchy via .environment().
    static let shared = AppState()

    // Persisted — names stored LOCAL-ONLY (never sent to server)
    var herName: String {
        didSet { UserDefaults.standard.set(herName, forKey: "herName") }
    }
    var hisName: String {
        didSet { UserDefaults.standard.set(hisName, forKey: "hisName") }
    }
    var selectedTeam: Team? {
        didSet {
            if let team = selectedTeam {
                UserDefaults.standard.set(team.rawValue, forKey: "selectedTeam")
            }
        }
    }
    var selectedTier: Int {
        didSet { UserDefaults.standard.set(selectedTier, forKey: "selectedTier") }
    }
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    var notificationPermissionRequested: Bool {
        didSet { UserDefaults.standard.set(notificationPermissionRequested, forKey: "notificationPermissionRequested") }
    }

    // Navigation
    var deepLinkContentId: UUID?

    // Feed context — session-only, not persisted. Resets to .team(selectedTeam) on app launch.
    var activeContext: FeedContext = .everyoneTalking
    var isContextSwitcherOpen: Bool = false

    // Feed style — persisted
    var feedStyle: FeedStyle {
        didSet { UserDefaults.standard.set(feedStyle.rawValue, forKey: "feedStyle") }
    }

    enum FeedStyle: String {
        case immersive, classic
    }

    init() {
        self.herName = UserDefaults.standard.string(forKey: "herName") ?? ""
        self.hisName = UserDefaults.standard.string(forKey: "hisName") ?? ""
        let teamRaw = UserDefaults.standard.string(forKey: "selectedTeam")
        self.selectedTeam = teamRaw.flatMap { Team(rawValue: $0) }
        self.selectedTier = UserDefaults.standard.integer(forKey: "selectedTier").clamped(to: 1...3, default: 2)
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.notificationPermissionRequested = UserDefaults.standard.bool(forKey: "notificationPermissionRequested")

        // Feed style — persisted, defaults to immersive (one full-screen card
        // per scroll position). The "lands on article" complaint earlier was
        // actually a separate auto-expand bug, now removed; the immersive feed
        // itself is the intended default.
        let styleRaw = UserDefaults.standard.string(forKey: "feedStyle") ?? "immersive"
        self.feedStyle = FeedStyle(rawValue: styleRaw) ?? .immersive

        // Active context — always starts on team, session-only
        if let team = self.selectedTeam {
            self.activeContext = .team(team)
        }
    }

    /// Replace [his name] and [her name] placeholders in server-generated content at display time.
    /// Handles lowercase, capitalised (sentence-start), and possessive variants.
    /// Also strips em dashes for cleaner copy.
    ///
    /// Why both cases: routine items written with `[His name]` at sentence start
    /// (audited: 29 of ~150 routine rows). Without capitalised handling, those
    /// sentences render the literal placeholder in the UI. Lowercase fallback
    /// also returns "your partner" / "Your partner" if the user hasn't filled
    /// in the name in onboarding.
    func personalise(_ text: String) -> String {
        var result = text

        let hisDisplay = hisName.isEmpty ? "your partner" : hisName
        let hisDisplayCapitalised = hisName.isEmpty ? "Your partner" : hisName
        let herDisplay = herName.isEmpty ? "you" : herName
        let herDisplayCapitalised = herName.isEmpty ? "You" : herName

        // His name — lowercase, capitalised, possessive
        result = result.replacingOccurrences(of: "[his name's]", with: hisDisplay + "'s")
        result = result.replacingOccurrences(of: "[His name's]", with: hisDisplayCapitalised + "'s")
        result = result.replacingOccurrences(of: "[his name]", with: hisDisplay)
        result = result.replacingOccurrences(of: "[His name]", with: hisDisplayCapitalised)

        // Her name — lowercase, capitalised, possessive
        result = result.replacingOccurrences(of: "[her name's]", with: herDisplay + "'s")
        result = result.replacingOccurrences(of: "[Her name's]", with: herDisplayCapitalised + "'s")
        result = result.replacingOccurrences(of: "[her name]", with: herDisplay)
        result = result.replacingOccurrences(of: "[Her name]", with: herDisplayCapitalised)

        // Strip em + en dashes (defence-in-depth; post_news.sh also strips them)
        result = result.replacingOccurrences(of: " \u{2014} ", with: ", ")
        result = result.replacingOccurrences(of: "\u{2014}", with: ", ")
        result = result.replacingOccurrences(of: " \u{2013} ", with: ", ")
        result = result.replacingOccurrences(of: "\u{2013}", with: ", ")

        return result
    }

    /// Clear all local data (for "Delete My Data" flow)
    func clearAllData() {
        // Clear team page cache before resetting team
        if let team = selectedTeam {
            TeamPageCache.clear(teamId: team.rawValue)
        }
        herName = ""
        hisName = ""
        selectedTeam = nil
        selectedTier = 2
        hasCompletedOnboarding = false
        notificationPermissionRequested = false
        deepLinkContentId = nil
        activeContext = .everyoneTalking
        isContextSwitcherOpen = false
        feedStyle = .immersive
        let keys = ["herName", "hisName", "selectedTeam", "selectedTier",
                     "hasCompletedOnboarding", "notificationPermissionRequested", "apnsToken",
                     "hasAutoExpandedFirstItem", "feedStyle", "hasSeenImmersiveBanner"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        UnreadTracker.shared.clearAll()
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        if self == 0 { return defaultValue }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
