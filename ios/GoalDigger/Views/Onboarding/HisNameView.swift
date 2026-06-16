import SwiftUI

struct HisNameView: View {
    @Environment(AppState.self) var appState
    @State private var name = ""
    let onContinue: () -> Void

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appState.hisName = trimmed
        onContinue()
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "soccerball")
                .font(.system(size: 28))
                .foregroundColor(.hotRose.opacity(0.6))

            Text("And what's their name?")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            // UIKit-backed field — bypasses SwiftUI TextField's focus-state
            // background bug under forced dark mode (see OnboardingTextField).
            OnboardingTextField(
                text: $name,
                placeholder: "Their name",
                autofocus: true,
                onSubmit: submit
            )
            .frame(height: 28)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .stroke(!name.isEmpty ? Color.hotRose : Color.clear, lineWidth: 2)
            )
            .padding(.horizontal, Layout.screenPadding)

            // Relationship — Partner by default; tap to change to parent /
            // sibling / friend. Only changes the fallback noun; everything else
            // runs off their name.
            VStack(spacing: 10) {
                Text("They're my…")
                    .font(.jakarta(13, weight: .medium))
                    .foregroundColor(.textOnDark.opacity(0.6))
                HStack(spacing: 8) {
                    ForEach(AppState.RelationshipType.allCases) { type in
                        relationshipChip(type)
                    }
                }
            }
            .padding(.horizontal, Layout.screenPadding)

            Spacer()

            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Continue", action: submit)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Layout.screenPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer().frame(height: 40)
        }
        .animation(.easeOut(duration: 0.2), value: name.isEmpty)
    }

    @ViewBuilder
    private func relationshipChip(_ type: AppState.RelationshipType) -> some View {
        let selected = appState.relationshipType == type
        Text(type.label)
            .font(.jakarta(13, weight: selected ? .bold : .regular))
            .foregroundColor(selected ? .white : .textOnDark.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(selected ? Color.hotRose : Color.white.opacity(0.08))
            )
            .contentShape(Capsule())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.relationshipType = type
            }
    }
}
