import SwiftUI

/// An achievement the user unlocks by actually using the app. Badges are the
/// fun, legible face of progression: each one is tied to a real usage signal
/// (logging, keeping a streak, saving toward a goal, finishing goals, sticking
/// around) and awards XP that feeds the rank. Tiers are fine-grained so there's
/// always a next one within reach.
///
/// `metric` reads the current value toward the badge from the container, and
/// the badge is unlocked once it reaches `target`. It's a pure definition;
/// the per-user math (progress, unlocked, XP totals) lives on AppContainer.
struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let xp: Int
    let tint: Color
    let target: Int
    /// When true, progress is shown as money (e.g. "$520 / $1,000").
    let isMoney: Bool
    /// Current raw value toward the target, read from live data.
    let metric: @MainActor (AppContainer) -> Int

    init(id: String, title: String, detail: String, icon: String, xp: Int,
         tint: Color, target: Int, isMoney: Bool = false,
         metric: @escaping @MainActor (AppContainer) -> Int) {
        self.id = id
        self.title = title
        self.detail = detail
        self.icon = icon
        self.xp = xp
        self.tint = tint
        self.target = target
        self.isMoney = isMoney
        self.metric = metric
    }
}

extension Badge {
    // Accent colours, one per family, so the grid reads with variety.
    static let cLog = Theme.Palette.gold            // logging
    static let cSave = Color(hex: 0x12B5A6)         // saving totals
    static let cGoal = Theme.Palette.winGold        // funding goals
    static let cDeposit = Color(hex: 0x8A63E8)      // deposits
    static let cFlame = Color(hex: 0xFF7A2E)        // streaks
    static let cBlue = Color(hex: 0x3BA0E0)         // loyalty

    @MainActor private static func logs(_ c: AppContainer) -> Int { c.transactions.count }
    @MainActor private static func saved(_ c: AppContainer) -> Int { Int(c.derivedTotalSaved) }
    @MainActor private static func funded(_ c: AppContainer) -> Int { c.derivedFundedGoalCount }
    @MainActor private static func deposits(_ c: AppContainer) -> Int { c.derivedDepositCount }
    // The visible logging streak (a day counts if it was logged OR shielded),
    // so spending a shield to save a streak also keeps these badges progressing.
    @MainActor private static func streak(_ c: AppContainer) -> Int { c.loggedStreak }
    @MainActor private static func months(_ c: AppContainer) -> Int { c.derivedMonthsActive }

    // MARK: - Families (fine tiers, all achievable)

    // Targets calibrated to a realistic ~3-4 logs/week user (XP unchanged).
    private static let logging: [Badge] = [
        Badge(id: "log_1", title: "First Move", detail: "Log your first purchase.", icon: "bolt.fill", xp: 12, tint: cLog, target: 1, metric: { logs($0) }),
        Badge(id: "log_5", title: "Getting Started", detail: "Log 3 purchases.", icon: "plus.circle.fill", xp: 18, tint: cLog, target: 3, metric: { logs($0) }),
        Badge(id: "log_10", title: "Getting Going", detail: "Log 7 purchases.", icon: "list.bullet", xp: 24, tint: cLog, target: 7, metric: { logs($0) }),
        Badge(id: "log_15", title: "Warmed Up", detail: "Log 12 purchases.", icon: "list.bullet", xp: 30, tint: cLog, target: 12, metric: { logs($0) }),
        Badge(id: "log_25", title: "Tracker", detail: "Log 20 purchases.", icon: "list.bullet.rectangle.fill", xp: 40, tint: cLog, target: 20, metric: { logs($0) }),
        Badge(id: "log_50", title: "Dedicated", detail: "Log 30 purchases.", icon: "square.stack.3d.up.fill", xp: 65, tint: cLog, target: 30, metric: { logs($0) }),
        Badge(id: "log_75", title: "Diligent Logger", detail: "Log 45 purchases.", icon: "square.stack.3d.up.fill", xp: 90, tint: cLog, target: 45, metric: { logs($0) }),
        Badge(id: "log_100", title: "Logbook", detail: "Log 65 purchases.", icon: "books.vertical.fill", xp: 115, tint: cLog, target: 65, metric: { logs($0) }),
        Badge(id: "log_150", title: "Bookkeeper", detail: "Log 90 purchases.", icon: "books.vertical.fill", xp: 150, tint: cLog, target: 90, metric: { logs($0) }),
        Badge(id: "log_250", title: "Archivist", detail: "Log 130 purchases.", icon: "tray.full.fill", xp: 210, tint: cLog, target: 130, metric: { logs($0) }),
        Badge(id: "log_400", title: "Ledger Lord", detail: "Log 200 purchases.", icon: "tray.full.fill", xp: 300, tint: cLog, target: 200, metric: { logs($0) }),
        Badge(id: "log_600", title: "Power Logger", detail: "Log 300 purchases.", icon: "shippingbox.fill", xp: 420, tint: cLog, target: 300, metric: { logs($0) }),
    ]

    private static let saving: [Badge] = [
        Badge(id: "save_50", title: "Pocket Change", detail: "Save $40 across goals.", icon: "banknote", xp: 18, tint: cSave, target: 40, isMoney: true, metric: { saved($0) }),
        Badge(id: "save_100", title: "Piggy Bank", detail: "Save $80 across goals.", icon: "banknote", xp: 28, tint: cSave, target: 80, isMoney: true, metric: { saved($0) }),
        Badge(id: "save_250", title: "Saver", detail: "Save $150 across goals.", icon: "dollarsign.circle", xp: 45, tint: cSave, target: 150, isMoney: true, metric: { saved($0) }),
        Badge(id: "save_500", title: "Nest Egg", detail: "Save $250 across goals.", icon: "dollarsign.circle.fill", xp: 65, tint: cSave, target: 250, isMoney: true, metric: { saved($0) }),
        Badge(id: "save_1000", title: "Rainy Day", detail: "Save $400 across goals.", icon: "dollarsign.circle.fill", xp: 100, tint: cSave, target: 400, isMoney: true, metric: { saved($0) }),
        Badge(id: "save_2000", title: "Cushion", detail: "Save $700 across goals.", icon: "creditcard.fill", xp: 150, tint: cSave, target: 700, isMoney: true, metric: { saved($0) }),
        Badge(id: "save_3500", title: "Safety Net", detail: "Save $1,100 across goals.", icon: "creditcard.fill", xp: 210, tint: cSave, target: 1100, isMoney: true, metric: { saved($0) }),
        Badge(id: "save_5000", title: "Big Saver", detail: "Save $1,700 across goals.", icon: "wallet.pass.fill", xp: 290, tint: cSave, target: 1700, isMoney: true, metric: { saved($0) }),
        Badge(id: "save_7500", title: "War Chest", detail: "Save $2,500 across goals.", icon: "wallet.pass.fill", xp: 400, tint: cSave, target: 2500, isMoney: true, metric: { saved($0) }),
        Badge(id: "save_10000", title: "Vault", detail: "Save $3,600 across goals.", icon: "building.columns.fill", xp: 560, tint: cSave, target: 3600, isMoney: true, metric: { saved($0) }),
    ]

    private static let depositsFamily: [Badge] = [
        Badge(id: "deposit_1", title: "Squirrel", detail: "Make your first goal deposit.", icon: "banknote.fill", xp: 18, tint: cDeposit, target: 1, metric: { deposits($0) }),
        Badge(id: "deposit_3", title: "Stasher", detail: "Make 2 goal deposits.", icon: "arrow.down.circle.fill", xp: 32, tint: cDeposit, target: 2, metric: { deposits($0) }),
        Badge(id: "deposit_5", title: "Collector", detail: "Make 3 goal deposits.", icon: "arrow.down.circle.fill", xp: 50, tint: cDeposit, target: 3, metric: { deposits($0) }),
        Badge(id: "deposit_10", title: "Diligent", detail: "Make 5 goal deposits.", icon: "square.and.arrow.down.fill", xp: 85, tint: cDeposit, target: 5, metric: { deposits($0) }),
        Badge(id: "deposit_20", title: "Committed", detail: "Make 8 goal deposits.", icon: "square.and.arrow.down.fill", xp: 140, tint: cDeposit, target: 8, metric: { deposits($0) }),
        Badge(id: "deposit_35", title: "Devoted", detail: "Make 14 goal deposits.", icon: "tray.and.arrow.down.fill", xp: 220, tint: cDeposit, target: 14, metric: { deposits($0) }),
        Badge(id: "deposit_60", title: "Machine", detail: "Make 24 goal deposits.", icon: "tray.and.arrow.down.fill", xp: 360, tint: cDeposit, target: 24, metric: { deposits($0) }),
    ]

    private static let goalsFamily: [Badge] = [
        Badge(id: "goal_1", title: "Goal Getter", detail: "Fully fund your first goal.", icon: "flag.checkered", xp: 80, tint: cGoal, target: 1, metric: { funded($0) }),
        Badge(id: "goal_2", title: "Double Up", detail: "Fully fund 2 goals.", icon: "flag.2.crossed.fill", xp: 120, tint: cGoal, target: 2, metric: { funded($0) }),
        Badge(id: "goal_3", title: "Finisher", detail: "Fully fund 3 goals.", icon: "trophy.fill", xp: 170, tint: cGoal, target: 3, metric: { funded($0) }),
        Badge(id: "goal_5", title: "On a Roll", detail: "Fully fund 4 goals.", icon: "rosette", xp: 260, tint: cGoal, target: 4, metric: { funded($0) }),
        Badge(id: "goal_7", title: "Closer", detail: "Fully fund 5 goals.", icon: "trophy.circle.fill", xp: 380, tint: cGoal, target: 5, metric: { funded($0) }),
        Badge(id: "goal_10", title: "Dream Maker", detail: "Fully fund 6 goals.", icon: "crown.fill", xp: 560, tint: cGoal, target: 6, metric: { funded($0) }),
    ]

    private static let streaks: [Badge] = [
        Badge(id: "streak_3", title: "Warming Up", detail: "Hold a 2 day streak.", icon: "flame", xp: 28, tint: cFlame, target: 2, metric: { streak($0) }),
        Badge(id: "streak_7", title: "On Fire", detail: "Hold a 5 day streak.", icon: "flame.fill", xp: 50, tint: cFlame, target: 5, metric: { streak($0) }),
        Badge(id: "streak_14", title: "Relentless", detail: "Hold a 10 day streak.", icon: "flame.fill", xp: 85, tint: cFlame, target: 10, metric: { streak($0) }),
        Badge(id: "streak_21", title: "Locked In", detail: "Hold a 15 day streak.", icon: "flame.circle", xp: 125, tint: cFlame, target: 15, metric: { streak($0) }),
        Badge(id: "streak_30", title: "Untouchable", detail: "Hold a 21 day streak.", icon: "flame.circle.fill", xp: 175, tint: cFlame, target: 21, metric: { streak($0) }),
        Badge(id: "streak_45", title: "Unbreakable", detail: "Hold a 30 day streak.", icon: "flame.circle.fill", xp: 250, tint: cFlame, target: 30, metric: { streak($0) }),
        Badge(id: "streak_60", title: "Ironclad", detail: "Hold a 45 day streak.", icon: "bolt.shield.fill", xp: 350, tint: cFlame, target: 45, metric: { streak($0) }),
        Badge(id: "streak_90", title: "Centurion", detail: "Hold a 60 day streak.", icon: "shield.fill", xp: 520, tint: cFlame, target: 60, metric: { streak($0) }),
    ]

    private static let loyalty: [Badge] = [
        Badge(id: "months_1", title: "Settling In", detail: "Use Cashie for 1 month.", icon: "calendar", xp: 28, tint: cBlue, target: 1, metric: { months($0) }),
        Badge(id: "months_2", title: "Sticking Around", detail: "Use Cashie for 2 months.", icon: "calendar", xp: 50, tint: cBlue, target: 2, metric: { months($0) }),
        Badge(id: "months_3", title: "Regular", detail: "Use Cashie for 3 months.", icon: "calendar.badge.clock", xp: 80, tint: cBlue, target: 3, metric: { months($0) }),
        Badge(id: "months_6", title: "Veteran", detail: "Use Cashie for 4 months.", icon: "calendar.badge.clock", xp: 150, tint: cBlue, target: 4, metric: { months($0) }),
        Badge(id: "months_9", title: "Loyalist", detail: "Use Cashie for 6 months.", icon: "star.circle.fill", xp: 230, tint: cBlue, target: 6, metric: { months($0) }),
        Badge(id: "months_12", title: "Mainstay", detail: "Use Cashie for 8 months.", icon: "star.square.fill", xp: 340, tint: cBlue, target: 8, metric: { months($0) }),
    ]

    /// The full catalog, sorted by XP so the easiest, most achievable badges
    /// sit first and there's always a bigger one to chase. The total comfortably
    /// exceeds the Legendary threshold, so the climb is steady and never caps.
    static let all: [Badge] =
        (logging + saving + depositsFamily + goalsFamily + streaks + loyalty)
            .sorted { $0.xp < $1.xp }
}

extension Badge {
    /// The unlock threshold in the user's display currency. Money badges (the
    /// "save X across goals" tier) are defined in USD; we convert them so the
    /// milestone stays meaningful in any currency (e.g. "Save $3,600" becomes
    /// ~₹300,000), matching the user's saved total, which is already in their
    /// currency. Non-money badges (counts, days, months) are unchanged. This is
    /// a local display adjustment only; no user data is touched.
    var currentTarget: Int {
        guard isMoney, Money.currencyCode != "USD" else { return target }
        return Int(CurrencyRates.roundNice(CurrencyRates.convert(Double(target), from: "USD", to: Money.currencyCode)))
    }

    /// Description with the money tier re-priced into the user's currency.
    var currentDetail: String {
        guard isMoney, Money.currencyCode != "USD" else { return detail }
        return "Save \(Money.format(Double(currentTarget))) across goals."
    }
}
