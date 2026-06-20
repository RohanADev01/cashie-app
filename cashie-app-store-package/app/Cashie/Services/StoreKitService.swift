import Foundation
import StoreKit

// Local alias avoids clashing with the app's own `Transaction` model.
private typealias SKTransaction = StoreKit.Transaction

/// Production purchase gateway backed by native StoreKit 2. This is the only
/// subscription backend Cashie ships with.
///
/// During development the simulator reads from `Cashie.storekit` (set on the
/// scheme), so calling `purchase()` triggers Apple's real system sheet — with
/// the double-tap-side-button / Face ID confirmation. On device and in the
/// App Store it talks to the real App Store.
///
/// Conforms to `SubscriptionService` so the rest of the app talks to a single
/// subscription protocol.
final class StoreKitService: SubscriptionService {
    private static let subscribedKey = "isSubscribed"

    private let productIDs: [String] = [
        "cashie_pro_monthly",
        "cashie_pro_yearly_v2"
    ]

    private var loadedProducts: [String: Product] = [:]
    private var transactionListener: Task<Void, Never>?

    var isSubscribed: Bool {
        UserDefaults.standard.bool(forKey: Self.subscribedKey)
    }

    init() {
        // Watch for transactions that arrive outside an explicit purchase()
        // (renewals, sandbox refreshes, restores from another device).
        transactionListener = Task.detached {
            for await update in SKTransaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await Self.refreshFromCurrentEntitlementsStatic()
                }
            }
        }
    }

    deinit { transactionListener?.cancel() }

    // MARK: - SubscriptionService

    func refreshSubscriptionStatus() async throws -> Bool {
        await refreshFromCurrentEntitlements()
        return isSubscribed
    }

    func loadOfferings() async throws -> [Offering] {
        try await ensureProductsLoaded()
        let monthly = loadedProducts["cashie_pro_monthly"]
        let yearly = loadedProducts["cashie_pro_yearly_v2"]
        var out: [Offering] = []
        if let yearly { out.append(offering(from: yearly)) }
        if let monthly { out.append(offering(from: monthly)) }
        return out
    }

    func purchase(_ offering: Offering) async throws -> PurchaseResult {
        try await ensureProductsLoaded()
        guard let product = loadedProducts[offering.id] else {
            // No products loaded → the simulator was launched without a
            // StoreKit configuration (e.g. via `xcrun simctl launch` rather
            // than from Xcode). In DEBUG we simulate a successful purchase so
            // the rest of the onboarding flow is still testable; release
            // builds keep this as a hard cancel.
            #if DEBUG
            markSubscribed(true)
            return .success
            #else
            return .cancelled
            #endif
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let tx):
                await tx.finish()
                markSubscribed(true)
                return .success
            case .unverified:
                return .cancelled
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws -> Bool {
        try await AppStore.sync()
        await refreshFromCurrentEntitlements()
        return isSubscribed
    }

    /// The `originalTransactionId` of the current verified Pro entitlement, as a
    /// string, or `nil` if none. The mint endpoint uses it to look the
    /// subscription up via Apple's App Store Server API.
    func proEntitlementToken() async -> String? {
        for await result in SKTransaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.revocationDate == nil,
               productIDs.contains(tx.productID) {
                return String(tx.originalID)
            }
        }
        return nil
    }

    // MARK: - Internal

    private func ensureProductsLoaded() async throws {
        guard loadedProducts.isEmpty else { return }
        let products = try await Product.products(for: productIDs)
        loadedProducts = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
    }

    private func refreshFromCurrentEntitlements() async {
        await Self.refreshFromCurrentEntitlementsStatic(productIDs: productIDs)
    }

    private static func refreshFromCurrentEntitlementsStatic(productIDs: [String]? = nil) async {
        let ids = productIDs ?? [
            "cashie_pro_monthly", "cashie_pro_yearly_v2"
        ]
        var active = false
        for await result in SKTransaction.currentEntitlements {
            if case .verified(let tx) = result, tx.revocationDate == nil {
                if ids.contains(tx.productID) {
                    active = true
                    break
                }
            }
        }
        UserDefaults.standard.set(active, forKey: Self.subscribedKey)
    }

    private func markSubscribed(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.subscribedKey)
    }

    private func offering(from product: Product) -> Offering {
        let isYearly = product.subscription?.subscriptionPeriod.unit == .year
        let monthlyEquivalent: String
        if isYearly {
            let perMonth = (product.price as Decimal) / 12
            monthlyEquivalent = "\(format(perMonth, currencyCode: product.priceFormatStyle.currencyCode)) / mo"
        } else {
            monthlyEquivalent = "\(product.displayPrice) / mo"
        }
        return Offering(
            id: product.id,
            displayTitle: product.displayName,
            displayPrice: product.displayPrice,
            billingPeriod: isYearly ? "year" : "month",
            monthlyEquivalent: monthlyEquivalent,
            oldPrice: nil
        )
    }

    private func format(_ value: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
