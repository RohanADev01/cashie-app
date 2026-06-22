import Foundation
import Combine

/// On-device store for the user's recurring bills.
///
/// PERSISTENCE
/// -----------
/// Bills are saved to `LocalStore` (the same JSON-on-disk store the rest of the
/// app uses) on every change and loaded on launch, so they survive relaunches.
/// This is local-only: the transactions a bill auto-posts sync through the normal
/// transaction path, while the rule definition itself stays on the device. Starts
/// empty on a fresh install (no seed), so the Today/Bills surfaces self-hide until
/// the user adds real content.
@MainActor
final class BillsStore: ObservableObject {
    static let shared = BillsStore()

    @Published private(set) var bills: [RecurringBill] {
        didSet { LocalStore.shared.save(bills, key: LocalStore.Key.bills) }
    }

    private init() {
        // didSet does not fire during init, so this load never triggers a save.
        self.bills = LocalStore.shared.load([RecurringBill].self, key: LocalStore.Key.bills) ?? []
    }

    // MARK: - Reads

    /// Active bills due in `[today, today + window]`, soonest first.
    /// Used by the Today UpcomingBills card and by the Safe to Spend math.
    func upcoming(within days: Int = 14, now: Date = Date()) -> [RecurringBill] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: now)) ?? now
        return bills
            .filter { $0.isActive && $0.nextDue <= cutoff }
            .sorted { $0.nextDue < $1.nextDue }
    }

    /// Sum of active bills with their next due date before the end of the current
    /// calendar month. Display only: powers the "Due this month" total on the
    /// Bills list sheet. NOT part of Safe to Spend - bills affect that only once
    /// their date passes and they post as real transactions (see
    /// `AppContainer.processDueRecurring` / `collectDuePayments`).
    func upcomingThisMonth(now: Date = Date()) -> Double {
        let cal = Calendar.current
        guard let monthEnd = cal.dateInterval(of: .month, for: now)?.end else { return 0 }
        return bills
            .filter { $0.isActive && $0.nextDue < monthEnd }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Mutations

    func add(_ bill: RecurringBill) {
        bills.insert(bill, at: 0)
    }

    func update(_ bill: RecurringBill) {
        guard let idx = bills.firstIndex(where: { $0.id == bill.id }) else { return }
        bills[idx] = bill
    }

    func delete(_ id: UUID) {
        bills.removeAll { $0.id == id }
    }

    func setActive(_ id: UUID, active: Bool) {
        guard let idx = bills.firstIndex(where: { $0.id == id }) else { return }
        bills[idx].isActive = active
    }

    /// Mark a bill as paid: rolls `nextDue` forward one cycle. The caller can
    /// also choose to log an associated Transaction (BillDetailSheet does that
    /// via AppContainer.addTransaction); this method only advances the cycle.
    func markPaid(_ id: UUID) {
        guard let idx = bills.firstIndex(where: { $0.id == id }) else { return }
        let bill = bills[idx]
        bills[idx].nextDue = bill.occurrence(after: bill.nextDue)
    }

    /// Roll every active bill whose due date has already passed (strictly before
    /// today) forward, returning one payment per missed cycle for the caller to
    /// post as a real transaction. A bill only affects spending once its date
    /// passes; nothing is reserved ahead of time. Idempotent: rolling the date
    /// forward means a second call won't re-post the same cycle.
    func collectDuePayments(now: Date = Date()) -> [(name: String, amount: Double, category: SpendCategory, date: Date)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var out: [(name: String, amount: Double, category: SpendCategory, date: Date)] = []
        for idx in bills.indices where bills[idx].isActive {
            var due = cal.startOfDay(for: bills[idx].nextDue)
            var rolled = 0
            while due < today && rolled < 60 {
                out.append((bills[idx].name, bills[idx].amount, bills[idx].category, due))
                due = bills[idx].occurrence(after: due)
                rolled += 1
            }
            if rolled > 0 { bills[idx].nextDue = due }
        }
        return out
    }
}
