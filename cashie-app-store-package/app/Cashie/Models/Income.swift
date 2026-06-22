import Foundation

/// The user's single income source (salary or wage). One income by design: no
/// multi-source array, just an optional `Income?` on `IncomeStore`. Powers the
/// Today payday chip and the income-aware Safe to Spend.
///
/// PROTOTYPE NOTE
/// --------------
/// Held in memory by `IncomeStore` only. No file persistence, no Supabase sync.
/// Killing the app loses it. See `major-changes-v1/income/NEXT_STEPS.md` for the
/// LocalStore wiring (one Key, one load/save) when we lift this to real storage.
struct Income: Identifiable, Codable, Hashable {
    enum Frequency: String, CaseIterable, Codable, Hashable {
        case weekly
        case fortnightly
        case monthly

        var label: String {
            switch self {
            case .weekly: return "Weekly"
            case .fortnightly: return "Fortnightly"
            case .monthly: return "Monthly"
            }
        }

        /// Step a payday forward by exactly one cycle.
        func next(after date: Date, calendar: Calendar = .current) -> Date {
            switch self {
            case .weekly: return calendar.date(byAdding: .day, value: 7, to: date) ?? date
            case .fortnightly: return calendar.date(byAdding: .day, value: 14, to: date) ?? date
            case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
            }
        }
    }

    var id: UUID = UUID()
    var name: String
    var amount: Double
    var frequency: Frequency
    var nextPayday: Date
    var isActive: Bool = true
    var createdAt: Date = Date()
    /// Day-of-month (1...31) the payday is anchored to. Monthly pay re-anchors to
    /// it so an end-of-month salary (e.g. the 31st) doesn't drift to the 28th once
    /// it crosses February. Defaults to the day of the first `nextPayday`.
    /// Recompute it whenever `nextPayday` is edited.
    var anchorDay: Int = 1

    init(id: UUID = UUID(), name: String, amount: Double, frequency: Frequency,
         nextPayday: Date, isActive: Bool = true, createdAt: Date = Date(),
         anchorDay: Int? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.nextPayday = nextPayday
        self.isActive = isActive
        self.createdAt = createdAt
        self.anchorDay = anchorDay ?? Calendar.current.component(.day, from: nextPayday)
    }

    /// The payday exactly one cycle after `date`. Weekly/fortnightly step by days;
    /// monthly steps the month and re-anchors the day to `anchorDay` (clamped to
    /// the month's length), so end-of-month paydays don't drift to the 28th. Use
    /// this instead of `frequency.next(after:)` wherever a stored payday rolls on.
    func occurrence(after date: Date, calendar: Calendar = .current) -> Date {
        switch frequency {
        case .weekly, .fortnightly:
            return frequency.next(after: date, calendar: calendar)
        case .monthly:
            guard let stepped = calendar.date(byAdding: DateComponents(month: 1), to: date) else {
                return frequency.next(after: date, calendar: calendar)
            }
            return Income.reanchorDay(of: stepped, to: anchorDay, calendar: calendar)
        }
    }

    /// Rebuild `date` with its day set to `min(day, daysInThatMonth)`, keeping its
    /// year and month. Clamping keeps Feb (and 30-day months) valid.
    static func reanchorDay(of date: Date, to day: Int, calendar: Calendar = .current) -> Date {
        let maxDay = calendar.range(of: .day, in: .month, for: date)?.count ?? 28
        var dc = calendar.dateComponents([.year, .month], from: date)
        dc.day = min(max(day, 1), maxDay)
        return calendar.date(from: dc) ?? date
    }

    /// The next payday on or after today. Rolls the stored date forward by whole
    /// cycles if it has slipped into the past, so the chip and the Safe to Spend
    /// math stay correct without a background timer advancing `nextPayday`.
    func effectiveNextPayday(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        var pay = calendar.startOfDay(for: nextPayday)
        var guardCount = 0
        while pay < today && guardCount < 1040 {           // 1040 weeks ≈ 20 years
            pay = occurrence(after: pay, calendar: calendar)
            guardCount += 1
        }
        return pay
    }

    /// Whole days until the next payday (0 = today).
    func daysUntilPayday(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let pay = effectiveNextPayday(now: now, calendar: calendar)
        return calendar.dateComponents([.day], from: today, to: pay).day ?? 0
    }

    /// "Payday today" / "Payday tomorrow" / "Payday in 6 days".
    func paydayLabel(now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = daysUntilPayday(now: now, calendar: calendar)
        if days <= 0 { return "Payday today" }
        if days == 1 { return "Payday tomorrow" }
        return "Payday in \(days) days"
    }
}
