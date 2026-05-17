import SwiftUI

/// V2.0 — one-time sheet shown to V1.x users on app launch after the V2.0
/// update. Asks if they want to pick a World Cup country to follow. Wraps
/// `CountrySelectionView` in sheet chrome with a Skip option.
///
/// Trigger condition (checked in RootView):
///   hasCompletedOnboarding == true
///   && selectedCountry == nil
///   && !hasSeenWCPrompt
///
/// After this sheet dismisses (either via country pick or Skip), the
/// `hasSeenWCPrompt` flag is set so the user is never bothered again.
/// Users who skip can pick a country later by Settings → Delete My Data
/// → re-onboard (V2.1 will add a proper Settings option).
struct WCMigrationSheetView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("World Cup is coming.")
                        .font(.onboardingTitle)
                        .foregroundColor(.textOnDark)
                    Text(prompt)
                        .font(.onboardingBody)
                        .foregroundColor(.textOnDark.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, 32)
                .padding(.bottom, 8)

                // Embed CountrySelectionView. Its onContinue handler picks
                // up appState.selectedCountry as side-effect; we listen for
                // that change here to dismiss the sheet automatically.
                CountrySelectionView {
                    // Promote the newly-picked country to active context so
                    // the feed switches immediately. Without this, activeContext
                    // stays at the pre-sheet value (.team(arsenal)) and the
                    // user lands on the PL feed even though they just picked
                    // their country — and the scenePhase handler would keep
                    // resetting it back to PL on every background/return.
                    if let country = appState.selectedCountry {
                        appState.activeContext = .country(country)
                    }
                    appState.hasSeenWCPrompt = true
                    dismiss()
                }
            }

            Button("Maybe later") {
                appState.hasSeenWCPrompt = true
                dismiss()
            }
            .font(.onboardingBody)
            .foregroundColor(.hotRose)
            .padding(.top, 12)
            .padding(.trailing, 20)
        }
        .interactiveDismissDisabled(true)
    }

    private var prompt: String {
        if appState.hisName.isEmpty {
            return "Who's your boyfriend backing this summer?"
        }
        return "Who is \(appState.hisName) backing this summer?"
    }
}
