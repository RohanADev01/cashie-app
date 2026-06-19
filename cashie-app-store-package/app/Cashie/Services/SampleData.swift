import Foundation

/// Deterministic seed data used by the mock services and SwiftUI previews.
enum SampleData {
    static let transactions: [Transaction] = {
        let cal = Calendar.current
        func ago(_ days: Int, hour: Int = 12, minute: Int = 0) -> Date {
            let base = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }
        return [
            Transaction(merchant: "Don Antonio", amount: 18, category: .food, date: ago(0, hour: 19, minute: 12), source: .quicklog),
            Transaction(merchant: "Blue Bottle", amount: 5.50, category: .food, date: ago(0, hour: 9, minute: 41)),
            Transaction(merchant: "Lyft", amount: 14.20, category: .transport, date: ago(1, hour: 22, minute: 8)),
            Transaction(merchant: "Whole Foods", amount: 62.40, category: .food, date: ago(1, hour: 18, minute: 55)),
            Transaction(merchant: "Salary · Acme", amount: 3200, category: .income, date: ago(2, hour: 9), source: .bank),
            Transaction(merchant: "Uniqlo", amount: 78, category: .shopping, date: ago(3, hour: 14, minute: 22)),
            Transaction(merchant: "Netflix", amount: 15.99, category: .bills, date: ago(3, hour: 6)),
            Transaction(merchant: "Bar Belly", amount: 42, category: .fun, date: ago(4, hour: 22, minute: 30), source: .quicklog),
            Transaction(merchant: "Tartine", amount: 8.50, category: .food, date: ago(5, hour: 8, minute: 12)),
            Transaction(merchant: "Trader Joe's", amount: 38.10, category: .food, date: ago(5, hour: 19, minute: 4)),
            Transaction(merchant: "Spotify", amount: 11.99, category: .bills, date: ago(6)),
            Transaction(merchant: "Equinox", amount: 215, category: .health, date: ago(6, hour: 7, minute: 30)),
            Transaction(merchant: "Shake Shack", amount: 16.20, category: .food, date: ago(7, hour: 13, minute: 5)),
            // An isolated older log ~2 weeks before the recent cluster, so the
            // weeks in between have no activity. Lets us test the shield block
            // on an "empty week" (a week the user never logged in).
            Transaction(merchant: "Costco", amount: 84.30, category: .food, date: ago(20, hour: 15, minute: 10)),
        ]
    }()

    static let goals: [Goal] = [
        Goal(
            emoji: "🎮",
            name: "Nintendo Switch 2",
            targetAmount: 450,
            currentAmount: 252,
            targetDate: Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date(),
            deposits: [
                Deposit(amount: 50, date: Date().addingTimeInterval(-86400 * 5)),
                Deposit(amount: 80, date: Date().addingTimeInterval(-86400 * 14)),
                Deposit(amount: 122, date: Date().addingTimeInterval(-86400 * 28)),
            ]
        ),
        Goal(
            emoji: "✈️",
            name: "Tokyo trip",
            targetAmount: 2400,
            currentAmount: 540,
            targetDate: Calendar.current.date(byAdding: .month, value: 8, to: Date()) ?? Date()
        ),
        Goal(
            emoji: "🚑",
            name: "Emergency buffer",
            targetAmount: 1000,
            currentAmount: 720,
            targetDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        ),
    ]

    /// Notifications are emitted from real events (budget thresholds,
    /// streak milestones, weekly wrap availability). The sample seed is
    /// intentionally empty so first-launch users never see invented stats.
    static let notifications: [AppNotification] = []

    static let user: CashieUser = {
        var u = CashieUser()
        // No default name. Optionally captured during onboarding via
        // NameInputScreen. UIs that greet the user check `hasName`.
        u.archetype = .default
        return u
    }()
}
