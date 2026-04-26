import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppState.self) var appState
    @State private var step: OnboardingStep = .herName // TEMP: skip welcome for testing

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case herName = 1
        case hisName = 2
        case teamSelection = 3
        case tierSelection = 4
        case notificationPrompt = 5
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots + back button row
                HStack {
                    if step != .welcome {
                        Button {
                            if let prev = OnboardingStep(rawValue: step.rawValue - 1) {
                                step = prev
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.hotRose)
                        }
                    } else {
                        Spacer().frame(width: 14)
                    }

                    Spacer()

                    ProgressDotsView(
                        totalSteps: OnboardingStep.allCases.count,
                        currentStep: step.rawValue
                    )

                    Spacer()

                    // Balance the back button width
                    Spacer().frame(width: 14)
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, 12)

                // Screen content
                switch step {
                case .welcome:
                    WelcomeView { step = .herName }
                case .herName:
                    HerNameView { step = .hisName }
                case .hisName:
                    HisNameView { step = .teamSelection }
                case .teamSelection:
                    TeamSelectionView { step = .tierSelection }
                case .tierSelection:
                    TierSelectionView { step = .notificationPrompt }
                case .notificationPrompt:
                    NotificationPromptView {
                        // Mark all contexts as viewed so first feed open has zero false unread
                        if let team = appState.selectedTeam {
                            UnreadTracker.shared.markViewed(.team(team))
                        }
                        UnreadTracker.shared.markViewed(.everyoneTalking)
                        appState.hasCompletedOnboarding = true
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }
}
