import SwiftUI

/// Onboarding step 3: which Premier League club does he follow. Mandatory,
/// up to 2 clubs. The type name is historical: during the World Championship
/// (V2.0) this step was optional after a forced country pick. Since Sept 2026
/// the club is the primary entity again and there is no skip path (audit
/// 2026-09: a September signup was routed into a dead tournament first).
struct OptionalPLTeamView: View {
    @Environment(AppState.self) var appState
    @State private var picks: [Team] = []
    @State private var wantsSecond = false
    @State private var searchText = ""
    @Environment(\.dynamicTypeSize) private var typeSize
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

    /// Icon, question and search. Pinned above the list at the usual sizes;
    /// at accessibility sizes it alone filled the screen and left no room for
    /// the list, so there it scrolls away with the clubs.
    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield")
                .font(.system(size: 28))
                .foregroundColor(.hotRose.opacity(0.6))
                .padding(.top, 8)
                .accessibilityHidden(true)

            GlossaryText(raw: "Which Premier League team does \(appState.hisName.isEmpty ? appState.pSubject : appState.hisName) follow?")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                // Keep the whole question when the second-club card appears;
                // the club list below gives up the height instead.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.screenPadding)

            Text("Everything in the app is built around \(appState.pPossessive) club.")
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.mutedText)
                    .font(.system(size: 14))
                    .accessibilityHidden(true)
                // The system placeholder grey vanished on the blush field.
                TextField("Search \(appState.pPossessive) team", text: $searchText,
                          prompt: Text("Search \(appState.pPossessive) team...").foregroundColor(.textSecondaryOnCard))
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
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            if !typeSize.isAccessibilitySize {
                header
            }

            ScrollView {
                if typeSize.isAccessibilitySize {
                    header.padding(.bottom, 16)
                    // Pinned, this card took half the screen at these sizes.
                    if !picks.isEmpty {
                        addOwnToggle
                            .padding(.horizontal, Layout.screenPadding)
                            .padding(.bottom, 16)
                    }
                }
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
                                        .accessibilityHidden(true)
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
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.bottom, 8)
            }

            VStack(spacing: 12) {
                if !picks.isEmpty && !typeSize.isAccessibilitySize {
                    addOwnToggle
                }

                Button(picks.isEmpty ? "Pick a team" : (picks.count > 1 ? "Add both teams" : "Add team")) {
                    guard !picks.isEmpty else { return }
                    appState.selectedTeams = picks
                    onContinue()
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: !picks.isEmpty))
                .disabled(picks.isEmpty)
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
                Text(wantsSecond ? "Pick a second club (up to 2)." : "Follow two clubs, not just \(appState.usesHeVoice ? "his" : "theirs").")
                    .font(.feedTimestamp)
                    .foregroundColor(.textSecondaryOnCard)
            }
        }
        .toggleStyle(CardToggleStyle())
        .padding(Layout.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.hotRose.opacity(0.3), lineWidth: 1)
        )
    }
}
