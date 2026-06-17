import SwiftUI

/// V2.0 World Cup onboarding — picks which country he supports in the WC.
/// The primary entity picker; the PL club picker is optional
/// (OptionalPLTeamView) after this step.
///
/// 48 countries grouped by FIFA confederation. Sections collapse to a flat
/// alphabetical list when searching (Apple's standard pattern). Crests are
/// pulled from API-Football CDN via TeamCrestView(country:size:) and cached
/// via URLCache.shared (configured in AppDelegate).
struct CountrySelectionView: View {
    @Environment(AppState.self) var appState
    @State private var picks: [Country] = []
    @State private var wantsSecond = false
    @State private var searchText = ""
    /// When true, offer an opt-in box to follow a SECOND country (cap 2) — e.g.
    /// his Norway plus her Sweden. Onboarding's WC step and the Settings picker
    /// pass true; WCMigration keeps the single-pick default.
    var allowsSecond: Bool = false
    let onContinue: () -> Void

    /// Tap behaviour: single-replace by default; when the user has opted into a
    /// second country, tapping toggles membership (capped at 2).
    private func tap(_ country: Country) {
        guard allowsSecond, wantsSecond else { picks = [country]; return }
        if let i = picks.firstIndex(of: country) {
            picks.remove(at: i)
        } else if picks.count < 2 {
            picks.append(country)
        }
    }

    /// When search is empty: grouped by confederation.
    /// When searching: flat alphabetical list filtered by searchableText.
    private var groupedCountries: [(Country.Confederation, [Country])] {
        guard searchText.isEmpty else { return [] }
        let all = Country.allCases
        let byConf = Dictionary(grouping: all) { $0.confederation }
        return Country.Confederation.allCases.compactMap { conf in
            guard let group = byConf[conf] else { return nil }
            let sorted = group.sorted { $0.displayName < $1.displayName }
            return (conf, sorted)
        }
    }

    private var filteredCountries: [Country] {
        let query = searchText.lowercased()
        return Country.allCases
            .filter { $0.searchableText.contains(query) }
            .sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 28))
                .foregroundColor(.hotRose.opacity(0.6))
                .padding(.top, 8)

            GlossaryText(raw: "Who is \(appState.hisName.isEmpty ? "they" : appState.hisName) backing at the World Championship?")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            Text("His country. Your new month.")
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.8))
                .padding(.horizontal, Layout.screenPadding)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.mutedText)
                    .font(.system(size: 14))
                TextField("Search for a country...", text: $searchText)
                    .font(.jakarta(17, weight: .regular))
                    .foregroundColor(.textPrimaryOnCard)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .stroke(Color.hotRose.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, Layout.screenPadding)

            // Country list
            ScrollView {
                LazyVStack(spacing: Layout.cardSpacing, pinnedViews: []) {
                    if searchText.isEmpty {
                        ForEach(groupedCountries, id: \.0) { conf, countries in
                            sectionHeader(conf.displayLabel)
                            ForEach(countries) { country in
                                countryRow(country)
                            }
                        }
                    } else {
                        ForEach(filteredCountries) { country in
                            countryRow(country)
                        }
                    }
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.bottom, 8)
            }

            if allowsSecond, !picks.isEmpty {
                addOwnToggle
                    .padding(.horizontal, Layout.screenPadding)
                    .transition(.opacity)
            }

            if !picks.isEmpty {
                Button(picks.count > 1 ? "Continue with both" : "Continue") {
                    appState.selectedCountries = picks
                    onContinue()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Layout.screenPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer().frame(height: 16)
        }
        .animation(.easeOut(duration: 0.2), value: picks)
        .animation(.easeOut(duration: 0.2), value: wantsSecond)
        .onAppear {
            // Seed from current state so re-entering (Settings, or back-nav)
            // shows the existing pick(s) instead of an empty selection.
            picks = appState.selectedCountries
            wantsSecond = appState.selectedCountries.count > 1
        }
        .onChange(of: wantsSecond) { _, on in
            if !on { picks = Array(picks.prefix(1)) }
        }
    }

    /// Opt-in box: "I want to add my own country too." Revealed once a first
    /// country is picked; toggling it on lets the user select a second.
    @ViewBuilder
    private var addOwnToggle: some View {
        Toggle(isOn: $wantsSecond) {
            VStack(alignment: .leading, spacing: 2) {
                Text("I want to add my own country too")
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimaryOnCard)
                Text(wantsSecond ? "Pick a second country (up to 2)." : "Follow two countries this World Championship.")
                    .font(.feedTimestamp)
                    .foregroundColor(.textSecondaryOnCard)
            }
        }
        .tint(.hotRose)
        .padding(Layout.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.hotRose.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sectionHeader(_ label: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.sectionHeader)
                .foregroundColor(.textOnDark.opacity(0.5))
                .tracking(1.2)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func countryRow(_ country: Country) -> some View {
        let isSelected = picks.contains(country)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                tap(country)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                TeamCrestView(country: country, size: 32)
                    .background(
                        Circle()
                            .fill(Color.mutedText.opacity(0.1))
                            .frame(width: 36, height: 36)
                    )

                Text(country.displayName)
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimaryOnCard)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.hotRose)
                }
            }
            .padding(Layout.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .stroke(isSelected ? Color.hotRose : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.cardShadowColor, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
        }
    }
}
