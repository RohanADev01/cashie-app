import Foundation

/// A queued full-screen (or sheet) celebration: a badge unlock, a rank-up, or a
/// goal being funded. Owned and driven by `AppContainer` so detection happens at
/// the data layer (not in a single tab's view) and plays no matter which screen
/// the user is on. `MainTabsView` is the single presenter.
enum Celebration: Identifiable {
    case rank(Rank)
    case badge(Badge)
    case goal(Goal)

    var id: String {
        switch self {
        case .rank(let r): return "rank-\(r.rawValue)"
        case .badge(let b): return "badge-\(b.id)"
        case .goal(let g): return "goal-\(g.id.uuidString)"
        }
    }
}

/// Rank XP is derived from real activity, the same way the streak and
/// "total saved" stats are. Keeping it derived (rather than a stored
/// counter) means it can never drift away from what the user actually did,
/// and there's no migration to worry about.
extension AppContainer {

    /// Number of goal deposits banked across every goal.
    var derivedDepositCount: Int {
        goals.reduce(0) { $0 + $1.deposits.count }
    }

    /// Goals that have hit their target.
    var derivedFundedGoalCount: Int {
        goals.filter { $0.isAchieved }.count
    }

    /// Cumulative XP that drives the user's rank: the sum of XP from every
    /// badge unlocked. Badges cover logging, saving, deposits, funding goals,
    /// streaks and loyalty in fine tiers, so this only ever grows and maps
    /// cleanly onto the rank thresholds.
    var rankXP: Int {
        #if DEBUG
        // Dev affordance: `-rankXP <n>` forces the XP total so the rank screen
        // can be previewed at any tier in the simulator. Compiled out of release.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-rankXP"), i + 1 < args.count,
           let forced = Int(args[i + 1]) {
            return forced
        }
        #endif
        return unlockedBadgeXP
    }

    /// Where the user sits on the ladder right now.
    var rankProgress: RankProgress {
        Rank.progress(forXP: rankXP)
    }

    var currentRank: Rank { rankProgress.current }

    // MARK: - Badges

    /// Current raw value toward a badge (uncapped).
    func badgeMetric(_ b: Badge) -> Int { b.metric(self) }

    /// Whether the badge has been earned. Money badges compare against the
    /// currency-adjusted threshold (see `Badge.currentTarget`).
    func isBadgeUnlocked(_ b: Badge) -> Bool { b.metric(self) >= b.currentTarget }

    /// 0...1 progress toward a badge.
    func badgeFraction(_ b: Badge) -> Double {
        let target = b.currentTarget
        guard target > 0 else { return 1 }
        return min(1, max(0, Double(b.metric(self)) / Double(target)))
    }

    /// "12 / 25" or "₹3,00,000 / ₹3,00,000" depending on the badge.
    func badgeProgressText(_ b: Badge) -> String {
        let target = b.currentTarget
        let current = min(b.metric(self), target)
        if b.isMoney {
            return "\(Money.format(Double(current))) / \(Money.format(Double(target)))"
        }
        return "\(current) / \(target)"
    }

    var unlockedBadges: [Badge] { Badge.all.filter { isBadgeUnlocked($0) } }
    var earnedBadgeCount: Int { unlockedBadges.count }
    var unlockedBadgeXP: Int { unlockedBadges.reduce(0) { $0 + $1.xp } }

    // MARK: - Achievement detection

    /// Auto-checks for newly earned badges and rank-ups and queues a
    /// celebration for each. Baselines are seeded in `bootstrap()` once real
    /// data is loaded, so nothing fires on the initial load, only on genuine
    /// new achievements. Badges play before the rank-up they triggered.
    ///
    /// This is the single entry point for badge/rank detection: every data
    /// mutation, every remote/intent sync merge, and every foreground calls it,
    /// so an earned badge is celebrated no matter which screen the user is on.
    /// Safe to call repeatedly - already-celebrated achievements are skipped.
    func evaluateAchievements() {
        guard !isBootstrapping, settings.badgeBaselineSeeded else { return }

        // During the cold-launch settling window celebrations aren't armed yet.
        // Fold whatever is already unlocked into the baseline (badges and the
        // current rank) so a relaunch never replays an old celebration, then
        // return without showing anything. Once armed (shortly after launch),
        // only achievements newly crossed from here on will celebrate.
        guard achievementsArmed else {
            settings.celebratedBadgeIDs = unlockedBadges.map { $0.id }
            if currentRank.rawValue > settings.lastSeenRankRaw {
                settings.lastSeenRankRaw = currentRank.rawValue
            }
            return
        }

        var pending: [Celebration] = []

        let seen = Set(settings.celebratedBadgeIDs)
        let fresh = unlockedBadges.filter { !seen.contains($0.id) }
        if !fresh.isEmpty {
            settings.celebratedBadgeIDs.append(contentsOf: fresh.map { $0.id })
            pending.append(contentsOf: fresh.map { Celebration.badge($0) })
        }

        let lastRaw = settings.lastSeenRankRaw
        if lastRaw >= 0 {
            let current = currentRank
            if current.rawValue > lastRaw {
                settings.lastSeenRankRaw = current.rawValue
                pending.append(.rank(current))
            }
        }

        enqueueCelebrations(pending)
    }
}
