import SwiftUI

struct NotificationPromptView: View {
    @Environment(AppState.self) var appState
    let onComplete: () -> Void

    /// First "I'll do this later" tap opens a smaller explainer instead of
    /// skipping outright — the app is almost nothing without push, so we make
    /// the case once more before accepting the skip.
    @State private var showSecondChance = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 24) {
            FittingScrollView {
                VStack(spacing: 24) {
                    Spacer()

                    LockScreenPreview(team: appState.selectedTeam ?? .arsenal)
                        .padding(.horizontal, Layout.screenPadding)

                    Text("It only works if\nwe can reach you.")
                        .font(.onboardingTitle)
                        .foregroundColor(.textOnDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Layout.screenPadding)

                    Text("A heads-up on match day, then the score on your lock screen while it's on. If your iPhone asks about Live Activities, say yes: that's the score.")
                        .font(.onboardingBody)
                        .foregroundColor(.textOnDark.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Layout.screenPadding)

                    Spacer()
                }
            }

            VStack(spacing: 12) {
                Button("Yes, keep me posted") {
                    Task {
                        _ = await NotificationService.shared.requestPermission()
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("I'll do this later") {
                    showSecondChance = true
                }
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.6))
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showSecondChance) {
            secondChanceSheet
        }
    }

    /// A lighter-weight nudge after the first skip, giving her a second tap to
    /// allow before we let her through.
    private var secondChanceSheet: some View {
        // Scrolls, and opens full height at accessibility text sizes: the
        // fixed 360pt detent clipped the buttons off the bottom.
        FittingScrollView {
            VStack(spacing: 20) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.hotRose)
                    .padding(.top, 8)
                    .accessibilityHidden(true)

                Text("One more thing.")
                    .font(.feedHeadline)
                    .foregroundColor(.warmWhite)

                Text("Without notifications, you won't know \(appState.pIs) playing until \(appState.pIs) already talking about it. It's the whole point of the app, and you can mute it any time.")
                    .font(.jakarta(15, weight: .regular))
                    .foregroundColor(.warmWhite.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Button("Allow notifications") {
                        showSecondChance = false
                        Task {
                            _ = await NotificationService.shared.requestPermission()
                            finish()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("I'll risk missing it") {
                        showSecondChance = false
                        finish()
                    }
                    .font(.onboardingBody)
                    .foregroundColor(.warmWhite.opacity(0.6))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.top, 12)
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(360)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.deepMauve)
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        appState.notificationPermissionRequested = true
        // Token registration happens at the END of onboarding (in OnboardingFlow's
        // completion handler) so we register with the actual tier the user picks.
        onComplete()
    }
}

/// What she is saying yes to, drawn as it will look: the real match-day
/// push copy (matchday-reminder-copy.ts) above the Live Activity with its
/// running minute. Her club, a made-up opponent and score.
private struct LockScreenPreview: View {
    let team: Team

    private var opponent: String { (team == .chelsea ? Team.arsenal : Team.chelsea).shortName }

    var body: some View {
        VStack(spacing: 10) {
            card {
                HStack(alignment: .top, spacing: 10) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .frame(width: 34, height: 34)
                        .background(Color.deepMauve)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(team.shortName) play today").font(.jakarta(14, weight: .bold))
                            Spacer()
                            Text("now").font(.jakarta(12, weight: .regular)).opacity(0.6)
                        }
                        Text("\(team.shortName) face \(opponent) today at 15:00. Ask for a score prediction before kickoff.")
                            .font(.jakarta(13, weight: .regular))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            card {
                HStack {
                    Text(team.shortName).font(.jakarta(15, weight: .bold))
                    Spacer()
                    Text("1 – 0").font(.jakarta(22, weight: .extraBold)).monospacedDigit()
                    Spacer()
                    Text(opponent).font(.jakarta(15, weight: .bold))
                }
                .overlay(alignment: .bottom) {
                    Text("63'").font(.jakarta(12, weight: .bold)).foregroundStyle(Color.hotRose)
                        .offset(y: 16)
                }
                .padding(.bottom, 10)
            }
        }
        .foregroundStyle(Color.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example: a match-day notification, then the live score on your lock screen.")
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .environment(\.colorScheme, .dark)
    }
}
