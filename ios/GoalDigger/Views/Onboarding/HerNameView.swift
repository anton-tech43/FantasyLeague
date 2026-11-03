import SwiftUI

struct HerNameView: View {
    @Environment(AppState.self) var appState
    @State private var name = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The field's height, 28 at the default size and growing with its font.
    @ScaledMetric(relativeTo: .title3) private var fieldHeight: CGFloat = 28
    let onContinue: () -> Void

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appState.herName = trimmed
        onContinue()
    }

    var body: some View {
        VStack(spacing: 24) {
            FittingScrollView {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundColor(.hotRose.opacity(0.6))
                        .accessibilityHidden(true)

                    Text("First things first,\nwhat's your name?")
                        .font(.onboardingTitle)
                        .foregroundColor(.textOnDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Layout.screenPadding)

                    // UIKit-backed field — bypasses SwiftUI TextField's focus-state
                    // background bug under forced dark mode (see OnboardingTextField).
                    OnboardingTextField(
                        text: $name,
                        placeholder: "Your name",
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
        // The field keeps what she typed. Back re-creates this view, and a kill
        // mid-onboarding restarts the flow; both used to show an empty field
        // with Continue hidden (bug hunt 2026-11-03 U-C4). Saved as she types,
        // so a draft survives too; nothing reads it before onboarding ends.
        .onAppear { if name.isEmpty { name = appState.herName } }
        .onChange(of: name) { _, new in appState.herName = new.trimmingCharacters(in: .whitespaces) }
    }
}
