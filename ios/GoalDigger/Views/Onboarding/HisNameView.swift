import SwiftUI

struct HisNameView: View {
    @Environment(AppState.self) var appState
    @State private var name = ""
    @FocusState private var isFocused: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "soccerball")
                .font(.system(size: 28))
                .foregroundColor(.hotRose.opacity(0.6))

            Text("And what's his name?")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            TextField("His name", text: $name)
                .textFieldStyle(.plain)
                .font(.jakarta(20, weight: .medium))
                .foregroundColor(.textPrimaryOnCard)
                .tint(.hotRose)
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
                    appState.hisName = name.trimmingCharacters(in: .whitespaces)
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
