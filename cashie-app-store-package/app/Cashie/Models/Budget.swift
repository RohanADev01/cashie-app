import Foundation

/// One per category, what the user has set as their monthly cap.
/// The amount used in any given period is computed from `transactions`.
struct CategoryBudget: Identifiable, Codable, Hashable {
    var id: SpendCategory { category }
    var category: SpendCategory
    var monthlyCap: Double
}

extension CategoryBudget {
    /// Default monthly cap applied to every category on a fresh install.
    static let defaultCap: Double = 100

    /// Shipped default: every spendable (non-income) category starts at
    /// `defaultCap`/mo on a fresh install and stays there until the user
    /// changes it manually — their value is then persisted and reused. A
    /// category with no entry counts as 0 (see the `?? 0` cap lookups).
    static let seed: [CategoryBudget] =
        SpendCategory.allCases
            .filter { $0 != .income }
            .map { CategoryBudget(category: $0, monthlyCap: defaultCap) }
}
