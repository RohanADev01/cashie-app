import Foundation

struct Goal: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var emoji: String
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: Date
    var deposits: [Deposit] = []
    /// Set when the user marks a completed goal as "celebrated/archived" so
    /// it disappears from the active list and lands in Past wins.
    var archivedAt: Date? = nil

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1, currentAmount / targetAmount)
    }

    var remaining: Double { max(0, targetAmount - currentAmount) }

    var isAchieved: Bool { currentAmount >= targetAmount && targetAmount > 0 }

    var isArchived: Bool { archivedAt != nil }

    var weeklyPace: Double {
        let weeks = max(
            1,
            Calendar.current.dateComponents([.weekOfYear], from: Date(), to: targetDate).weekOfYear ?? 1
        )
        return remaining / Double(weeks)
    }
}

struct Deposit: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var amount: Double
    var date: Date
    var addedBy: String = "You"
}
