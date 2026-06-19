import Foundation

/// Subscription gateway for the app. Backed by native StoreKit 2 in
/// production (`StoreKitService`); the app talks only to this protocol so the
/// purchase implementation can be swapped without touching the UI.
///
/// Cashie is StoreKit-only: there is no third-party purchase SDK. The `pro`
/// entitlement is resolved entirely from Apple's signed transactions via
/// `Transaction.currentEntitlements`.
protocol SubscriptionService: AnyObject {
    /// Last known subscription state (cached). Use `refreshSubscriptionStatus`
    /// to revalidate against StoreKit's current entitlements on launch.
    var isSubscribed: Bool { get }
    /// Re-reads the platform's current entitlements and returns the
    /// authoritative subscription state. Implementations also update
    /// `isSubscribed` as a side effect.
    func refreshSubscriptionStatus() async throws -> Bool
    func loadOfferings() async throws -> [Offering]
    /// Returns `.success` once Apple has confirmed the purchase, or
    /// `.cancelled` if the user dismissed the StoreKit sheet without paying.
    func purchase(_ offering: Offering) async throws -> PurchaseResult
    func restore() async throws -> Bool
    /// The `originalTransactionId` of the active Pro entitlement, if any. Sent to
    /// the `mint-quick-log-key` edge function so it can verify the subscription
    /// server-side via Apple's App Store Server API. `nil` when not subscribed.
    func proEntitlementToken() async -> String?
}

enum PurchaseResult: Equatable {
    case success
    case cancelled
}

struct Offering: Identifiable, Hashable {
    var id: String
    var displayTitle: String
    var displayPrice: String
    var billingPeriod: String
    var monthlyEquivalent: String
    var oldPrice: String?
}

/// In-memory / `UserDefaults`-backed test double used by SwiftUI previews and
/// QA. It never touches the App Store, so purchases "succeed" instantly. The
/// shipping app always uses `StoreKitService` instead (see `AppContainer`).
final class MockSubscriptionService: SubscriptionService {
    private static let key = "isSubscribed"
    var isSubscribed: Bool { UserDefaults.standard.bool(forKey: Self.key) }

    /// Toggle to simulate the "user closed the App Store sheet" code path.
    var nextPurchaseShouldCancel: Bool = false

    func refreshSubscriptionStatus() async throws -> Bool {
        // Simulate a tiny network roundtrip so SplashView animates while we wait.
        try? await Task.sleep(nanoseconds: 200_000_000)
        return UserDefaults.standard.bool(forKey: Self.key)
    }

    func loadOfferings() async throws -> [Offering] {
        // Mirrors the live StoreKit products and dashboard pricing
        // ($9.99/mo, $23.88/yr).
        [
            Offering(
                id: "cashie_pro_yearly",
                displayTitle: "Cashie Pro · Yearly",
                displayPrice: "$23.88",
                billingPeriod: "year",
                monthlyEquivalent: "$1.99 / mo",
                oldPrice: nil
            ),
            Offering(
                id: "cashie_pro_monthly",
                displayTitle: "Cashie Pro · Monthly",
                displayPrice: "$9.99",
                billingPeriod: "month",
                monthlyEquivalent: "$9.99 / mo",
                oldPrice: nil
            ),
        ]
    }

    func purchase(_ offering: Offering) async throws -> PurchaseResult {
        try? await Task.sleep(nanoseconds: 400_000_000)
        if nextPurchaseShouldCancel {
            nextPurchaseShouldCancel = false
            return .cancelled
        }
        UserDefaults.standard.set(true, forKey: Self.key)
        return .success
    }

    func restore() async throws -> Bool {
        // Pretend we found nothing; manual override in dev settings.
        UserDefaults.standard.set(false, forKey: Self.key)
        return false
    }

    /// No real StoreKit transaction exists in previews/QA, so there is no token
    /// to verify server-side.
    func proEntitlementToken() async -> String? { nil }
}
