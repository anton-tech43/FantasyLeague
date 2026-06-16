import SwiftUI

/// V2.0 World Cup onboarding — step 5. Asks if he ALSO follows a Premier
/// League team after the WC country is set. Skippable.
///
/// Many WC users won't follow PL at all (especially non-UK audiences arriving
/// via WC marketing) and shouldn't be forced through a team picker for a
/// league they don't watch. Equally, existing PL fans should be able to
/// keep their PL signal alongside their national team.
///
/// Skip path → appState.selectedTeam = nil. Add path → sets selectedTeam.
/// Either way the flow advances to tier selection.
struct OptionalPLTeamView: View {
    @Environment(AppState.self) var appState
    @State private var picks: [Team] = []
    @State private var wantsSecond = false
    @State private var searchText = ""
    let onContinue: () -> Void

    /// Single-replace until the user opts into a second club, then toggle (cap 2).
    private func tap(_ team: Team) {
        guard wantsSecond else { picks = [team]; return }
        if let i = picks.firstIndex(of: team) {
            picks.remove(at: i)
        } else if picks.count < 2 {
            picks.append(team)
        }
    }

    private var filteredTeams: [Team] {
        if searchText.isEmpty {
            return Team.allCases.sorted { $0.displayName < $1.displayName }
        }
        let query = searchText.lowercased()
        return Team.allCases
            .filter { $0.searchableText.contains(query) }
            .sorted { $0.displayName < $1.displayName }
    }

    private var countryShortName: String {
        appState.selectedCountry?.shortName ?? "his country"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield")
                .font(.system(size: 28))
                .foregroundColor(.hotRose.opacity(0.6))
                .padding(.top, 8)

            GlossaryText(raw: "Does \(appState.hisName.isEmpty ? "he" : appState.hisName) follow a Premier League team too?")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            Text("Skip if not. We'll focus on his \(countryShortName) squad.")
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.mutedText)
                    .font(.system(size: 14))
                TextField("Search his team...", text: $searchText)
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

            ScrollView {
                LazyVStack(spacing: Layout.cardSpacing) {
                    ForEach(filteredTeams) { team in
                        let isSelected = picks.contains(team)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                tap(team)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 12) {
                                TeamCrestView(team: team, size: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.mutedText.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                    )

                                Text(team.displayName)
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
                .padding(.horizontal, Layout.screenPadding)
                .padding(.bottom, 8)
            }

            VStack(spacing: 12) {
                if !picks.isEmpty {
                    addOwnToggle
                }

                Button(picks.isEmpty ? "Pick a team" : (picks.count > 1 ? "Add both teams" : "Add team")) {
                    guard !picks.isEmpty else { return }
                    appState.selectedTeams = picks
                    onContinue()
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: !picks.isEmpty))
                .disabled(picks.isEmpty)

                Button("Skip, just his country") {
                    appState.selectedTeams = []
                    onContinue()
                }
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.6))
            }
            .padding(.horizontal, Layout.screenPadding)

            Spacer().frame(height: 16)
        }
        .animation(.easeOut(duration: 0.2), value: picks)
        .animation(.easeOut(duration: 0.2), value: wantsSecond)
        .onAppear {
            picks = appState.selectedTeams
            wantsSecond = appState.selectedTeams.count > 1
        }
        .onChange(of: wantsSecond) { _, on in
            if !on { picks = Array(picks.prefix(1)) }
        }
    }

    /// Opt-in box: "I want to add my own club too." Revealed once a first club
    /// is picked; toggling it on lets the user select a second.
    @ViewBuilder
    private var addOwnToggle: some View {
        Toggle(isOn: $wantsSecond) {
            VStack(alignment: .leading, spacing: 2) {
                Text("I want to add my own club too")
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimaryOnCard)
                Text(wantsSecond ? "Pick a second club (up to 2)." : "Follow two clubs, not just his.")
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
}
