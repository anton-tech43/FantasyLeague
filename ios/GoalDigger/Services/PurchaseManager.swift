import StoreKit

@Observable
class PurchaseManager {
    static let shared = PurchaseManager()
    static let productId = "com.goaldigger.unlock"

    var isPurchased: Bool = false {
        didSet { UserDefaults.standard.set(isPurchased, forKey: "com.goaldigger.isPurchased") }
    }
    var isLoading = false
    var errorMessage: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        isPurchased = UserDefaults.standard.bool(forKey: "com.goaldigger.isPurchased")
        Task { await checkEntitlement() }
        transactionListener = Task { await listenForTransactions() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Purchase

    @MainActor
    func purchase() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let product = try await Product.products(for: [Self.productId]).first else {
                errorMessage = "Product not found. Please try again later."
                isLoading = false
                return
            }

            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPurchased = true
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch StoreError.failedVerification {
            errorMessage = "Purchase verification failed. Please try again."
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isLoading = false
    }

    // MARK: - Restore

    @MainActor
    func restore() async {
        isLoading = true
        errorMessage = nil

        try? await AppStore.sync()
        await checkEntitlement()

        isLoading = false
    }

    // MARK: - Entitlement check

    @MainActor
    func checkEntitlement() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.productId {
                found = true
                break
            }
        }
        isPurchased = found
    }

    // MARK: - Transaction listener

    @MainActor
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
            }
            await checkEntitlement()
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
