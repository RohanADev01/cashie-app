import Foundation

/// User-controlled toggles that live alongside the user profile but aren't
/// part of identity. Persisted with the rest of the local store.
struct AppSettings: Codable, Hashable {
    var privacyLockEnabled: Bool = false
    var dailyReminderEnabled: Bool = false
    /// 24-hour clock (0..<24) for the local daily reminder.
    var dailyReminderHour: Int = 20
    var dailyReminderMinute: Int = 0

    /// Highest rank the user has already been shown a celebration for, stored
    /// as `Rank.rawValue`. `-1` means "not yet initialised": on first launch
    /// we seed it to the current rank silently so existing activity doesn't
    /// trigger a surprise celebration. After that, crossing into a higher
    /// tier fires the rank-up screen exactly once.
    var lastSeenRankRaw: Int = -1

    /// IDs of badges the user has already seen the unlock animation for. New
    /// unlocks (not in this list) fire the badge celebration once, then get
    /// added here. Seeded with whatever's already unlocked on first launch.
    var celebratedBadgeIDs: [String] = []
    /// Whether `celebratedBadgeIDs` has been seeded against loaded data, so we
    /// don't celebrate pre-existing badges on the very first launch.
    var badgeBaselineSeeded: Bool = false

    /// Days the user has spent a "shield" on to keep their logging streak
    /// alive, stored as `yyyy-MM-dd` keys. The local store is the source of
    /// truth (no extra DB round-trips); these sync with the rest of settings.
    /// See `StreakEngine` for the redemption rules (6 per week, only in a week
    /// the user actually logged in).
    var shieldedDayKeys: [String] = []
}
