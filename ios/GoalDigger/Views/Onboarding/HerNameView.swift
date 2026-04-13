import SwiftUI

struct HerNameView: View {
    @Environment(AppState.self) var appState
    @State private var name = ""
    @FocusState private var isFocused: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundColor(.hotRose.opacity(0.6))

            Text("First things first,\nwhat's your name?")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            TextField("Your name", text: $name)
                .font(.jakarta(20, weight: .medium))
                .foregroundColor(.textPrimaryOnCard)
                .padding(16)
                .background(Color.cardBackground)
                .cornerRadius(Layout.cardCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                        .stroke(isFocused && !name.isEmpty ? Color.hotRose : Color.clear, lineWidth: 2)
                )
                .padding(.horizontal, Layout.screenPadding)
                .focused($isFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            Spacer()

            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Continue") {
                    appState.herName = name.trimmingCharacters(in: .whitespaces)
                    onContinue()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Layout.screenPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer().frame(height: 40)
        }
        .animation(.easeOut(duration: 0.2), value: name.isEmpty)
        .onAppear { isFocused = true }
    }
}
