import Foundation

/// The logging-and-shield streak that powers the Streak calendar screen.
///
/// This is a different idea from `derivedStreakDays` (which measures budget
/// pace and feeds the streak badges). Here a day "counts" if the user logged
/// a transaction that day OR spent a shield on it. The streak is the run of
/// counted days reaching back from today within the current calendar month.
///
/// Shields are the recovery mechanic: 6 per calendar week, redeemable only on
/// a missed day in a week the user actually logged something. The on-device
/// store is the source of truth (shields live in `AppSettings`), so nothing
/// here makes a network call.
extension AppContainer {

    static let shieldsPerWeek = 6

    // MARK: - Day keys

    func dayKey(_ date: Date) -> String { Self.dayKeyFormatter.string(from: date) }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Logged / shielded queries

    /// Every day with at least one logged transaction, as `yyyy-MM-dd` keys.
    /// Built once per access; callers in tight loops should cache it.
    var loggedDayKeys: Set<String> {
        Set(transactions.map { dayKey($0.date) })
    }

    func didLog(on day: Date) -> Bool {
        loggedDayKeys.contains(dayKey(day))
    }

    var shieldedDayKeys: Set<String> {
        Set(settings.shieldedDayKeys)
    }

    func isShielded(_ day: Date) -> Bool {
        shieldedDayKeys.contains(dayKey(day))
    }

    /// A day counts toward the streak if it was logged or shielded.
    func isCovered(_ day: Date) -> Bool {
        didLog(on: day) || isShielded(day)
    }

    // MARK: - The streak

    /// Consecutive covered days reaching back from today, crossing month
    /// boundaries and stopping at the first uncovered day (or the user's first
    /// ever logged day). Today not being logged yet doesn't break it: we start
    /// the count from yesterday in that case (the day isn't over).
    var loggedStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Floor the backward walk at the earliest day with ANY coverage (a log
        // OR a shield) so shielded days that reach back before the first logged
        // day are still counted. Using only the earliest transaction here was a
        // bug: shields below that floor were dropped from the streak.
        let shieldDates = settings.shieldedDayKeys.compactMap { Self.dayKeyFormatter.date(from: $0) }
        guard let earliest = (transactions.map(\.date) + shieldDates).min() else { return 0 }
        let firstDay = cal.startOfDay(for: earliest)

        var cursor = today
        if !isCovered(cursor) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while cursor >= firstDay, isCovered(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    // MARK: - Shield budget (per calendar week)

    private func sameWeek(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, equalTo: b, toGranularity: .weekOfYear)
    }

    /// True when the user logged at least one real transaction in `day`'s week.
    /// Shields can only be spent in a week they showed up for.
    func loggedInWeek(of day: Date) -> Bool {
        transactions.contains { sameWeek($0.date, day) }
    }

    func shieldsUsedInWeek(of day: Date) -> Int {
        settings.shieldedDayKeys
            .compactMap { Self.dayKeyFormatter.date(from: $0) }
            .filter { sameWeek($0, day) }
            .count
    }

    func shieldsRemainingInWeek(of day: Date) -> Int {
        max(0, Self.shieldsPerWeek - shieldsUsedInWeek(of: day))
    }

    /// Whether `day` can have a shield spent on it right now: any missed,
    /// non-future day (this month or earlier) in a week the user logged in,
    /// with shields still left that week.
    func canShield(_ day: Date) -> Bool {
        let cal = Calendar.current
        let d = cal.startOfDay(for: day)
        let today = cal.startOfDay(for: Date())
        guard d <= today else { return false }           // not in the future
        guard !didLog(on: d) else { return false }        // already a fire day
        guard !isShielded(d) else { return false }
        guard loggedInWeek(of: d) else { return false }   // must have logged that week
        guard shieldsRemainingInWeek(of: d) > 0 else { return false }  // 6 per week
        return true
    }

    /// Why a missed past day can't be shielded, for inline feedback. Returns
    /// nil when the day can actually be shielded, or isn't a missed past day.
    func shieldBlockReason(_ day: Date) -> String? {
        let cal = Calendar.current
        let d = cal.startOfDay(for: day)
        let today = cal.startOfDay(for: Date())
        guard d <= today, !didLog(on: d), !isShielded(d) else { return nil }
        if !loggedInWeek(of: d) { return "Log at least once that week to shield a day." }
        if shieldsRemainingInWeek(of: d) == 0 { return "No shields left that week (6 max)." }
        return nil
    }

    @discardableResult
    func redeemShield(_ day: Date) -> Bool {
        guard canShield(day) else { return false }
        settings.shieldedDayKeys.append(dayKey(day))   // persists via didSet
        return true
    }

    func removeShield(_ day: Date) {
        let k = dayKey(day)
        settings.shieldedDayKeys.removeAll { $0 == k }
    }
}
