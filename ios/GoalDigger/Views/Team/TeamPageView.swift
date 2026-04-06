import SwiftUI

struct TeamPageView: View {
    let teamId: String
    @Environment(AppState.self) var appState
    @State private var content: TeamPageContent?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if let content {
                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                        if let nickname = content.nickname {
                            Text(nickname)
                                .font(.detailTitle)
                                .foregroundColor(.textOnDark)
                        }

                        if let stadium = content.stadium {
                            infoRow(icon: "building.2", label: "Stadium", value: stadium)
                        }

                        if let manager = content.manager {
                            infoRow(icon: "person", label: "Manager", value: appState.personalise(manager))
                        }

                        if let rival = content.biggestRival {
                            infoRow(icon: "flame", label: "Biggest Rival", value: appState.personalise(rival))
                        }

                        if let players = content.topPlayers, !players.isEmpty {
                            VStack(alignment: .leading, spacing: Layout.elementSpacing) {
                                SectionHeaderView(title: "Key Players", icon: "star")

                                ForEach(players) { player in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(player.name)
                                                .font(.feedHeadline)
                                                .foregroundColor(.textPrimaryOnCard)
                                            Text(player.position)
                                                .font(.feedTimestamp)
                                                .foregroundColor(.textSecondaryOnCard)
                                        }
                                        Spacer()
                                        if let oneLiner = player.oneLiner {
                                            Text(appState.personalise(oneLiner))
                                                .font(.feedTimestamp)
                                                .foregroundColor(.textSecondaryOnCard)
                                                .multilineTextAlignment(.trailing)
                                                .frame(maxWidth: 160)
                                        }
                                    }
                                    .cardStyle()
                                }
                            }
                        }

                        if let funFact = content.funFact {
                            VStack(alignment: .leading, spacing: Layout.elementSpacing) {
                                SectionHeaderView(title: "Fun Fact", icon: "lightbulb")

                                Text(appState.personalise(funFact))
                                    .font(.detailBody)
                                    .foregroundColor(.textPrimaryOnCard)
                                    .cardStyle()
                            }
                        }

                        if let summary = content.seasonSummary {
                            VStack(alignment: .leading, spacing: Layout.elementSpacing) {
                                SectionHeaderView(title: "This Season", icon: "chart.line.uptrend.xyaxis")

                                Text(appState.personalise(summary))
                                    .font(.detailBody)
                                    .foregroundColor(.textPrimaryOnCard)
                                    .cardStyle()
                            }
                        }
                    }
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            } else if isLoading {
                ProgressView()
                    .tint(.hotRose)
            }
        }
        .navigationTitle("\(appState.hisName.isEmpty ? "His" : appState.hisName + "'s") Team")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await loadTeamPage() }
    }

    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.hotRose)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.feedBadge)
                    .foregroundColor(.textSecondaryOnCard)
                    .tracking(0.5)
                Text(value)
                    .font(.detailBody)
                    .foregroundColor(.textPrimaryOnCard)
            }
        }
        .cardStyle()
    }

    private func loadTeamPage() async {
        do {
            content = try await APIClient.shared.fetchTeamPage(teamId: teamId)
        } catch {
            // Silent failure
        }
        isLoading = false
    }
}
