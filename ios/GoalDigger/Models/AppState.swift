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
            } else {
                // Symmetry with selectedCountry: clear the key when unset, so
                // skipping the optional PL team doesn't leave a stale club
                // behind for a country-only (WC) user.
                UserDefaults.standard.removeObject(forKey: "selectedTeam")
            }
        }
    }
    /// V2.0 World Cup support — the country he supports at WC 2026. New
    /// users land on this picker first (WC is the primary onboarding
    /// context); selectedTeam (PL club) is then offered as optional.
    /// Both can be set simultaneously for fans who follow both.
    var selectedCountry: Country? {
        didSet {
            if let country = selectedCountry {
                UserDefaults.standard.set(country.rawValue, forKey: "selectedCountry")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedCountry")
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
    var calendarSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(calendarSyncEnabled, forKey: "calendarSyncEnabled") }
    }
    /// Whether the user has dismissed the post-onboarding Season Primer screen.
    /// True after they tap either CTA on `SeasonPrimerView`, OR after a fetch
    /// failure (defensive: we never block twice on a slow/broken backend).
    /// Reset to false in `clearAllData()` so re-onboarding shows it again.
    var hasSeenSeasonPrimer: Bool {
        didSet { UserDefaults.standard.set(hasSeenSeasonPrimer, forKey: "hasSeenSeasonPrimer") }
    }
    /// V2.0: whether the existing-user "World Cup is coming, who's he
    /// backing?" sheet has been dismissed (either by picking a country or
    /// tapping Skip). Shown ONCE on next app launch for V1.x users who
    /// have hasCompletedOnboarding=true but no selectedCountry. New V2.0
    /// users skip this entirely because they pick a country during
    /// onboarding.
    var hasSeenWCPrompt: Bool {
        didSet { UserDefaults.standard.set(hasSeenWCPrompt, forKey: "hasSeenWCPrompt") }
    }

    // Navigation
    var deepLinkContentId: UUID?
    /// Transient, session-only. Set by `SeasonPrimerView` CTAs to direct the
    /// user to the right tab when `MainTabView` first appears. The "Teach me
    /// more" CTA sets this to 1 (His Team); "Take me to the news" sets 0
    /// (Feed). Consumed and cleared on `MainTabView.onAppear` so a later
    /// re-appear (e.g., scenePhase change) doesn't snap back.
    /// NOT persisted.
    var pendingTabAfterPrimer: Int?

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
        let countryRaw = UserDefaults.standard.string(forKey: "selectedCountry")
        self.selectedCountry = countryRaw.flatMap { Country(rawValue: $0) }
        self.selectedTier = UserDefaults.standard.integer(forKey: "selectedTier").clamped(to: 1...3, default: 2)
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.notificationPermissionRequested = UserDefaults.standard.bool(forKey: "notificationPermissionRequested")
        self.calendarSyncEnabled = UserDefaults.standard.bool(forKey: "calendarSyncEnabled")
        self.hasSeenSeasonPrimer = UserDefaults.standard.bool(forKey: "hasSeenSeasonPrimer")
        self.hasSeenWCPrompt = UserDefaults.standard.bool(forKey: "hasSeenWCPrompt")

        // Feed style — persisted, defaults to immersive (one full-screen card
        // per scroll position). The "lands on article" complaint earlier was
        // actually a separate auto-expand bug, now removed; the immersive feed
        // itself is the intended default.
        let styleRaw = UserDefaults.standard.string(forKey: "feedStyle") ?? "immersive"
        self.feedStyle = FeedStyle(rawValue: styleRaw) ?? .immersive

        // Active context — country takes precedence over team in V2.0 (WC
        // is the primary anchor; if the user has both, default to the WC
        // feed). Falls back to team for V1.x users with no country selected,
        // and to .everyoneTalking when neither is set.
        if let country = self.selectedCountry {
            self.activeContext = .country(country)
        } else if let team = self.selectedTeam {
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

    /// Force pending UserDefaults writes to disk NOW.
    ///
    /// UserDefaults persists asynchronously — `set(_:forKey:)` updates an
    /// in-memory cache and cfprefsd flushes to disk on a timer and on app
    /// suspension. So onboarding state written moments before the user
    /// force-quits (swipes the app away) or a crash/jetsam kill can be lost,
    /// and the user re-enters EVERYTHING on next launch. Calling this at the
    /// load-bearing moments (onboarding complete; resign-active) flushes the
    /// whole suite at once and closes that window. `synchronize()` is the only
    /// public API to force the write; Apple's "usually unnecessary" note
    /// assumes the process isn't killed first — which is exactly this bug.
    func persistNow() {
        UserDefaults.standard.synchronize()
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
        selectedCountry = nil
        selectedTier = 2
        hasCompletedOnboarding = false
        notificationPermissionRequested = false
        calendarSyncEnabled = false
        hasSeenSeasonPrimer = false
        hasSeenWCPrompt = false
        deepLinkContentId = nil
        pendingTabAfterPrimer = nil
        activeContext = .everyoneTalking
        isContextSwitcherOpen = false
        feedStyle = .immersive
        let keys = ["herName", "hisName", "selectedTeam", "selectedCountry", "selectedTier",
                     "hasCompletedOnboarding", "notificationPermissionRequested", "apnsToken",
                     "apnsTokenRegistered",
                     "hasAutoExpandedFirstItem", "feedStyle", "hasSeenImmersiveBanner",
                     "calendarSyncEnabled", "hasSeenSeasonPrimer", "hasSeenWCPrompt"]
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
