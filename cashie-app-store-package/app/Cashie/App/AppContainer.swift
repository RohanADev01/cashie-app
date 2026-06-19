import Foundation
import SwiftUI

/// Composition root. Holds the service bindings + the app's runtime state.
/// Swap mocks for real implementations here when keys are ready.
@MainActor
final class AppContainer: ObservableObject {
    /// The offline-first sync facade the whole app talks to: a `SyncEngine`
    /// wrapping the durable on-device store plus an optional live Supabase
    /// remote. Reads come from local instantly; writes persist locally first
    /// then sync in the background.
    let supabase: SupabaseService
    let subscriptions: SubscriptionService

    /// Durable anonymous Supabase identity. `nil` until a Supabase anon key is
    /// configured (the app then runs fully offline-first). Supplies the access
    /// token for every authed remote write and the stable `auth.uid()` that
    /// analytics + the Quick Log key mint key off.
    let authClient: AuthClient?

    /// PostHog funnel analytics (hand-rolled REST). `nil` until a PostHog key is
    /// set in `Config`; every event is then a no-op.
    let analytics: Analytics?

    /// Drives the small in-app "Saving…/Saved" loading indicator. Observed by
    /// `SyncStatusBar` in `RootView`.
    let syncIndicator = SyncIndicator()

    /// Concrete engine handle for sync-lifecycle calls (start / resync).
    private let engine: SyncEngine

    @Published var session: SessionState = .splash

    @Published var user: CashieUser = SampleData.user {
        didSet { persistUser() }
    }
    @Published var transactions: [Transaction] = []
    @Published var goals: [Goal] = []
    @Published var notifications: [AppNotification] = []
    @Published var budgets: [CategoryBudget] = CategoryBudget.seed {
        didSet { persistBudgets() }
    }
    @Published var settings: AppSettings = AppSettings() {
        didSet { persistSettings() }
    }

    /// Display currency code, mirrored to `Money.currencyCode` (UserDefaults).
    /// Lives on the container so changing it republishes and every money label
    /// refreshes. Local-only, never synced to the backend.
    @Published var currencyCode: String = Money.currencyCode {
        didSet { Money.currencyCode = currencyCode }
    }

    /// Local-only onboarding progress, used to resume at the right screen after
    /// a relaunch. Persisted to `LocalStore` (never synced) so routing never
    /// waits on the network. See `routeOnLaunch` / `recordOnboardingAnswers`.
    private(set) var onboardingProgress: OnboardingProgress

    /// Tracks whether a Quick Log sheet should be shown over any screen.
    @Published var quickLogPresented: Bool = false

    /// Values to seed the Quick Log sheet with when it's opened from a deep link
    /// or an App Intent. Cleared by the presenter when the sheet dismisses.
    @Published var quickLogPrefill: QuickLogPrefill? = nil

    /// Active main-app tab. Lives on the container so any sheet can switch
    /// tabs (e.g. dismissing the Subscription sheet for an already-paid
    /// user and routing them back to Today).
    @Published var mainTab: MainTab = .today

    /// The celebration currently on screen (badge unlock, rank-up, or a funded
    /// goal). Owned here so detection lives at the data layer and presentation
    /// is tab-independent: `MainTabsView` binds to this and plays whatever is
    /// queued, immediately, over any open sheet. Nil = nothing showing.
    @Published var currentCelebration: Celebration? = nil

    /// Celebrations earned while one is already on screen, played one after
    /// another (see `enqueueCelebrations` / `presentNextCelebration`).
    private var celebrationQueue: [Celebration] = []

    /// Suppresses didSet-driven persistence (and achievement detection) while we
    /// hydrate from disk. Readable from the RankEngine extension; only this file
    /// flips it.
    private(set) var isBootstrapping: Bool = false

    /// Gates celebration playback. Stays false through the cold-launch settling
    /// window, during which `evaluateAchievements` silently folds whatever is
    /// already unlocked into the baseline instead of celebrating, so a relaunch
    /// never replays a badge or rank the user already earned. Launch data lands
    /// in stages (local load, then the first remote/sample merge via
    /// `reloadFromLocal`), so seeding once in `bootstrap` can miss a badge that
    /// crosses its threshold a moment later. Armed shortly after `bootstrap`,
    /// then stays armed for the process lifetime so in-session unlocks and
    /// foreground-resume (time-based) unlocks celebrate normally.
    private(set) var achievementsArmed: Bool = false

    /// `supabase` is the durable on-device store (the file-backed mock). It is
    /// wrapped in a `SyncEngine` that adds optimistic writes, a retry outbox,
    /// the loading indicator, and optional background Supabase sync. By default
    /// a live remote is built from `Config` when an anon key is present, and
    /// stays dormant (app runs fully offline) otherwise.
    init(supabase: SupabaseService = MockSupabaseService(),
         remote: SupabaseService? = nil,
         subscriptions: SubscriptionService = StoreKitService()) {
        self.subscriptions = subscriptions
        // Anonymous Supabase session backs every authed write. Its access token
        // is fed to the live remote via the token provider; both are nil (and
        // the app stays offline-first) until an anon key is configured.
        let auth = AuthClient()
        self.authClient = auth
        self.analytics = Analytics()
        let resolvedRemote = remote ?? LiveSupabaseService.makeIfConfigured(tokenProvider: { [auth] in
            guard let auth else { return nil }
            return await auth.accessToken()
        })
        let engine = SyncEngine(local: supabase, remote: resolvedRemote, indicator: syncIndicator)
        self.engine = engine
        self.supabase = engine
        self.onboardingProgress = LocalStore.shared.load(OnboardingProgress.self, key: LocalStore.Key.onboarding) ?? OnboardingProgress()
    }

    func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        async let txs = (try? await supabase.loadTransactions()) ?? []
        async let gs = (try? await supabase.loadGoals()) ?? []
        async let ns = (try? await supabase.loadNotifications()) ?? []
        async let bs = (try? await supabase.loadBudgets()) ?? CategoryBudget.seed
        async let st = (try? await supabase.loadSettings()) ?? AppSettings()
        async let u = (try? await supabase.loadUser()) ?? nil

        let (t, g, n, b, s, savedUser) = await (txs, gs, ns, bs, st, u)
        self.transactions = t
        self.goals = g
        self.notifications = n
        self.budgets = b
        self.settings = s
        if var savedUser {
            // Re-resolve the archetype from the live catalog by id, so a profile
            // saved before an archetype was renamed/retuned always shows the
            // current copy (name, tagline, stats) on every screen.
            savedUser.archetype = Archetype.by(id: savedUser.archetype.id)
            self.user = savedUser
        }

        // Seed the rank baseline against fully-loaded data so the first launch
        // never fires a spurious rank-up while transactions are still
        // streaming in. After this, only a genuine in-app climb advances it
        // (see evaluateAchievements). Runs while bootstrapping, so the
        // didSet persistence is intentionally suppressed.
        if self.settings.lastSeenRankRaw < 0 {
            self.settings.lastSeenRankRaw = self.currentRank.rawValue
        }
        // Same idea for badges: mark everything already unlocked as "seen" so
        // we only celebrate badges earned from here on.
        if !self.settings.badgeBaselineSeeded {
            self.settings.celebratedBadgeIDs = self.unlockedBadges.map { $0.id }
            self.settings.badgeBaselineSeeded = true
        }

        // Establish the durable anonymous Supabase identity (no-op when no anon
        // key is set or anonymous sign-ins are disabled). With a uid in hand we
        // identify analytics and align the local user id. Done before startSync
        // so the first remote pull is authenticated. isBootstrapping suppresses
        // the user didSet, so setting the id here doesn't trigger a spurious save.
        if let uid = await authClient?.userID() {
            await analytics?.identify(uid.uuidString)
            if user.id != uid { user.id = uid }
        }
        track("app_opened", ["cold": "true"])
        await analytics?.flush()

        // Wire background sync. When the remote pushes changes (realtime / pull)
        // it rehydrates the local store and asks us to refresh the published
        // snapshots. Both calls are no-ops when there is no configured /
        // authenticated remote, so the offline path is unchanged.
        await engine.setRemoteMergeHandler { [weak self] in self?.reloadFromLocal() }
        await engine.startSync()

        // Arm celebrations once launch data (local load + the first remote pull
        // and its async merge) has had a moment to settle. Until now,
        // evaluateAchievements folds everything already unlocked into the
        // baseline silently, so a cold launch never replays an old celebration.
        // The short delay covers the fire-and-forget reloadFromLocal a remote
        // pull schedules; genuine in-session unlocks happen far later and still
        // celebrate.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.achievementsArmed = true
        }

        #if DEBUG
        // Dev: `-currency INR` forces the display currency (and converts goals)
        // so currency states are testable without tapping through onboarding.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-currency"), i + 1 < args.count {
            Money.currencyConfirmed = true
            currencyCode = args[i + 1]
        }
        #endif
    }

    /// Re-pull from the remote and flush the outbox, e.g. on foreground.
    /// No-op when there is no live remote.
    func resync() async { await engine.resync() }

    /// Refresh the published collections from the durable local store after a
    /// remote merge. Persistence didSets are suppressed during the assignment
    /// so this can never loop back into another save.
    func reloadFromLocal() {
        Task { @MainActor in
            let u = try? await supabase.loadUser()
            let t = (try? await supabase.loadTransactions()) ?? transactions
            let g = (try? await supabase.loadGoals()) ?? goals
            let n = (try? await supabase.loadNotifications()) ?? notifications
            let b = (try? await supabase.loadBudgets()) ?? budgets
            let s = (try? await supabase.loadSettings()) ?? settings
            isBootstrapping = true
            if var u {
                u.archetype = Archetype.by(id: u.archetype.id)   // keep name/copy current
                user = u
            }
            transactions = t; goals = g; notifications = n; budgets = b; settings = s
            isBootstrapping = false
            // A merge can bring in transactions/goals earned on another device
            // or via a background Back Tap/Siri log. Check for anything newly
            // unlocked now that the published snapshots reflect the merged data.
            evaluateAchievements()
        }
    }

    // MARK: - Celebration queue

    /// Queue celebrations so several earned at once play one after another. The
    /// first plays immediately; the rest wait for `presentNextCelebration`.
    func enqueueCelebrations(_ items: [Celebration]) {
        guard !items.isEmpty else { return }
        if currentCelebration == nil {
            currentCelebration = items.first
            celebrationQueue.append(contentsOf: items.dropFirst())
        } else {
            celebrationQueue.append(contentsOf: items)
        }
    }

    /// Advance to the next queued celebration. Called by the presenter when the
    /// current one is dismissed. A small gap lets the previous cover/sheet
    /// finish dismissing before the next presents.
    func presentNextCelebration() {
        guard !celebrationQueue.isEmpty else { return }
        let next = celebrationQueue.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.currentCelebration = next
        }
    }

    #if DEBUG
    /// Dev-only smoke test for the sync layer, triggered by `-syncSelfTest`. It
    /// drives every write path through the real container methods so we can
    /// confirm nothing crashes, the loading indicator shows then clears (never
    /// sticks), and writes persist to the durable local store. Compiled out of
    /// release builds.
    func runSyncSelfTest() async {
        func pause(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        print("SYNC-SELFTEST start tx=\(transactions.count) goals=\(goals.count) budgets=\(budgets.count)")

        // 0. Drive the indicator directly so its "Saving" state can be captured.
        syncIndicator.begin(); await pause(2.5)
        syncIndicator.end();   await pause(1.5)

        // 1. Add + delete a transaction.
        let tx = Transaction(merchant: "SelfTest Bill", amount: 4.5, category: .bills, date: Date(), note: nil)
        addTransaction(tx); await pause(1.2)
        deleteTransaction(tx.id); await pause(1.2)

        // 2. Goal lifecycle: create, deposit, remove deposit, delete.
        let goal = Goal(emoji: "🧪", name: "SelfTest Goal", targetAmount: 100, currentAmount: 0,
                        targetDate: Date().addingTimeInterval(60*60*24*30))
        saveGoal(goal); await pause(1.2)
        addDeposit(Deposit(amount: 25, date: Date()), to: goal.id); await pause(1.2)
        if let g = goals.first(where: { $0.id == goal.id }), let dep = g.deposits.first {
            removeDeposit(dep.id, from: goal.id)
        }
        await pause(1.2)

        // 3. Budgets + settings (persisted via didSet → engine).
        setBudget(category: .bills, cap: 99); await pause(1.2)
        settings.dailyReminderEnabled.toggle(); await pause(1.2)

        // 4. Cleanup the goal.
        deleteGoal(goal.id); await pause(1.0)

        print("SYNC-SELFTEST done tx=\(transactions.count) goals=\(goals.count) billsCap=\(budgets.first(where: { $0.category == .bills })?.monthlyCap ?? -1) indicatorStuck=\(syncIndicator.isActive)")
    }
    #endif

    func addTransaction(_ tx: Transaction) {
        transactions.insert(tx, at: 0)
        Task { try? await supabase.addTransaction(tx) }
        track("transaction_logged", ["source": tx.source.rawValue, "category": tx.category.rawValue])
        evaluateAchievements()
    }

    func deleteTransaction(_ id: UUID) {
        transactions.removeAll { $0.id == id }
        Task { try? await supabase.deleteTransaction(id) }
        evaluateAchievements()
    }

    func addDeposit(_ deposit: Deposit, to goalID: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == goalID }) else { return }
        let wasAchieved = goals[idx].isAchieved
        // Cap the deposit at what's still needed so we don't bank more
        // than the goal's target. e.g. depositing $50 into a $200/$230
        // goal lands as $30.
        let headroom = max(0, goals[idx].targetAmount - goals[idx].currentAmount)
        let amount = min(deposit.amount, headroom)
        guard amount > 0 else { return }
        var capped = deposit
        capped.amount = amount
        goals[idx].currentAmount += amount
        goals[idx].deposits.insert(capped, at: 0)
        let updated = goals[idx]
        Task { try? await supabase.saveGoal(updated) }
        // Crossing the line from "in flight" to "funded" on this deposit is
        // what we celebrate. Already-achieved or already-archived goals don't
        // re-trigger. Queue the "Funded" celebration first, then check for any
        // badge/rank earned by the same deposit so they play Funded -> badge.
        if !wasAchieved, updated.isAchieved, !updated.isArchived {
            enqueueCelebrations([.goal(updated)])
        }
        evaluateAchievements()
    }

    func removeDeposit(_ depositID: UUID, from goalID: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == goalID }) else { return }
        guard let dep = goals[idx].deposits.first(where: { $0.id == depositID }) else { return }
        goals[idx].deposits.removeAll { $0.id == depositID }
        goals[idx].currentAmount = max(0, goals[idx].currentAmount - dep.amount)
        let updated = goals[idx]
        Task { try? await supabase.saveGoal(updated) }
        evaluateAchievements()
    }

    /// Move an achieved goal into Past wins so the active list stays tidy.
    func archiveGoal(_ id: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[idx].archivedAt = Date()
        let snapshot = goals[idx]
        Task { try? await supabase.saveGoal(snapshot) }
    }

    /// Bring a Past win back into active flight (e.g. user wants to top it up).
    func unarchiveGoal(_ id: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[idx].archivedAt = nil
        let snapshot = goals[idx]
        Task { try? await supabase.saveGoal(snapshot) }
    }

    /// Goals still on the active board: not yet moved to Past wins. Sorted
    /// so in-flight goals stay at the top and freshly funded ones drop to
    /// the bottom, where they sit until the user celebrates them.
    var activeGoals: [Goal] {
        goals
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.isAchieved != rhs.isAchieved {
                    return !lhs.isAchieved
                }
                return lhs.targetDate < rhs.targetDate
            }
    }

    /// Achieved goals the user has acknowledged. Sorted newest-first.
    var pastWins: [Goal] {
        goals.filter { $0.isArchived }
             .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    func saveGoal(_ goal: Goal) {
        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[idx] = goal
        } else {
            goals.append(goal)
        }
        Task { try? await supabase.saveGoal(goal) }
        evaluateAchievements()
    }

    func deleteGoal(_ id: UUID) {
        goals.removeAll { $0.id == id }
        Task { try? await supabase.deleteGoal(id) }
        evaluateAchievements()
    }

    func setBudget(category: SpendCategory, cap: Double) {
        if let idx = budgets.firstIndex(where: { $0.category == category }) {
            budgets[idx].monthlyCap = cap
        } else {
            budgets.append(CategoryBudget(category: category, monthlyCap: cap))
        }
        // Streak badges read the budget pace, so a cap change can unlock one.
        evaluateAchievements()
    }

    // MARK: - Derived stats (computed from real data)

    /// Months between the earliest transaction and today (floor, min 1).
    var derivedMonthsActive: Int {
        guard let earliest = transactions.map(\.date).min() else { return 1 }
        let cal = Calendar.current
        let months = cal.dateComponents([.month], from: earliest, to: Date()).month ?? 0
        return max(1, months + 1)
    }

    /// Sum of every dollar pushed into any goal. Reflects deposits added via
    /// `addDeposit` (which mutates `Goal.currentAmount`).
    var derivedTotalSaved: Double {
        goals.reduce(0) { $0 + $1.currentAmount }
    }

    /// Daily allowance derived from the sum of every category's monthly cap,
    /// spread evenly across the days in the current calendar month. Used as
    /// a reference rate for "you can spend ~$X a day."
    var dailyBudgetAllowance: Double {
        let cal = Calendar.current
        let days = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        let monthCap = budgets.reduce(0) { $0 + $1.monthlyCap }
        guard days > 0 else { return 0 }
        return monthCap / Double(days)
    }

    /// Total non-income spend on a specific calendar day.
    func daySpend(on day: Date) -> Double {
        let cal = Calendar.current
        return transactions
            .filter { $0.category != .income && cal.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Cumulative non-income spend in the calendar month of `date`, summed
    /// from the first of that month through end-of-day on `date`.
    func monthToDateSpend(through date: Date) -> Double {
        let cal = Calendar.current
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
        return transactions
            .filter {
                $0.category != .income
                && cal.isDate($0.date, equalTo: date, toGranularity: .month)
                && $0.date <= endOfDay
            }
            .reduce(0) { $0 + $1.amount }
    }

    /// Cumulative cap allowed by the end of `date`, prorated against the
    /// calendar month it sits in. Day 7 of a 30-day month with a $900 cap
    /// returns $210 (7 / 30 × 900).
    func proratedMonthCap(through date: Date) -> Double {
        let cal = Calendar.current
        let monthCap = budgets.reduce(0) { $0 + $1.monthlyCap }
        let daysInMonth = cal.range(of: .day, in: .month, for: date)?.count ?? 30
        let dayOfMonth = cal.component(.day, from: date)
        guard daysInMonth > 0 else { return 0 }
        return monthCap * Double(dayOfMonth) / Double(daysInMonth)
    }

    /// Days you have left in the current calendar month, today included.
    var daysLeftInMonth: Int {
        let cal = Calendar.current
        let daysInMonth = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        let today = cal.component(.day, from: Date())
        return max(1, daysInMonth - today + 1)
    }

    /// What you can still spend each day, on average, to finish the month
    /// at or under the total cap. Treats today as a day you can still spend.
    var perDayLeftThisMonth: Double {
        let monthCap = budgets.reduce(0) { $0 + $1.monthlyCap }
        let mtd = monthToDateSpend(through: Date())
        let remaining = max(0, monthCap - mtd)
        return remaining / Double(daysLeftInMonth)
    }

    /// Streak = consecutive days, counting back from today, where cumulative
    /// month-to-date spend stayed at or under the prorated month cap.
    /// This is forgiving of irregular spending: a $0 day banks headroom for
    /// a $200 night out, and the streak only breaks once the running total
    /// has actually outpaced the budget. Crosses month boundaries cleanly
    /// because each day is judged against its own month's cap. Days before
    /// the user started tracking don't count.
    var derivedStreakDays: Int {
        let cal = Calendar.current
        guard budgets.reduce(0, { $0 + $1.monthlyCap }) > 0 else { return 0 }
        guard let earliest = transactions.map(\.date).min() else { return 0 }
        let firstDay = cal.startOfDay(for: earliest)

        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        while cursor >= firstDay {
            let mtd = monthToDateSpend(through: cursor)
            let cap = proratedMonthCap(through: cursor)
            if mtd > cap { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Most recent past day where running MTD spend pushed over the prorated
    /// cap. Used to explain why a streak is short.
    var lastOverspendDay: Date? {
        let cal = Calendar.current
        guard budgets.reduce(0, { $0 + $1.monthlyCap }) > 0 else { return nil }
        let today = cal.startOfDay(for: Date())
        let candidates = Set(transactions.map { cal.startOfDay(for: $0.date) })
            .filter { $0 < today }
            .sorted(by: >)
        for day in candidates {
            if monthToDateSpend(through: day) > proratedMonthCap(through: day) {
                return day
            }
        }
        return nil
    }

    /// Trailing-7-day spend versus a proportional weekly slice of every cap.
    /// Positive = under budget for the week, negative = over.
    var weeklyBudgetGap: Double {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let spent = transactions
            .filter { $0.date >= weekAgo && $0.category != .income }
            .reduce(0) { $0 + $1.amount }
        let monthCap = budgets.reduce(0) { $0 + $1.monthlyCap }
        let weeklyCap = monthCap / (30.0 / 7.0)
        return weeklyCap - spent
    }

    /// Income logged in the current calendar month. Used to show the
    /// "money in" line on home so users have a sense of how much their
    /// budget is actually drawing from.
    var monthIncomeTotal: Double {
        let cal = Calendar.current
        return transactions
            .filter { $0.category == .income && cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Total of every deposit made into any goal during the current
    /// calendar month. Treated as a budget outflow alongside expenses so
    /// that putting money into a goal actually feels like spending the
    /// month's budget on it (instead of free money on the side).
    var monthDepositsTotal: Double {
        let cal = Calendar.current
        return goals.flatMap(\.deposits)
            .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    /// "Safe to spend" this month = total monthly caps minus this month's
    /// non-income spend minus this month's goal deposits. The single source of
    /// truth for the Today hero, the Wrapped net card and the You weekly card,
    /// so those surfaces never disagree. Goes negative once over the cap.
    var safeToSpend: Double {
        let cal = Calendar.current
        let monthSpend = transactions
            .filter { $0.category != .income && cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
        let monthCap = budgets.reduce(0) { $0 + $1.monthlyCap }
        return monthCap - monthSpend - monthDepositsTotal
    }

    /// Total deposits made this month into a single goal. Powers the
    /// "Saving" row drilldown so each goal can show its own contribution
    /// for the period.
    func monthDeposits(in goalID: UUID) -> Double {
        let cal = Calendar.current
        guard let goal = goals.first(where: { $0.id == goalID }) else { return 0 }
        return goal.deposits
            .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Money spent in this category in the current calendar month.
    func monthSpend(in category: SpendCategory) -> Double {
        monthSpend(in: category, monthOffset: 0)
    }

    /// Money spent in this category, offset N calendar months from now
    /// (0 = this month, -1 = last month, etc.).
    func monthSpend(in category: SpendCategory, monthOffset: Int) -> Double {
        let cal = Calendar.current
        let target = cal.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        return transactions
            .filter {
                $0.category == category
                && cal.isDate($0.date, equalTo: target, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.amount }
    }

    func markNotificationsRead() {
        notifications = notifications.map { var n = $0; n.isUnread = false; return n }
        Task { try? await supabase.markNotificationsRead() }
    }

    // MARK: - Persistence (driven by @Published didSet)

    private func persistUser() {
        guard !isBootstrapping else { return }
        let snapshot = user
        Task { try? await supabase.saveUser(snapshot) }
    }

    private func persistBudgets() {
        guard !isBootstrapping else { return }
        let snapshot = budgets
        Task { try? await supabase.saveBudgets(snapshot) }
    }

    private func persistSettings() {
        guard !isBootstrapping else { return }
        let snapshot = settings
        Task { try? await supabase.saveSettings(snapshot) }
    }

    // MARK: - Subscription gating

    /// Re-checks the gateway and bounces the user back to the paywall if
    /// the entitlement is no longer active. Safe to call on launch and on
    /// every foreground.
    func refreshSubscription() async {
        // Don't bounce out of the main app when the -skipSubGate dev flag is set.
        if ProcessInfo.processInfo.arguments.contains("-skipSubGate") { return }
        let active = (try? await subscriptions.refreshSubscriptionStatus()) ?? false
        await MainActor.run {
            if active {
                UserDefaults.standard.set(true, forKey: "isSubscribed")
                return
            }
            // Subscription is gone (expired/refunded/cancelled). Drop the
            // local marker and route any user currently in the main app
            // back to the paywall.
            UserDefaults.standard.removeObject(forKey: "isSubscribed")
            if session == .main {
                advanceOnboarding(to: .paywall)
            }
        }
    }

    // MARK: - Onboarding progress (local-only, drives resume)

    /// Decides the first screen on launch given the authoritative subscription
    /// state. Pro users always land in the main app. Otherwise: a user who has
    /// reached the paywall always sees the paywall again (hard paywall), and a
    /// user mid-onboarding resumes where they left off — except a half-finished
    /// quiz restarts from the first question.
    func routeOnLaunch(subscribed: Bool) {
        if subscribed {
            UserDefaults.standard.set(true, forKey: "isSubscribed")
            goToMain()
            return
        }
        UserDefaults.standard.removeObject(forKey: "isSubscribed")
        guard let resume = OnboardingStep(persistedID: onboardingProgress.step) else {
            goToOnboarding()
            return
        }
        if resume.flowRank >= OnboardingStep.paywall.flowRank {
            advanceOnboarding(to: .paywall)
        } else {
            advanceOnboarding(to: resume.resumeDestination)
        }
    }

    /// Persists the latest in-flight quiz answers / relatability chips locally so
    /// they survive a relaunch and can rehydrate the onboarding state on resume.
    /// Local only — no network, no DB.
    func recordOnboardingAnswers(quizAnswers: [Int: String], relatabilityChips: Set<String>) {
        onboardingProgress.quizAnswers = quizAnswers.reduce(into: [:]) { $0[String($1.key)] = $1.value }
        onboardingProgress.relatabilityChips = Array(relatabilityChips)
        persistOnboardingProgress()
    }

    /// Writes the marketing snapshot (quiz answers, archetype, traits, chips) to
    /// the synced user profile once, at quiz completion. The single `user`
    /// mutation triggers one `persistUser` → one DB upsert.
    func recordQuizMarketingData(quizAnswers: [Int: String],
                                 relatabilityChips: Set<String>,
                                 archetype: Archetype,
                                 traits: [Trait]) {
        var u = user
        u.quizAnswers = quizAnswers.reduce(into: [:]) { $0[String($1.key)] = $1.value }
        u.relatabilityChips = Array(relatabilityChips)
        u.archetype = archetype
        u.traits = traits
        user = u   // single didSet → one persistUser → one DB upsert
        track("quiz_completed", ["archetype": archetype.id.rawValue])
    }

    private func persistOnboardingProgress() {
        LocalStore.shared.save(onboardingProgress, key: LocalStore.Key.onboarding)
    }

    // MARK: - Analytics (fire-and-forget)

    /// Captures a PostHog event without blocking the caller. No-op when analytics
    /// is not configured.
    func track(_ event: String, _ properties: [String: String] = [:]) {
        guard let analytics else { return }
        Task { await analytics.capture(event, properties) }
    }

    /// Flushes any buffered analytics events (called on foreground).
    func flushAnalytics() async { await analytics?.flush() }

    // MARK: - Session transitions

    func goToOnboarding() {
        advanceOnboarding(to: .welcome)
    }

    func advanceOnboarding(to step: OnboardingStep) {
        onboardingProgress.step = step.persistedID
        persistOnboardingProgress()
        // One central call site covers the whole onboarding funnel.
        track("onboarding_step_reached", ["step": step.persistedID])
        withAnimation(Theme.Motion.smooth) { session = .onboarding(step) }
    }

    func goToMain() {
        withAnimation(Theme.Motion.smooth) { session = .main }
    }

    /// Opens the Quick Log sheet over the main app, seeded with `prefill`. The
    /// single entry point for the FAB, deep links (`cashie://`), and the
    /// `OpenQuickLogIntent` App Intent. Routes to the main session first so a
    /// link that arrives during onboarding/splash still lands correctly.
    func presentQuickLog(_ prefill: QuickLogPrefill = QuickLogPrefill()) {
        // Hard paywall: Quick Log is a Pro feature. A deep link / App Intent must
        // not slip a non-subscriber past the paywall into the main app.
        guard isProUnlocked else {
            advanceOnboarding(to: .paywall)
            return
        }
        quickLogPrefill = prefill
        if session != .main {
            withAnimation(Theme.Motion.smooth) { session = .main }
        }
        quickLogPresented = true
    }

    /// Whether Pro features are unlocked right now. Uses the cached entitlement
    /// (kept fresh by `refreshSubscription` on launch/foreground); the dev
    /// `-skipSubGate` flag forces it open for QA/screenshots.
    var isProUnlocked: Bool {
        ProcessInfo.processInfo.arguments.contains("-skipSubGate") || subscriptions.isSubscribed
    }

    // MARK: - Quick Log key

    enum QuickLogKeyResult: Equatable {
        case ready(String)
        case notPro
        case unavailable
    }

    /// Returns the device's Quick Log API key, minting one server-side if needed.
    /// The mint endpoint verifies the caller's `pro` entitlement, so the returned
    /// key is registered server-side (the endpoint will accept it). Pass
    /// `reset: true` to revoke prior keys and issue a fresh one.
    ///
    /// With no Supabase backend configured (dev/previews) it falls back to a
    /// local inert key so the setup UI still renders.
    func quickLogKey(reset: Bool = false) async -> QuickLogKeyResult {
        guard Config.hasSupabase, let authClient else {
            return .ready(QuickLogKey.localFallback())
        }
        if !reset, let cached = QuickLogKey.cached() { return .ready(cached) }
        guard let token = await authClient.accessToken() else {
            return QuickLogKey.cached().map { .ready($0) } ?? .unavailable
        }

        // Proof of Pro for the server: the originalTransactionId of the active
        // entitlement, which the edge function verifies via Apple's App Store
        // Server API before minting.
        let originalTransactionID = await subscriptions.proEntitlementToken()

        let url = Config.supabaseURL.appendingPathComponent("functions/v1/mint-quick-log-key")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["reset": reset]
        if let originalTransactionID { payload["original_transaction_id"] = originalTransactionID }
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse else {
            return QuickLogKey.cached().map { .ready($0) } ?? .unavailable
        }
        if http.statusCode == 403 { return .notPro }
        guard (200..<300).contains(http.statusCode),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let key = obj["key"] as? String, key.hasPrefix("qlk_") else {
            return QuickLogKey.cached().map { .ready($0) } ?? .unavailable
        }
        QuickLogKey.store(key)
        track("quick_log_key_minted")
        return .ready(key)
    }
}

enum SessionState: Equatable {
    case splash
    case onboarding(OnboardingStep)
    case main
}

enum OnboardingStep: Equatable, Hashable {
    case welcome
    case relatability
    case intro
    case quiz(Int)             // 1...5
    case loading
    case reveal
    case traits
    case pain
    case solution
    case effort
    case socialProof
    case reviews
    case contrast
    case paywall
    case welcomeIn
    case nameInput
    case permissions
    case backTapIntro
    case backTapTeaser
    case backTapSetup
    case actionButtonSetup
    case applePaySetup
    case currency
    case tryLive
    case ready
}

extension OnboardingStep {
    /// Stable string used to persist the current step locally. `quiz(n)` encodes
    /// the question number so we can tell a half-finished quiz from a finished one.
    var persistedID: String {
        switch self {
        case .welcome: return "welcome"
        case .relatability: return "relatability"
        case .intro: return "intro"
        case .quiz(let n): return "quiz:\(n)"
        case .loading: return "loading"
        case .reveal: return "reveal"
        case .traits: return "traits"
        case .pain: return "pain"
        case .solution: return "solution"
        case .effort: return "effort"
        case .socialProof: return "socialProof"
        case .reviews: return "reviews"
        case .contrast: return "contrast"
        case .paywall: return "paywall"
        case .welcomeIn: return "welcomeIn"
        case .nameInput: return "nameInput"
        case .permissions: return "permissions"
        case .backTapIntro: return "backTapIntro"
        case .backTapTeaser: return "backTapTeaser"
        case .backTapSetup: return "backTapSetup"
        case .actionButtonSetup: return "actionButtonSetup"
        case .applePaySetup: return "applePaySetup"
        case .currency: return "currency"
        case .tryLive: return "tryLive"
        case .ready: return "ready"
        }
    }

    init?(persistedID: String) {
        if persistedID.hasPrefix("quiz:"), let n = Int(persistedID.dropFirst(5)) {
            self = .quiz(min(max(n, 1), 5))
            return
        }
        switch persistedID {
        case "welcome": self = .welcome
        case "relatability": self = .relatability
        case "intro": self = .intro
        case "loading": self = .loading
        case "reveal": self = .reveal
        case "traits": self = .traits
        case "pain": self = .pain
        case "solution": self = .solution
        case "effort": self = .effort
        case "socialProof": self = .socialProof
        case "reviews": self = .reviews
        case "contrast": self = .contrast
        case "paywall": self = .paywall
        case "welcomeIn": self = .welcomeIn
        case "nameInput": self = .nameInput
        case "permissions": self = .permissions
        case "backTapIntro": self = .backTapIntro
        case "backTapTeaser": self = .backTapTeaser
        case "backTapSetup": self = .backTapSetup
        case "actionButtonSetup": self = .actionButtonSetup
        case "applePaySetup": self = .applePaySetup
        case "currency": self = .currency
        case "tryLive": self = .tryLive
        case "ready": self = .ready
        default: return nil
        }
    }

    /// Linear position in the onboarding flow. Used to tell whether a saved step
    /// has reached the paywall (everything at/after which means "show paywall").
    var flowRank: Int {
        switch self {
        case .welcome: return 0
        case .relatability: return 1
        case .intro: return 2
        case .quiz(let n): return 2 + n          // quiz1=3 … quiz5=7
        case .loading: return 8
        case .reveal: return 9
        case .traits: return 10
        case .pain: return 11
        case .solution: return 12
        case .effort: return 13
        case .socialProof: return 14
        case .reviews: return 15
        case .contrast: return 16
        case .paywall: return 17
        case .welcomeIn: return 18
        case .nameInput: return 19
        case .permissions: return 20
        case .backTapIntro: return 21
        case .backTapTeaser: return 22
        case .backTapSetup: return 23
        case .actionButtonSetup: return 24
        case .applePaySetup: return 25
        case .currency: return 26
        case .tryLive: return 27
        case .ready: return 28
        }
    }

    /// Where to resume after a relaunch: a half-finished quiz restarts from the
    /// first question; every other step resumes in place.
    var resumeDestination: OnboardingStep {
        if case .quiz = self { return .quiz(1) }
        return self
    }
}

/// Local-only onboarding progress. Persisted to `LocalStore` (not synced) so the
/// app can resume onboarding at the right screen and rehydrate the in-flight quiz
/// answers / relatability chips after a relaunch.
struct OnboardingProgress: Codable, Equatable {
    var step: String = ""
    var quizAnswers: [String: String] = [:]
    var relatabilityChips: [String] = []
}
