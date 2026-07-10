import SwiftUI

/// V2.0 — one-time sheet shown to V1.x users on app launch after the V2.0
/// update. Asks if they want to pick a World Cup country to follow.
///
/// Trigger condition (checked in RootView):
///   hasCompletedOnboarding == true
///   && selectedCountry == nil
///   && !hasSeenWCPrompt
///
/// After this sheet dismisses (either via country pick or "Maybe later"),
/// the `hasSeenWCPrompt` flag is set so the user is never bothered again.
/// Users who skip can pick a country later in Settings → "Your Countries"
/// (CountryPickerSheet, which re-registers via reregisterForFollowChange).
///
/// Visually: identical to the onboarding `CountrySelectionView` (same
/// globe icon, same title, same subtitle, same search + list + Continue
/// button) — that view already speaks the right invitation copy ("Who
/// is [hisName] backing in the World Cup?" / "His country. Your new
/// month."). The only sheet-specific affordance is the "Maybe later"
/// link in the top-trailing corner. Earlier versions wrapped the embed
/// in its own headline + subtitle, which double-stacked two near-
/// identical questions on screen.
struct WCMigrationSheetView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.appBackground.ignoresSafeArea()

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
            // Push the globe + title down so it doesn't crowd the
            // "Maybe later" button in the top-right corner.
            .padding(.top, 24)

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
}
