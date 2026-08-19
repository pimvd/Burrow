import Foundation
import Observation
import OSLog
import StoreKit

/// Owns everything that decides whether Burrow is open: the single
/// non-consumable in-app purchase, and the free trial that precedes it.
///
/// There are no subscriptions and no ads. The purchase state is derived from
/// StoreKit 2's current entitlements, so it restores automatically on a new
/// device once the parent is signed in to the same App Store account. The trial
/// is the app's own, because StoreKit has no introductory offer for a
/// non-consumable.
@Observable
@MainActor
final class StoreManager {
    static let proProductID = "com.pvd.burrow.pro"

    let trial: TrialService

    private(set) var product: Product?
    private(set) var isPro = false
    private(set) var isLoadingProduct = false
    private(set) var isPurchasing = false
    private(set) var lastErrorMessage: String?

    /// The one question every limit asks. A trial is the whole app, so nothing
    /// downstream needs to know which of the two is paying for it.
    var hasFullAccess: Bool { isPro || trial.state.isActive }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "com.pvd.burrow", category: "Store")

    /// Builds the trial inside an isolated initializer rather than as a default
    /// argument, which would be evaluated in the caller's context.
    convenience init() {
        self.init(trial: TrialService())
    }

    init(trial: TrialService) {
        self.trial = trial
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(verificationResult: update)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Loads the product metadata and the current entitlement. Safe to call more
    /// than once; it simply refreshes.
    func refresh() async {
        trial.refresh()
        await loadProduct()
        await refreshEntitlement()
    }

    /// Opens everything for the length of the trial. Only ever works once.
    func startTrial() {
        trial.start()
    }

    func loadProduct() async {
        guard !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }

        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first
        } catch {
            logger.error("Loading the product failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = String(
                localized: "The store is not reachable right now. Please try again later.",
                comment: "Shown when StoreKit product loading fails"
            )
        }
    }

    func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.proProductID, transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled
    }

    /// Starts the purchase flow. Returns `true` when the unlock is active
    /// afterwards.
    @discardableResult
    func purchase() async -> Bool {
        guard let product else {
            await loadProduct()
            guard product != nil else { return false }
            return await purchase()
        }

        guard !isPurchasing else { return isPro }
        isPurchasing = true
        lastErrorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verificationResult: verification)
                return isPro
            case .userCancelled:
                return false
            case .pending:
                lastErrorMessage = String(
                    localized: "The purchase is waiting for approval.",
                    comment: "Ask to Buy / SCA pending purchase"
                )
                return false
            @unknown default:
                return false
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = String(
                localized: "The purchase could not be completed. Please try again.",
                comment: "Generic purchase failure"
            )
            return false
        }
    }

    /// Restores a previous purchase on a new device.
    func restorePurchases() async {
        lastErrorMessage = nil
        do {
            try await AppStore.sync()
        } catch {
            logger.error("Restore failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = String(
                localized: "Restoring did not work. Please check your internet connection.",
                comment: "Restore purchases failure"
            )
        }
        await refreshEntitlement()
    }

    private func handle(verificationResult: VerificationResult<Transaction>) async {
        switch verificationResult {
        case .verified(let transaction):
            await transaction.finish()
            await refreshEntitlement()
        case .unverified(_, let error):
            logger.error("Unverified transaction: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = String(
                localized: "This purchase could not be verified.",
                comment: "StoreKit verification failure"
            )
        }
    }
}
