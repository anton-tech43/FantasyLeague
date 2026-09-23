import UIKit
import AppTrackingTransparency
import FBSDKCoreKit

/// App-install attribution for Meta ads: ATT consent + the SDK's advertiser
/// tracking flag. No events are logged from here — `isAutoLogAppEventsEnabled`
/// makes the SDK log `fb_mobile_activate_app` itself on every foreground.
@MainActor
enum Attribution {
    /// Return value of `ApplicationDelegate.application(_:didFinishLaunchingWithOptions:)`.
    /// v18 exposes no public `isSDKInitialized`; this Bool is the only public
    /// proof the SDK's launch path ran (it is `false` if it ran twice).
    static var sdkLaunched = false

    private static let promptedKey = "attPrompted"

    /// Re-tell the SDK the user's standing ATT answer. Must run on every launch:
    /// the flag lives in the SDK's memory, not in UserDefaults.
    static func syncTrackingStatus() {
        Settings.shared.isAdvertiserTrackingEnabled =
            ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    /// Show the ATT sheet once per install, 1.5 s after the main tab view
    /// appears — never during onboarding (the notification prompt lives there;
    /// two system sheets in a row is how you get both declined).
    static func requestTrackingIfNeeded() async {
        var forced = false
        #if DEBUG
        // Screenshot harness: every harness launch passes -gdPresetTeam, and a
        // system sheet would make those screenshots non-deterministic.
        // -gdForceATT is the escape hatch that proves the sheet still appears.
        // The arguments are read inside the guard, not above it: in Release
        // this was an unused local, and a launch-argument read in a shipped
        // binary invites the reader to wonder what else it is listening for.
        let args = ProcessInfo.processInfo.arguments
        forced = args.contains("-gdForceATT")
        if !forced, args.contains("-gdSkipATT") || args.contains("-gdPresetTeam") { return }
        #endif

        if !forced {
            guard !UserDefaults.standard.bool(forKey: promptedKey),
                  AppState.shared.hasCompletedOnboarding else { return }
        }

        try? await Task.sleep(nanoseconds: 1_500_000_000)
        // iOS silently denies the request unless the app is frontmost.
        guard UIApplication.shared.applicationState == .active else { return }

        let status = await withCheckedContinuation { (c: CheckedContinuation<ATTrackingManager.AuthorizationStatus, Never>) in
            ATTrackingManager.requestTrackingAuthorization { c.resume(returning: $0) }
        }
        Settings.shared.isAdvertiserTrackingEnabled = (status == .authorized)
        // Also set when the status was already determined — the sheet never
        // shows twice, so neither should we ever ask again.
        UserDefaults.standard.set(true, forKey: promptedKey)
    }

    #if DEBUG
    /// One-line proof that the Meta SDK is wired: config the build can't
    /// compile-check (Info.plist keys) plus the SDK's own view of it.
    /// Prints exactly one `[FBSDK] ok …` or `[FBSDK] FAIL …` line.
    static func selfCheck() {
        let info = Bundle.main.infoDictionary
        let skan = (info?["SKAdNetworkItems"] as? [[String: Any]])?
            .compactMap { $0["SKAdNetworkIdentifier"] as? String } ?? []
        let schemes = (info?["CFBundleURLTypes"] as? [[String: Any]])?
            .flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] } ?? []

        var fails: [String] = []
        if Settings.shared.appID != "920070997769781" { fails.append("appID=\(Settings.shared.appID ?? "nil")") }
        if Settings.shared.clientToken != "842954293aec297f924aac8071250426" { fails.append("clientToken=\(Settings.shared.clientToken ?? "nil")") }
        if !Settings.shared.isAutoLogAppEventsEnabled { fails.append("autoLogAppEvents=off") }
        if !sdkLaunched { fails.append("sdkLaunched=false") }
        for id in ["v9wttpbfk9.skadnetwork", "n38lu8286q.skadnetwork"] where !skan.contains(id) {
            fails.append("skadnetwork-missing=\(id)")
        }
        if !schemes.contains("fb920070997769781") { fails.append("urlScheme=\(schemes.joined(separator: "|"))") }

        let line = fails.isEmpty
            ? "[FBSDK] ok appID=920070997769781 clientToken=set autoLog=1 skan=\(skan.count) scheme=fb920070997769781 att=\(ATTrackingManager.trackingAuthorizationStatus.rawValue)"
            : "[FBSDK] FAIL \(fails.joined(separator: "; "))"
        print(line)
        NSLog("%@", line) // simctl log stream sees NSLog even when stdout isn't captured

        if ProcessInfo.processInfo.arguments.contains("-gdCheckFBSDK") {
            let json: [String: Any] = [
                "ok": fails.isEmpty,
                "appID": Settings.shared.appID ?? "",
                "clientTokenSet": Settings.shared.clientToken?.isEmpty == false,
                "autoLogAppEvents": Settings.shared.isAutoLogAppEventsEnabled,
                "advertiserIDCollection": Settings.shared.isAdvertiserIDCollectionEnabled,
                "sdkLaunched": sdkLaunched,
                "skAdNetworkItems": skan,
                "urlSchemes": schemes,
                "attStatus": ATTrackingManager.trackingAuthorizationStatus.rawValue,
                "fails": fails,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
               let s = String(data: data, encoding: .utf8) {
                print("[FBSDK] json \(s)")
                NSLog("%@", "[FBSDK] json \(s)")
            }
        }
    }
    #endif
}
