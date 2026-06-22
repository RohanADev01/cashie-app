import Foundation

enum SpendCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case food
    case transport
    case shopping
    case fun
    case home
    case health
    case bills
    case income
    case other

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .food: return "🥡"
        case .transport: return "🚆"
        case .shopping: return "🛍"
        case .fun: return "🎉"
        case .home: return "🏡"
        case .health: return "😷"
        case .bills: return "🧾"
        case .income: return "💵"
        case .other: return "✦"
        }
    }

    var label: String {
        switch self {
        case .food: return "Food & Drinks"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .fun: return "Fun"
        case .home: return "Home"
        case .health: return "Health"
        case .bills: return "Bills"
        case .income: return "Income"
        case .other: return "Other"
        }
    }
}

struct Transaction: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var merchant: String
    var amount: Double
    var category: SpendCategory
    var date: Date
    var note: String?
    /// Where this came from, quicklog (back-tap), manual, automation.
    var source: Source = .manual

    enum Source: String, Codable, Hashable, Sendable {
        case manual
        case quicklog
        case automation
        case bank
    }

    var isIncome: Bool { category == .income || amount < 0 }

    var signedAmount: Double {
        category == .income ? abs(amount) : -abs(amount)
    }
}
