import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(AppState.self) var appState
    @State private var purchaseManager = PurchaseManager.shared
    @State private var product: Product?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 40)

                // Wordmark
                HStack(spacing: 0) {
                    Text("Goal")
                        .font(.jakarta(34, weight: .bold))
                        .foregroundColor(.warmWhite)
                    Text("Digger")
                        .font(.jakarta(34, weight: .bold))
                        .foregroundColor(.hotRose)
                }

                Spacer()
                    .frame(height: 48)

                // Benefits
                VStack(alignment: .leading, spacing: 16) {
                    benefitRow("Know what's happening with \(appState.pPossessive) team")
                    benefitRow("Always have something to say")
                    benefitRow("Know what mood \(appState.pIs) coming home in")
                }
                .padding(.horizontal, Layout.screenPadding)

                Spacer()
                    .frame(height: 48)

                // Price block
                if let product {
                    Text(product.displayPrice)
                        .font(.jakarta(34, weight: .bold))
                        .foregroundColor(.warmWhite)
                } else {
                    ProgressView()
                        .tint(.warmWhite)
                }

                Text("One-time purchase. No subscription. Yours forever.")
                    .font(.jakarta(14, weight: .regular))
                    .foregroundColor(.mutedText)
                    .padding(.top, 4)

                Spacer()

                // CTA button
                Button {
                    Task { await purchaseManager.purchase() }
                } label: {
                    ZStack {
                        if purchaseManager.isLoading {
                            ProgressView()
                                .tint(.warmWhite)
                        } else {
                            Text("Get GoalDigger")
                                .font(.jakarta(17, weight: .semiBold))
                                .foregroundColor(.warmWhite)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.hotRose)
                    .cornerRadius(16)
                }
                .disabled(purchaseManager.isLoading || product == nil)
                .padding(.horizontal, Layout.screenPadding)

                // Restore link
                Button {
                    Task { await purchaseManager.restore() }
                } label: {
                    Text("Restore purchase")
                        .font(.jakarta(14, weight: .regular))
                        .foregroundColor(.mutedText)
                }
                .disabled(purchaseManager.isLoading)
                .padding(.top, 12)

                // Error message
                if let error = purchaseManager.errorMessage {
                    Text(error)
                        .font(.jakarta(14, weight: .regular))
                        .foregroundColor(.hotRose.opacity(0.8))
                        .padding(.top, 8)
                        .padding(.horizontal, Layout.screenPadding)
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .task {
            product = try? await Product.products(for: [PurchaseManager.productId]).first
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.hotRose)
                .font(.system(size: 20))
            Text(text)
                .font(.jakarta(17, weight: .regular))
                .foregroundColor(.warmWhite)
        }
    }
}
