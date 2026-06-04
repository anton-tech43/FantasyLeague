import SwiftUI

/// V2.0 World Cup onboarding — picks which country he supports in the WC.
/// Replaces TeamSelectionView as the primary entity picker. The PL club
/// picker becomes optional (OptionalPLTeamView) after this step.
///
/// 48 countries grouped by FIFA confederation. Sections collapse to a flat
/// alphabetical list when searching (Apple's standard pattern). Crests are
/// pulled from API-Football CDN via TeamCrestView(country:size:) and cached
/// via URLCache.shared (configured in AppDelegate).
struct CountrySelectionView: View {
    @Environment(AppState.self) var appState
    @State private var selected: Country?
    @State private var searchText = ""
    let onContinue: () -> Void

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

            Text("Who is \(appState.hisName.isEmpty ? "he" : appState.hisName) backing at the World Championship?")
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
                TextField("Search his country...", text: $searchText)
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

            if let country = selected {
                Button("Continue") {
                    appState.selectedCountry = country
                    onContinue()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Layout.screenPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer().frame(height: 16)
        }
        .animation(.easeOut(duration: 0.2), value: selected)
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
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selected = country
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

                if selected == country {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.hotRose)
                }
            }
            .padding(Layout.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .stroke(selected == country ? Color.hotRose : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.cardShadowColor, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
        }
    }
}
