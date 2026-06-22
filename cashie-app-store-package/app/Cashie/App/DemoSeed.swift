import Foundation

#if DEBUG
/// Demo / QA fixture. Populates a believable cross-month account so the whole
/// bills + income + Safe-to-Spend flow can be seen working end to end - including
/// the month rollover (last month's leftover pay carrying into this month).
///
/// Triggered by the `-seedDemo` launch argument. `CashieApp` wipes the store first
/// (so it stays idempotent across relaunches) and calls `apply(to:)` once bootstrap
/// has loaded the empty account. Never compiled into release builds, so the
/// shipping binary carries no demo data.
///
/// The story it tells (relative to "today"):
///   - A monthly salary of $2,800. Last month's payday auto-posts as realised
///     income; the next one is a few days out (the payday chip counts down to it).
///   - Three recurring bills: one already due this month (auto-posts as a tagged
///     "Recurring" spend), two still upcoming.
///   - Real spends across last month and this month, plus a saving goal.
/// The net effect: last month finished with money to spare, so this month's Safe
/// to Spend sits ABOVE the monthly budget - the rollover, made visible.
enum DemoSeed {
    @MainActor
    static func apply(to container: AppContainer) {
        let cal = Calendar.current
        let now = Date()
        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) ?? now
        }

        // 1. Monthly budget plan (caps reset on the 1st). Totals $1,200/mo.
        let caps: [(SpendCategory, Double)] = [
            (.food, 400), (.transport, 120), (.shopping, 150), (.fun, 120),
            (.home, 150), (.health, 60), (.bills, 150), (.other, 50),
        ]
        for (cat, cap) in caps { container.setBudget(category: cat, cap: cap) }

        // 2. Real spends. Last month (~3-6 weeks ago, safely in the previous
        //    calendar month) totals $900; this month totals $300. Offsets are
        //    chosen so each lands unambiguously in its month regardless of today's
        //    date within the month.
        let lastMonth: [(String, Double, SpendCategory, Int)] = [
            ("Woolworths", 260, .food, -40),
            ("Dinner out", 120, .food, -33),
            ("Opal top up", 70, .transport, -38),
            ("Uniqlo", 180, .shopping, -26),
            ("Cinema", 90, .fun, -30),
            ("IKEA", 110, .home, -35),
            ("Pharmacy", 30, .health, -28),
            ("Birthday gift", 40, .other, -24),
        ]
        let thisMonth: [(String, Double, SpendCategory, Int)] = [
            ("Woolworths", 140, .food, -17),
            ("Corner cafe", 48, .food, -10),
            ("Uber", 42, .transport, -14),
            ("Steam", 35, .fun, -5),
            ("Stationery", 35, .other, -3),
        ]
        for (m, a, c, d) in lastMonth + thisMonth {
            container.addTransaction(
                Transaction(merchant: m, amount: a, category: c, date: day(d), note: nil, source: .manual)
            )
        }

        // 3. Recurring income: monthly $2,800. Storing the payday ~4 weeks back
        //    means processDueRecurring posts last month's pay (realised income,
        //    tagged "Recurring") and rolls the next payday a few days into the
        //    future, so the chip reads "Payday in N days".
        IncomeStore.shared.set(
            Income(name: "Salary", amount: 2800, frequency: .monthly, nextPayday: day(-25))
        )

        // 4. Recurring bills. Spotify is already due this month (auto-posts as a
        //    tagged spend); the gym and internet are still upcoming.
        BillsStore.shared.add(
            RecurringBill(name: "Spotify", amount: 11.99, category: .bills, nextDue: day(-12), frequency: .monthly)
        )
        BillsStore.shared.add(
            RecurringBill(name: "Gym", amount: 30, category: .health, nextDue: day(5), frequency: .monthly)
        )
        BillsStore.shared.add(
            RecurringBill(name: "Internet", amount: 79, category: .bills, nextDue: day(13), frequency: .monthly)
        )

        // 5. Post everything whose date has already passed: last month's payday and
        //    the Spotify bill land as real, "Recurring"-tagged transactions.
        container.processDueRecurring()

        // 6. A saving goal with deposits in each month (a budget outflow either way).
        let japan = Goal(
            emoji: "✈️",
            name: "Japan trip",
            targetAmount: 3000,
            currentAmount: 500,
            targetDate: day(150),
            deposits: [
                Deposit(amount: 300, date: day(-34)),
                Deposit(amount: 200, date: day(-19)),
            ]
        )
        container.saveGoal(japan)
    }
}
#endif
