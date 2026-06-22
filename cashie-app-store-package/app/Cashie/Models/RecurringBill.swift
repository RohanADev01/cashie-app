import Foundation

/// A recurring bill (rent, Netflix, gym...). Surfaced on Today and reduces the
/// month's Safe to Spend by whatever's due before the next pay/period boundary.
///
/// PROTOTYPE NOTE
/// --------------
/// In v1 this is held in memory by `BillsStore` only. There is NO file
/// persistence and NO Supabase sync. Killing the app loses the user's bills.
/// `major-changes-v1/NEXT_STEPS.md` covers wiring this into `LocalStore`
/// (one new `Key`, one load/save call in `AppContainer`) and the Supabase
/// table when we lift the prototype to real storage.
struct RecurringBill: Identifiable, Codable, Hashable {
    enum Frequency: String, CaseIterable, Codable, Hashable {
        case weekly
        case fortnightly
        case monthly
        case yearly

        var label: String {
            switch self {
            case .weekly: return "Weekly"
            case .fortnightly: return "Fortnightly"
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }

        /// Step the date forward by exactly one cycle. Used after "Mark paid"
        /// to roll `nextDue` to the next occurrence.
        func next(after date: Date, calendar: Calendar = .current) -> Date {
            switch self {
            case .weekly:
                return calendar.date(byAdding: .day, value: 7, to: date) ?? date
            case .fortnightly:
                return calendar.date(byAdding: .day, value: 14, to: date) ?? date
            case .monthly:
                return calendar.date(byAdding: .month, value: 1, to: date) ?? date
            case .yearly:
                return calendar.date(byAdding: .year, value: 1, to: date) ?? date
            }
        }
    }

    var id: UUID = UUID()
    var name: String
    var amount: Double
    var category: SpendCategory
    var nextDue: Date
    var frequency: Frequency
    var isActive: Bool = true
    var createdAt: Date = Date()
    /// Day-of-month (1...31) the user anchored this bill to. Monthly/yearly rolls
    /// re-anchor to it so an end-of-month bill (e.g. the 31st) doesn't permanently
    /// collapse to the 28th once it crosses February. Defaults to the day of the
    /// first `nextDue`. Recompute it whenever `nextDue` is edited.
    var anchorDay: Int = 1

    init(id: UUID = UUID(), name: String, amount: Double, category: SpendCategory,
         nextDue: Date, frequency: Frequency, isActive: Bool = true,
         createdAt: Date = Date(), anchorDay: Int? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.nextDue = nextDue
        self.frequency = frequency
        self.isActive = isActive
        self.createdAt = createdAt
        self.anchorDay = anchorDay ?? Calendar.current.component(.day, from: nextDue)
    }

    /// The occurrence exactly one cycle after `date`. Weekly/fortnightly step by
    /// days; monthly/yearly step the month/year and then re-anchor the day to
    /// `anchorDay` (clamped to the target month's length), so the 29th-31st are
    /// preserved instead of drifting to the 28th after February. Use this instead
    /// of `frequency.next(after:)` everywhere a stored date rolls forward.
    func occurrence(after date: Date, calendar: Calendar = .current) -> Date {
        switch frequency {
        case .weekly, .fortnightly:
            return frequency.next(after: date, calendar: calendar)
        case .monthly, .yearly:
            let comp: DateComponents = frequency == .monthly
                ? DateComponents(month: 1) : DateComponents(year: 1)
            guard let stepped = calendar.date(byAdding: comp, to: date) else {
                return frequency.next(after: date, calendar: calendar)
            }
            return RecurringBill.reanchorDay(of: stepped, to: anchorDay, calendar: calendar)
        }
    }

    /// Rebuild `date` with its day component set to `min(day, daysInThatMonth)`,
    /// keeping its year and month. Clamping keeps Feb (and 30-day months) valid.
    static func reanchorDay(of date: Date, to day: Int, calendar: Calendar = .current) -> Date {
        let maxDay = calendar.range(of: .day, in: .month, for: date)?.count ?? 28
        var dc = calendar.dateComponents([.year, .month], from: date)
        dc.day = min(max(day, 1), maxDay)
        return calendar.date(from: dc) ?? date
    }

    /// Human-friendly "Due in 4 days" / "Due tomorrow" / "Due today" / "3 days
    /// overdue". Reference date defaults to now and is injectable for tests.
    func dueLabel(now: Date = Date(), calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: now)
        let due = calendar.startOfDay(for: nextDue)
        let days = calendar.dateComponents([.day], from: start, to: due).day ?? 0
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days > 1 { return "Due in \(days) days" }
        if days == -1 { return "1 day overdue" }
        return "\(abs(days)) days overdue"
    }

    /// Days until due (negative = overdue). Used for sorting and the
    /// 14-day Upcoming Bills window.
    func daysUntilDue(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: now)
        let due = calendar.startOfDay(for: nextDue)
        return calendar.dateComponents([.day], from: start, to: due).day ?? 0
    }
}
