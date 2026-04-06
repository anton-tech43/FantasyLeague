import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppState.self) var appState
    @State private var step: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome, herName, hisName, whatToFollow, teamSelection, tierSelection, notificationPrompt
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            switch step {
            case .welcome:
                WelcomeView { step = .herName }
            case .herName:
                HerNameView { step = .hisName }
            case .hisName:
                HisNameView { step = .whatToFollow }
            case .whatToFollow:
                WhatToFollowView { step = .teamSelection }
            case .teamSelection:
                TeamSelectionView { step = .tierSelection }
            case .tierSelection:
                TierSelectionView { step = .notificationPrompt }
            case .notificationPrompt:
                NotificationPromptView {
                    appState.hasCompletedOnboarding = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }
}
