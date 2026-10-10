import Foundation
import Observation
import OSLog
import StoreKit

/// Owns everything that decides whether Burrow is open: the single
/// non-consumable in-app purchase, and the free trial that precedes it.
///
/// There are no subscriptions and no ads. Both states are derived from StoreKit
/// 2's current entitlements, so they restore automatically on a new device once
/// the parent is signed in to the same App Store account. The trial is a second,
/// free non-consumable, because StoreKit has no introductory offer for a
/// non-consumable and App Review asks for exactly this instead.
@Observable
@MainActor
final class StoreManager {
    static let proProductID = "com.pvd.burrow.pro"
    static let trialProductID = "com.pvd.burrow.trial"

    let trial: TrialService

    private(set) var product: Product?
    private(set) var trialProduct: Product?
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

    /// Opens everything for the length of the trial. The App Store sells a
    /// non-consumable only once per account, so this only ever works once.
    @discardableResult
    func startTrial() async -> Bool {
        if trialProduct == nil { await loadProduct() }
        guard let trialProduct else { return false }
        guard await purchase(trialProduct) else { return false }
        return trial.state.isActive
    }

    func loadProduct() async {
        guard !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }

        do {
            let products = try await Product.products(for: [Self.proProductID, Self.trialProductID])
            product = products.first { $0.id == Self.proProductID }
            trialProduct = products.first { $0.id == Self.trialProductID }
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
        var trialStartedAt: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil else { continue }
            switch transaction.productID {
            case Self.proProductID:
                entitled = true
            case Self.trialProductID:
                trialStartedAt = transaction.originalPurchaseDate
            default:
                break
            }
        }
        isPro = entitled
        trial.record(startedAt: trialStartedAt)
    }

    /// Starts the purchase flow. Returns `true` when the unlock is active
    /// afterwards.
    @discardableResult
    func purchase() async -> Bool {
        if product == nil { await loadProduct() }
        guard let product else { return false }
        guard await purchase(product) else { return false }
        return isPro
    }

    /// Runs one App Store purchase. Returns `true` when it went through and the
    /// entitlements have been re-read.
    private func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        lastErrorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verificationResult: verification)
                return true
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
