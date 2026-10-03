import SwiftUI

struct HisNameView: View {
    @Environment(AppState.self) var appState
    @State private var name = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The field's height, 28 at the default size and growing with its font.
    @ScaledMetric(relativeTo: .title3) private var fieldHeight: CGFloat = 28
    let onContinue: () -> Void

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appState.hisName = trimmed
        onContinue()
    }

    var body: some View {
        VStack(spacing: 24) {
            FittingScrollView {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "soccerball")
                        .font(.system(size: 28))
                        .foregroundColor(.hotRose.opacity(0.6))
                        .accessibilityHidden(true)

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
                    .frame(height: fieldHeight)
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
                        // One row of four; at large text sizes two rows of two,
                        // then one column, rather than running off the screen.
                        let types = AppState.RelationshipType.allCases
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                ForEach(types) { relationshipChip($0) }
                            }
                            VStack(spacing: 8) {
                                HStack(spacing: 8) { ForEach(types.prefix(2)) { relationshipChip($0) } }
                                HStack(spacing: 8) { ForEach(types.dropFirst(2)) { relationshipChip($0) } }
                            }
                            VStack(spacing: 8) {
                                ForEach(types) { relationshipChip($0) }
                            }
                        }
                    }
                    .padding(.horizontal, Layout.screenPadding)

                    Spacer()
                }
            }

            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Continue", action: submit)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Layout.screenPadding)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

            Spacer().frame(height: 40)
        }
        .animation(.easeOut(duration: 0.2), value: name.isEmpty)
    }

    @ViewBuilder
    private func relationshipChip(_ type: AppState.RelationshipType) -> some View {
        let selected = appState.relationshipType == type
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appState.relationshipType = type
        } label: {
            Text(type.label)
                .font(.jakarta(13, weight: selected ? .bold : .regular))
                .foregroundColor(selected ? .white : .textOnDark.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(selected ? Color.hotRose : Color.white.opacity(0.08))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
