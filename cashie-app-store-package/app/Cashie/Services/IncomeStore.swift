import Foundation
import Combine

/// On-device store for the user's single income source.
///
/// PERSISTENCE
/// -----------
/// Mirrors `BillsStore`: the income is saved to `LocalStore` on every change and
/// loaded on launch, so it survives relaunches. Local-only — the paydays it
/// auto-posts sync through the normal transaction path, while the income rule
/// itself stays on the device. Starts empty (no income) on a fresh install, so
/// Today and Safe to Spend behave exactly as before until the user sets one.
@MainActor
final class IncomeStore: ObservableObject {
    static let shared = IncomeStore()

    @Published private(set) var income: Income? {
        didSet {
            if let income {
                LocalStore.shared.save(income, key: LocalStore.Key.income)
            } else {
                LocalStore.shared.remove(key: LocalStore.Key.income)
            }
        }
    }

    private init() {
        // didSet does not fire during init, so this load never triggers a save.
        self.income = LocalStore.shared.load(Income.self, key: LocalStore.Key.income)
    }

    // MARK: - Mutations

    func set(_ income: Income) {
        self.income = income
    }

    func clear() {
        self.income = nil
    }

    // MARK: - Reads

    /// Days until the next payday, or nil when there's no active income.
    func daysUntilPayday(now: Date = Date()) -> Int? {
        guard let inc = income, inc.isActive else { return nil }
        return inc.daysUntilPayday(now: now)
    }

    // MARK: - Auto-post

    /// Roll the payday forward for every cycle that has already passed (strictly
    /// before today), returning one payment per missed payday for the caller to
    /// post as a real income transaction. Pay only affects Safe to Spend once it
    /// has actually landed; upcoming pay is not counted. Idempotent.
    func collectDuePaydays(now: Date = Date()) -> [(name: String, amount: Double, date: Date)] {
        guard var inc = income, inc.isActive else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var due = cal.startOfDay(for: inc.nextPayday)
        var out: [(name: String, amount: Double, date: Date)] = []
        var rolled = 0
        while due < today && rolled < 60 {
            out.append((inc.name, inc.amount, due))
            due = inc.occurrence(after: due)
            rolled += 1
        }
        if rolled > 0 {
            inc.nextPayday = due
            income = inc
        }
        return out
    }
}
