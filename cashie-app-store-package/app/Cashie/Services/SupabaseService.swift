import Foundation

/// Boundary that the app talks to for persistence + sync.
///
/// Implementations:
///   • `MockSupabaseService`, file-on-disk store backed by `LocalStore`. This is
///     the durable on-device store (the offline backup) used on every launch.
///   • `LiveSupabaseService`, a dependency-free Supabase client over URLSession
///     (PostgREST) + URLSessionWebSocketTask (Realtime). No SPM package needed.
///   • `SyncEngine`, the offline-first facade the app actually uses: it wraps a
///     local store (durable) plus an optional remote (`LiveSupabaseService`),
///     and adds optimistic writes, a retry outbox, realtime, and the loading
///     indicator. `AppContainer` builds it automatically.
///
/// The live path is dormant until BOTH `Config.supabaseAnonKey` is set AND a
/// Supabase auth access-token provider is supplied. Until then the app runs
/// fully offline-first on the local store. The dev project already has tables
/// `profiles`, `app_settings`, `transactions`, `category_budgets`, `goals`,
/// `deposits`, `notifications` with RLS enforcing `auth.uid() = user_id`, and a
/// trigger on `auth.users` seeds `profiles` + `app_settings` on sign-up. See
/// `BACKEND_SYNC_REPORT.md` for the full picture.
protocol SupabaseService: AnyObject {
    func loadUser() async throws -> CashieUser?
    func saveUser(_ user: CashieUser) async throws

    func loadTransactions() async throws -> [Transaction]
    func addTransaction(_ tx: Transaction) async throws
    func updateTransaction(_ tx: Transaction) async throws
    func deleteTransaction(_ id: UUID) async throws

    func loadGoals() async throws -> [Goal]
    func saveGoal(_ goal: Goal) async throws
    func deleteGoal(_ id: UUID) async throws

    func loadNotifications() async throws -> [AppNotification]
    func markNotificationsRead() async throws

    func loadBudgets() async throws -> [CategoryBudget]
    func saveBudgets(_ budgets: [CategoryBudget]) async throws

    func loadSettings() async throws -> AppSettings
    func saveSettings(_ settings: AppSettings) async throws

    // Bulk replace used when a remote pull rehydrates the durable local store.
    // A default no-op is provided in an extension so only the local store needs
    // to implement these (remote services inherit the no-op).
    func replaceTransactions(_ txs: [Transaction]) async throws
    func replaceGoals(_ goals: [Goal]) async throws
    func replaceNotifications(_ ns: [AppNotification]) async throws
}

/// File-on-disk mock used until real Supabase keys are wired up. First
/// launch seeds with `SampleData`; subsequent launches read the persisted
/// state from `LocalStore`.
///
/// All mutable state is guarded by `stateLock`. The async methods on this
/// non-isolated class hop OFF the calling actor (e.g. `SyncEngine`) and run
/// on the global cooperative executor, so two in-flight calls can read and
/// write these struct fields concurrently. Without the lock the embedded
/// heap-backed members (String/Dictionary/Array inside `CashieUser` etc.)
/// suffer refcount races, and the next `assignWithCopy` — most visibly the
/// `@Published user = u` in `AppContainer.reloadFromLocal` — crashes with a
/// PAC failure in `_swift_release_dealloc`. Disk I/O is kept outside the
/// lock because `LocalStore` already serialises writes on its own queue.
final class MockSupabaseService: SupabaseService {
    private let store = LocalStore.shared

    private let stateLock = NSLock()

    private var transactions: [Transaction]
    private var goals: [Goal]
    private var notifications: [AppNotification]
    private var budgets: [CategoryBudget]
    private var user: CashieUser?
    private var settings: AppSettings

    /// Run `body` under `stateLock`. Returned values are copied inside the
    /// critical section so callers receive a clean, refcount-correct snapshot.
    private func withState<T>(_ body: () -> T) -> T {
        stateLock.lock(); defer { stateLock.unlock() }
        return body()
    }

    init() {
        let seeded = UserDefaults.standard.bool(forKey: LocalStore.Key.seeded)

        if seeded {
            self.transactions = store.load([Transaction].self, key: LocalStore.Key.transactions) ?? []
            self.goals = store.load([Goal].self, key: LocalStore.Key.goals) ?? []
            self.notifications = store.load([AppNotification].self, key: LocalStore.Key.notifications) ?? []
            self.budgets = store.load([CategoryBudget].self, key: LocalStore.Key.budgets) ?? CategoryBudget.seed
            self.user = store.load(CashieUser.self, key: LocalStore.Key.user)
            self.settings = store.load(AppSettings.self, key: LocalStore.Key.settings) ?? AppSettings()
        } else {
            // Production first launch starts clean: no fabricated demo spends or
            // goals ever reach a real user. The sample dataset is dev-only (used
            // for screenshots and SwiftUI previews); release builds begin empty
            // with only the default category budgets.
            #if DEBUG
            self.transactions = SampleData.transactions
            self.goals = SampleData.goals
            #else
            self.transactions = []
            self.goals = []
            #endif
            self.notifications = SampleData.notifications
            self.budgets = CategoryBudget.seed
            self.user = nil
            self.settings = AppSettings()
            store.save(transactions, key: LocalStore.Key.transactions)
            store.save(goals, key: LocalStore.Key.goals)
            store.save(notifications, key: LocalStore.Key.notifications)
            store.save(budgets, key: LocalStore.Key.budgets)
            store.save(settings, key: LocalStore.Key.settings)
            UserDefaults.standard.set(true, forKey: LocalStore.Key.seeded)
        }
    }

    // MARK: - User

    func loadUser() async throws -> CashieUser? {
        withState { user }
    }

    func saveUser(_ user: CashieUser) async throws {
        withState { self.user = user }
        store.save(user, key: LocalStore.Key.user)
    }

    // MARK: - Transactions

    func loadTransactions() async throws -> [Transaction] {
        withState { transactions.sorted { $0.date > $1.date } }
    }

    func addTransaction(_ tx: Transaction) async throws {
        let snapshot = withState { () -> [Transaction] in
            transactions.insert(tx, at: 0)
            return transactions
        }
        store.save(snapshot, key: LocalStore.Key.transactions)
    }

    func updateTransaction(_ tx: Transaction) async throws {
        let snapshot = withState { () -> [Transaction] in
            if let idx = transactions.firstIndex(where: { $0.id == tx.id }) {
                transactions[idx] = tx
            } else {
                transactions.insert(tx, at: 0)
            }
            return transactions
        }
        store.save(snapshot, key: LocalStore.Key.transactions)
    }

    func deleteTransaction(_ id: UUID) async throws {
        let snapshot = withState { () -> [Transaction] in
            transactions.removeAll { $0.id == id }
            return transactions
        }
        store.save(snapshot, key: LocalStore.Key.transactions)
    }

    // MARK: - Bulk replace (used when a remote pull rehydrates local state)

    func replaceTransactions(_ txs: [Transaction]) async throws {
        withState { transactions = txs }
        store.save(txs, key: LocalStore.Key.transactions)
    }

    func replaceGoals(_ goals: [Goal]) async throws {
        withState { self.goals = goals }
        store.save(goals, key: LocalStore.Key.goals)
    }

    func replaceNotifications(_ ns: [AppNotification]) async throws {
        withState { notifications = ns }
        store.save(ns, key: LocalStore.Key.notifications)
    }

    // MARK: - Goals

    func loadGoals() async throws -> [Goal] {
        withState { goals }
    }

    func saveGoal(_ goal: Goal) async throws {
        let snapshot = withState { () -> [Goal] in
            if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[idx] = goal
            } else {
                goals.append(goal)
            }
            return goals
        }
        store.save(snapshot, key: LocalStore.Key.goals)
    }

    func deleteGoal(_ id: UUID) async throws {
        let snapshot = withState { () -> [Goal] in
            goals.removeAll { $0.id == id }
            return goals
        }
        store.save(snapshot, key: LocalStore.Key.goals)
    }

    // MARK: - Notifications

    func loadNotifications() async throws -> [AppNotification] {
        withState { notifications.sorted { $0.date > $1.date } }
    }

    func markNotificationsRead() async throws {
        let snapshot = withState { () -> [AppNotification] in
            notifications = notifications.map { var n = $0; n.isUnread = false; return n }
            return notifications
        }
        store.save(snapshot, key: LocalStore.Key.notifications)
    }

    // MARK: - Budgets

    func loadBudgets() async throws -> [CategoryBudget] {
        withState { budgets }
    }

    func saveBudgets(_ budgets: [CategoryBudget]) async throws {
        withState { self.budgets = budgets }
        store.save(budgets, key: LocalStore.Key.budgets)
    }

    // MARK: - Settings

    func loadSettings() async throws -> AppSettings {
        withState { settings }
    }

    func saveSettings(_ settings: AppSettings) async throws {
        withState { self.settings = settings }
        store.save(settings, key: LocalStore.Key.settings)
    }
}

// MARK: - Sync status indicator
//
// Tiny observable the UI watches to show a small "Saving…/Saved" pill while an
// action is in flight. `activeCount` is bumped when an action starts and
// dropped when it finishes (success, failure, OR timeout), so the indicator can
// never get permanently stuck on one operation. See `SyncStatusBar` in
// RootView for the matching view.
@MainActor
final class SyncIndicator: ObservableObject {
    @Published private(set) var activeCount: Int = 0
    /// Number of writes that are saved locally but still waiting to reach the
    /// server. Surfaced for diagnostics; the user's data is safe regardless.
    @Published private(set) var pendingSync: Int = 0

    var isActive: Bool { activeCount > 0 }

    func begin() { activeCount += 1 }
    func end() { activeCount = max(0, activeCount - 1) }
    func setPending(_ n: Int) { pendingSync = max(0, n) }
}

// MARK: - Offline outbox (durable retry queue for remote sync)
//
// A pending remote operation, persisted to disk so a write survives an app
// kill and flushes once connectivity / auth is available. The actual entity is
// JSON in `payload`; deletes store the raw UUID string.
struct PendingOp: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case addTransaction, updateTransaction, deleteTransaction
        case saveGoal, deleteGoal
        case saveUser, saveBudgets, saveSettings
        case markNotificationsRead
    }
    var id: UUID = UUID()
    var kind: Kind
    var payload: Data
    /// Collapses superseded ops (e.g. repeated saves of the same goal keep only
    /// the latest). `nil` = never collapse.
    var dedupeKey: String?
}

// MARK: - Offline-first sync engine
//
// The single `SupabaseService` the app actually talks to. It is offline-first:
//
//   • Reads come straight from the durable on-device store (instant, works with
//     no network).
//   • Writes hit the on-device store FIRST (so data is never lost), then are
//     pushed to Supabase in the background with a retry outbox.
//   • A small loading indicator reflects in-flight work and always resolves.
//   • If Supabase is unreachable or not configured, the app keeps working
//     exactly as normal on the local store; queued ops flush later.
//   • When a remote is present it also pulls on launch/foreground and can
//     subscribe to realtime changes, keeping every device in sync.
//
// `local` is the durable store (the file-backed MockSupabaseService). `remote`
// is the optional live Supabase service. The engine is an actor so its outbox
// and flags are race-free.
actor SyncEngine: SupabaseService {
    private let local: SupabaseService
    private let remote: SupabaseService?
    private let indicator: SyncIndicator
    private let store = LocalStore.shared

    private var outbox: [PendingOp]
    private var isFlushing = false
    /// Set when the remote reports it can't be used this session (e.g. no auth
    /// token yet). Stops us from hammering a dead endpoint or stalling writes.
    private var remoteDisabled = false
    /// Invoked on the main actor after remote data has been merged into local,
    /// so the container can refresh its published snapshots.
    private var onRemoteMerge: (@Sendable @MainActor () -> Void)?

    private let pushTimeout: UInt64 = 12_000_000_000  // 12s in nanoseconds

    init(local: SupabaseService, remote: SupabaseService?, indicator: SyncIndicator) {
        self.local = local
        self.remote = remote
        self.indicator = indicator
        self.outbox = store.load([PendingOp].self, key: LocalStore.Key.outbox) ?? []
    }

    // MARK: Reads (always from the durable local store)

    func loadUser() async throws -> CashieUser? { try await local.loadUser() }
    func loadTransactions() async throws -> [Transaction] { try await local.loadTransactions() }
    func loadGoals() async throws -> [Goal] { try await local.loadGoals() }
    func loadNotifications() async throws -> [AppNotification] { try await local.loadNotifications() }
    func loadBudgets() async throws -> [CategoryBudget] { try await local.loadBudgets() }
    func loadSettings() async throws -> AppSettings { try await local.loadSettings() }

    // MARK: Writes (durable-local first, then background remote)

    func saveUser(_ user: CashieUser) async throws {
        try? await local.saveUser(user)
        await track(.saveUser, payload: encode(user), dedupe: "user") { try await $0.saveUser(user) }
    }

    func addTransaction(_ tx: Transaction) async throws {
        try? await local.addTransaction(tx)
        await track(.addTransaction, payload: encode(tx), dedupe: nil) { try await $0.addTransaction(tx) }
    }

    func updateTransaction(_ tx: Transaction) async throws {
        try? await local.updateTransaction(tx)
        await track(.updateTransaction, payload: encode(tx), dedupe: "tx:\(tx.id.uuidString)") { try await $0.updateTransaction(tx) }
    }

    func deleteTransaction(_ id: UUID) async throws {
        try? await local.deleteTransaction(id)
        await track(.deleteTransaction, payload: encodeID(id), dedupe: nil) { try await $0.deleteTransaction(id) }
    }

    func saveGoal(_ goal: Goal) async throws {
        try? await local.saveGoal(goal)
        await track(.saveGoal, payload: encode(goal), dedupe: "goal:\(goal.id.uuidString)") { try await $0.saveGoal(goal) }
    }

    func deleteGoal(_ id: UUID) async throws {
        try? await local.deleteGoal(id)
        await track(.deleteGoal, payload: encodeID(id), dedupe: nil) { try await $0.deleteGoal(id) }
    }

    func saveBudgets(_ budgets: [CategoryBudget]) async throws {
        try? await local.saveBudgets(budgets)
        await track(.saveBudgets, payload: encode(budgets), dedupe: "budgets") { try await $0.saveBudgets(budgets) }
    }

    func saveSettings(_ settings: AppSettings) async throws {
        try? await local.saveSettings(settings)
        await track(.saveSettings, payload: encode(settings), dedupe: "settings") { try await $0.saveSettings(settings) }
    }

    func markNotificationsRead() async throws {
        try? await local.markNotificationsRead()
        await track(.markNotificationsRead, payload: Data(), dedupe: "notifsRead") { try await $0.markNotificationsRead() }
    }

    // MARK: Indicator-wrapped write tracking

    /// Drives the loading indicator for one action, persists it to the outbox
    /// when a remote exists, and best-effort pushes it now. Always resolves the
    /// indicator (even on failure/timeout), so the spinner can never stick.
    private func track(_ kind: PendingOp.Kind,
                       payload: Data,
                       dedupe: String?,
                       _ send: @escaping @Sendable (SupabaseService) async throws -> Void) async {
        await indicator.begin()
        defer { let ind = indicator; Task { await ind.end() } }

        guard let remote, !remoteDisabled else { return }   // offline / not configured

        // Record durably so the write survives an app kill mid-sync.
        let op = PendingOp(kind: kind, payload: payload, dedupeKey: dedupe)
        enqueue(op)
        await publishPending()

        do {
            try await withTimeoutPush { try await send(remote) }
            // Drop by id, NOT by kind. Dropping by kind takes outbox[firstIndex
            // where kind matches], which after a prior failure can be a DIFFERENT
            // op (e.g. an earlier addTransaction that failed offline). The later
            // push succeeding would then silently delete the earlier op from the
            // outbox, losing that write on the next pull/replace.
            dropOp(id: op.id)
            await publishPending()
            await flush()   // opportunistically drain anything else queued
        } catch {
            if isAuthError(error) { remoteDisabled = true }
            // Leave the op in the outbox to retry later; data is safe locally.
        }
    }

    // MARK: Outbox management (actor-isolated, race-free)

    private func enqueue(_ op: PendingOp) {
        if let key = op.dedupeKey { outbox.removeAll { $0.dedupeKey == key } }
        outbox.append(op)
        persistOutbox()
    }

    private func dropOp(id: UUID) {
        outbox.removeAll { $0.id == id }
        persistOutbox()
    }

    private func persistOutbox() { store.save(outbox, key: LocalStore.Key.outbox) }

    private func publishPending() async {
        let n = outbox.count
        await indicator.setPending(n)
    }

    // MARK: Sync lifecycle (called by the container)

    func setRemoteMergeHandler(_ handler: @escaping @Sendable @MainActor () -> Void) {
        onRemoteMerge = handler
    }

    /// Pulls remote → local, starts realtime, and flushes the outbox. No-op when
    /// there is no configured/authenticated remote.
    func startSync() async {
        guard remote != nil, !remoteDisabled else { return }
        await pullAll()
        startRealtimeIfPossible()
        await flush()
    }

    /// Re-pull + flush, e.g. when returning to the foreground.
    func resync() async {
        guard remote != nil, !remoteDisabled else { return }
        await pullAll()
        await flush()
    }

    /// Drains the outbox one op at a time. Stops on the first failure so we
    /// don't spin against a dead endpoint; the next launch/foreground retries.
    ///
    /// IMPORTANT: actor methods may suspend at `await` points, during which
    /// another actor-isolated call (e.g. `track`'s `dropOp`) can mutate
    /// `outbox`. So we must NOT assume the op at index 0 after we resume is the
    /// same one we picked up. Removing by id (and tolerating "already gone")
    /// prevents the `removeFirst()` empty-collection trap that crashed TestFlight
    /// users right after onboarding screens that fire `saveUser`.
    private func flush() async {
        guard let remote, !remoteDisabled, !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        while let op = outbox.first {
            await indicator.begin()
            var ok = false
            do {
                try await withTimeoutPush { try await self.apply(op, to: remote) }
                ok = true
            } catch {
                if isAuthError(error) { remoteDisabled = true }
            }
            await indicator.end()
            if ok {
                // The op may already have been removed during the await above
                // (e.g. a fresh save with the same dedupeKey collapsed onto it,
                // or another path dropped it). Removing by id is a no-op in that
                // case, instead of trapping on an empty collection.
                if let idx = outbox.firstIndex(where: { $0.id == op.id }) {
                    outbox.remove(at: idx)
                    persistOutbox()
                    await publishPending()
                }
            } else {
                break   // retry later; data already safe locally
            }
        }
    }

    /// Fetches every collection from the remote and writes it into the durable
    /// local store, then asks the container to refresh from local.
    private func pullAll() async {
        guard let remote, !remoteDisabled else { return }
        do {
            let user = try await remote.loadUser()
            let txs = try await remote.loadTransactions()
            let goals = try await remote.loadGoals()
            let notifs = try await remote.loadNotifications()
            let budgets = try await remote.loadBudgets()
            let settings = try await remote.loadSettings()

            if let user { try? await local.saveUser(user) }
            try? await local.replaceTransactions(txs)
            try? await local.replaceGoals(goals)
            try? await local.replaceNotifications(notifs)
            try? await local.saveBudgets(budgets)
            // Streak shields are device-local (see StreakEngine; the remote
            // app_settings row doesn't carry them). Preserve whatever this
            // device already has so a remote pull can't blank them out and
            // silently reset the logging streak.
            var mergedSettings = settings
            mergedSettings.shieldedDayKeys = (try? await local.loadSettings())?.shieldedDayKeys ?? []
            try? await local.saveSettings(mergedSettings)

            if let handler = onRemoteMerge { await handler() }
        } catch {
            if isAuthError(error) { remoteDisabled = true }
        }
    }

    private func startRealtimeIfPossible() {
        guard let rt = remote as? RealtimeCapable else { return }
        rt.startRealtime { [weak self] in self?.scheduleRealtimePull() }
    }

    /// Nonisolated bridge so the synchronous @Sendable realtime callback can hop
    /// back onto the actor to pull, without capturing actor-isolated state.
    private nonisolated func scheduleRealtimePull() {
        Task { await self.pullAll() }
    }

    private func apply(_ op: PendingOp, to remote: SupabaseService) async throws {
        switch op.kind {
        case .addTransaction:    try await remote.addTransaction(decode(op.payload))
        case .updateTransaction: try await remote.updateTransaction(decode(op.payload))
        case .deleteTransaction: try await remote.deleteTransaction(decodeID(op.payload))
        case .saveGoal:          try await remote.saveGoal(decode(op.payload))
        case .deleteGoal:        try await remote.deleteGoal(decodeID(op.payload))
        case .saveUser:          try await remote.saveUser(decode(op.payload))
        case .saveBudgets:       try await remote.saveBudgets(decode(op.payload))
        case .saveSettings:      try await remote.saveSettings(decode(op.payload))
        case .markNotificationsRead: try await remote.markNotificationsRead()
        }
    }

    // MARK: Helpers

    private func withTimeoutPush(_ work: @escaping @Sendable () async throws -> Void) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await work() }
            group.addTask { [pushTimeout] in
                try await Task.sleep(nanoseconds: pushTimeout)
                throw SupabaseError.timedOut
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private func isAuthError(_ error: Error) -> Bool {
        if let e = error as? SupabaseError { return e == .notAuthenticated || e == .notConfigured }
        return false
    }

    private func encode<T: Encodable>(_ v: T) -> Data { (try? JSONEncoder.sync.encode(v)) ?? Data() }
    private func decode<T: Decodable>(_ d: Data) throws -> T { try JSONDecoder.sync.decode(T.self, from: d) }
    private func encodeID(_ id: UUID) -> Data { Data(id.uuidString.utf8) }
    private func decodeID(_ d: Data) throws -> UUID {
        guard let s = String(data: d, encoding: .utf8), let id = UUID(uuidString: s) else {
            throw SupabaseError.decoding
        }
        return id
    }
}

// Shared coders for the outbox payloads (kept consistent with LocalStore).
extension JSONEncoder {
    static let sync: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
}
extension JSONDecoder {
    static let sync: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}

// MARK: - Optional bulk-replace hooks used by remote pull
//
// Default implementations let any SupabaseService accept a wholesale replace
// (used when the remote pull rehydrates the local store). MockSupabaseService
// overrides these to rewrite its files.
extension SupabaseService {
    func replaceTransactions(_ txs: [Transaction]) async throws {}
    func replaceGoals(_ goals: [Goal]) async throws {}
    func replaceNotifications(_ ns: [AppNotification]) async throws {}
}

// MARK: - Errors

enum SupabaseError: Error, Equatable {
    case notConfigured
    case notAuthenticated
    case timedOut
    case http(Int)
    case decoding
}

// MARK: - Realtime capability

protocol RealtimeCapable: AnyObject {
    /// Begin streaming row changes; `onChange` fires (debounced by the caller)
    /// whenever any subscribed table changes. Safe to call more than once.
    func startRealtime(onChange: @escaping @Sendable () -> Void)
    func stopRealtime()
}

// MARK: - Live Supabase service (Foundation-only PostgREST + Realtime)
//
// A dependency-free Supabase client built on URLSession (REST) and
// URLSessionWebSocketTask (Realtime). No SPM package required. It stays DORMANT
// until BOTH a Supabase anon key is set in `Config` AND an access-token
// provider is supplied (i.e. a signed-in Supabase session). Until then every
// method throws `.notAuthenticated` immediately — no network, no hangs — and
// the SyncEngine simply runs the app fully offline on the local store.
//
// To activate: paste the anon key into `Config.supabaseAnonKey` (gitignored
// build). AuthClient then mints a durable anonymous session and injects its
// access token via `tokenProvider`. RLS then scopes every row to auth.uid().
final class LiveSupabaseService: SupabaseService, RealtimeCapable {
    private let baseURL: URL
    private let anonKey: String
    private let tokenProvider: @Sendable () async -> String?
    private let session: URLSession
    private let realtime: RealtimeConnection

    init(baseURL: URL,
         anonKey: String,
         tokenProvider: @escaping @Sendable () async -> String?) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.tokenProvider = tokenProvider
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)
        self.realtime = RealtimeConnection(baseURL: baseURL, anonKey: anonKey, tokenProvider: tokenProvider)
    }

    /// Returns a live service only when a Supabase key is configured. The token
    /// provider defaults to `nil` (no session) so the service stays dormant and
    /// the app remains offline-first until real auth is wired in.
    static func makeIfConfigured(tokenProvider: @escaping @Sendable () async -> String? = { nil }) -> LiveSupabaseService? {
        guard Config.hasSupabase else { return nil }
        return LiveSupabaseService(baseURL: Config.supabaseURL,
                                   anonKey: Config.supabaseAnonKey,
                                   tokenProvider: tokenProvider)
    }

    // MARK: REST plumbing

    private func authToken() async throws -> String {
        guard let token = await tokenProvider(), !token.isEmpty else { throw SupabaseError.notAuthenticated }
        return token
    }

    /// Current user id, parsed from the JWT `sub` claim. Needed to stamp
    /// user_id on inserts (RLS requires user_id == auth.uid()).
    private func currentUserID(_ token: String) throws -> UUID {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { throw SupabaseError.notAuthenticated }
        var b64 = String(segments[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = obj["sub"] as? String,
              let id = UUID(uuidString: sub) else { throw SupabaseError.notAuthenticated }
        return id
    }

    @discardableResult
    private func send(method: String,
                      path: String,
                      query: [URLQueryItem] = [],
                      body: Data? = nil,
                      prefer: String? = nil) async throws -> Data {
        let token = try await authToken()
        guard var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw SupabaseError.notConfigured
        }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw SupabaseError.notConfigured }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.http(-1) }
        guard (200..<300).contains(http.statusCode) else { throw SupabaseError.http(http.statusCode) }
        return data
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        let data = try await send(method: "GET", path: path, query: query)
        return try PG.decoder.decode(T.self, from: data)
    }

    // MARK: User / profile

    func loadUser() async throws -> CashieUser? {
        let rows: [ProfileRow] = try await get("rest/v1/profiles", query: [.init(name: "select", value: "*"), .init(name: "limit", value: "1")])
        return rows.first?.toModel()
    }

    func saveUser(_ user: CashieUser) async throws {
        let token = try await authToken()
        let uid = try currentUserID(token)
        let body = try PG.encoder.encode(ProfileRow(model: user, userID: uid))
        try await send(method: "POST", path: "rest/v1/profiles",
                       query: [.init(name: "on_conflict", value: "user_id")],
                       body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    // MARK: Transactions

    func loadTransactions() async throws -> [Transaction] {
        let rows: [TxRow] = try await get("rest/v1/transactions",
            query: [.init(name: "select", value: "*"), .init(name: "order", value: "occurred_at.desc")])
        return rows.map { $0.toModel() }
    }

    func addTransaction(_ tx: Transaction) async throws {
        let token = try await authToken()
        let uid = try currentUserID(token)
        let body = try PG.encoder.encode(TxRow(model: tx, userID: uid))
        try await send(method: "POST", path: "rest/v1/transactions",
                       query: [.init(name: "on_conflict", value: "id")],
                       body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    // Editing a logged transaction (e.g. changing its category) upserts the
    // same row by id, so the existing record is overwritten in place rather
    // than duplicated.
    func updateTransaction(_ tx: Transaction) async throws {
        try await addTransaction(tx)
    }

    func deleteTransaction(_ id: UUID) async throws {
        try await send(method: "DELETE", path: "rest/v1/transactions",
                       query: [.init(name: "id", value: "eq.\(id.uuidString)")])
    }

    // MARK: Goals + deposits

    func loadGoals() async throws -> [Goal] {
        let rows: [GoalRow] = try await get("rest/v1/goals",
            query: [.init(name: "select", value: "*,deposits(*)"), .init(name: "order", value: "created_at.asc")])
        return rows.map { $0.toModel() }
    }

    func saveGoal(_ goal: Goal) async throws {
        let token = try await authToken()
        let uid = try currentUserID(token)
        // Upsert the goal row.
        let goalBody = try PG.encoder.encode(GoalRow(model: goal, userID: uid))
        try await send(method: "POST", path: "rest/v1/goals",
                       query: [.init(name: "on_conflict", value: "id")],
                       body: goalBody, prefer: "resolution=merge-duplicates,return=minimal")
        // Upsert current deposits.
        if !goal.deposits.isEmpty {
            let depBody = try PG.encoder.encode(goal.deposits.map { DepositRow(model: $0, goalID: goal.id, userID: uid) })
            try await send(method: "POST", path: "rest/v1/deposits",
                           query: [.init(name: "on_conflict", value: "id")],
                           body: depBody, prefer: "resolution=merge-duplicates,return=minimal")
        }
        // Delete deposits that were removed locally.
        let keepIDs = goal.deposits.map { $0.id.uuidString }.joined(separator: ",")
        let notIn = goal.deposits.isEmpty ? "" : "&id=not.in.(\(keepIDs))"
        try await send(method: "DELETE", path: "rest/v1/deposits",
                       query: [.init(name: "goal_id", value: "eq.\(goal.id.uuidString)")]
                               + (goal.deposits.isEmpty ? [] : [URLQueryItem(name: "id", value: "not.in.(\(keepIDs))")]))
        _ = notIn   // (query item form above is authoritative; string kept for clarity)
    }

    func deleteGoal(_ id: UUID) async throws {
        // Deposits cascade via the FK, but delete explicitly for older rows.
        _ = try? await send(method: "DELETE", path: "rest/v1/deposits",
                            query: [.init(name: "goal_id", value: "eq.\(id.uuidString)")])
        try await send(method: "DELETE", path: "rest/v1/goals",
                       query: [.init(name: "id", value: "eq.\(id.uuidString)")])
    }

    // MARK: Notifications

    func loadNotifications() async throws -> [AppNotification] {
        let rows: [NotificationRow] = try await get("rest/v1/notifications",
            query: [.init(name: "select", value: "*"), .init(name: "order", value: "occurred_at.desc")])
        return rows.map { $0.toModel() }
    }

    func markNotificationsRead() async throws {
        let body = try PG.encoder.encode(["is_unread": false])
        try await send(method: "PATCH", path: "rest/v1/notifications",
                       query: [.init(name: "is_unread", value: "eq.true")],
                       body: body, prefer: "return=minimal")
    }

    // MARK: Budgets

    func loadBudgets() async throws -> [CategoryBudget] {
        let rows: [BudgetRow] = try await get("rest/v1/category_budgets", query: [.init(name: "select", value: "*")])
        let mapped = rows.compactMap { $0.toModel() }
        return mapped.isEmpty ? CategoryBudget.seed : mapped
    }

    func saveBudgets(_ budgets: [CategoryBudget]) async throws {
        let token = try await authToken()
        let uid = try currentUserID(token)
        let body = try PG.encoder.encode(budgets.map { BudgetRow(model: $0, userID: uid) })
        try await send(method: "POST", path: "rest/v1/category_budgets",
                       query: [.init(name: "on_conflict", value: "user_id,category")],
                       body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    // MARK: Settings

    func loadSettings() async throws -> AppSettings {
        let rows: [AppSettingsRow] = try await get("rest/v1/app_settings", query: [.init(name: "select", value: "*"), .init(name: "limit", value: "1")])
        return rows.first?.toModel() ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) async throws {
        let token = try await authToken()
        let uid = try currentUserID(token)
        let body = try PG.encoder.encode(AppSettingsRow(model: settings, userID: uid))
        try await send(method: "POST", path: "rest/v1/app_settings",
                       query: [.init(name: "on_conflict", value: "user_id")],
                       body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    // MARK: Realtime

    func startRealtime(onChange: @escaping @Sendable () -> Void) { realtime.start(onChange: onChange) }
    func stopRealtime() { realtime.stop() }
}

// Shared PostgREST coders. timestamptz ↔ ISO-8601 (with/without fractional
// seconds); `date` columns are handled as plain yyyy-MM-dd strings in the DTOs.
enum PG {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(isoFractional.string(from: date))
        }
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let date = isoFractional.date(from: s) ?? isoPlain.date(from: s) { return date }
            throw SupabaseError.decoding
        }
        return d
    }()
    static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
    static let dateOnly: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"; return f
    }()
}

// MARK: - Row DTOs (snake_case DB shape ↔ app models)

private struct ProfileRow: Codable {
    var user_id: String
    var first_name: String
    var email: String?
    var archetype_id: String
    var traits: [TraitRow]
    var has_face_id: Bool
    var has_notifications: Bool
    var quick_log_setup: Bool
    // Marketing snapshot (jsonb columns). Optional so older rows without these
    // columns still decode cleanly.
    var quiz_answers: [String: String]?
    var relatability_chips: [String]?

    init(model u: CashieUser, userID: UUID) {
        user_id = userID.uuidString
        first_name = u.firstName
        email = u.email
        archetype_id = u.archetype.id.rawValue
        traits = u.traits.map { TraitRow(trait: $0.trait.rawValue, score: $0.score, blurb: $0.blurb) }
        has_face_id = u.hasFaceID
        has_notifications = u.hasNotifications
        quick_log_setup = u.quickLogSetup
        quiz_answers = u.quizAnswers
        relatability_chips = u.relatabilityChips
    }

    func toModel() -> CashieUser {
        var u = CashieUser()
        if let id = UUID(uuidString: user_id) { u.id = id }
        u.firstName = first_name
        u.email = email
        if let aid = ArchetypeID(rawValue: archetype_id) { u.archetype = Archetype.by(id: aid) }
        u.traits = traits.compactMap { row in
            guard let tid = TraitID(rawValue: row.trait) else { return nil }
            return Trait(trait: tid, score: row.score, blurb: row.blurb)
        }
        u.hasFaceID = has_face_id
        u.hasNotifications = has_notifications
        u.quickLogSetup = quick_log_setup
        u.quizAnswers = quiz_answers ?? [:]
        u.relatabilityChips = relatability_chips ?? []
        return u
    }
}

private struct TraitRow: Codable { var trait: String; var score: Int; var blurb: String }

private struct TxRow: Codable {
    var id: String
    var user_id: String
    var merchant: String
    var amount: Double
    var category: String
    var occurred_at: Date
    var note: String?
    var source: String

    init(model t: Transaction, userID: UUID) {
        id = t.id.uuidString; user_id = userID.uuidString
        merchant = t.merchant; amount = t.amount
        category = t.category.rawValue; occurred_at = t.date
        note = t.note; source = t.source.rawValue
    }

    func toModel() -> Transaction {
        Transaction(
            id: UUID(uuidString: id) ?? UUID(),
            merchant: merchant,
            amount: amount,
            category: SpendCategory(rawValue: category) ?? .other,
            date: occurred_at,
            note: note,
            source: Transaction.Source(rawValue: source) ?? .manual
        )
    }
}

private struct GoalRow: Codable {
    var id: String
    var user_id: String
    var emoji: String
    var name: String
    var target_amount: Double
    var current_amount: Double
    var target_date: String          // DB `date` column → yyyy-MM-dd
    var archived_at: Date?
    var deposits: [DepositRow]?

    init(model g: Goal, userID: UUID) {
        id = g.id.uuidString; user_id = userID.uuidString
        emoji = g.emoji; name = g.name
        target_amount = g.targetAmount; current_amount = g.currentAmount
        target_date = PG.dateOnly.string(from: g.targetDate)
        archived_at = g.archivedAt
        deposits = nil   // deposits are written to their own table
    }

    enum CodingKeys: String, CodingKey {
        case id, user_id, emoji, name, target_amount, current_amount
        case target_date, archived_at, deposits
    }

    /// Custom encoder so `archived_at = nil` is written as JSON `null` rather
    /// than omitted. Swift's synthesised `Encodable` uses `encodeIfPresent` for
    /// optionals, which made the PostgREST upsert (`resolution=merge-duplicates`)
    /// silently keep the previous `archived_at` value — so restoring a goal from
    /// Past wins set `archivedAt = nil` locally, but the round-trip pull put it
    /// straight back into Past wins.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(user_id, forKey: .user_id)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(name, forKey: .name)
        try c.encode(target_amount, forKey: .target_amount)
        try c.encode(current_amount, forKey: .current_amount)
        try c.encode(target_date, forKey: .target_date)
        if let archived_at {
            try c.encode(archived_at, forKey: .archived_at)
        } else {
            try c.encodeNil(forKey: .archived_at)
        }
        try c.encodeIfPresent(deposits, forKey: .deposits)
    }

    func toModel() -> Goal {
        Goal(
            id: UUID(uuidString: id) ?? UUID(),
            emoji: emoji,
            name: name,
            targetAmount: target_amount,
            currentAmount: current_amount,
            targetDate: PG.dateOnly.date(from: target_date) ?? Date(),
            deposits: (deposits ?? []).map { $0.toModel() }.sorted { $0.date > $1.date },
            archivedAt: archived_at
        )
    }
}

private struct DepositRow: Codable {
    var id: String
    var goal_id: String
    var user_id: String
    var amount: Double
    var added_by: String
    var occurred_at: Date

    init(model d: Deposit, goalID: UUID, userID: UUID) {
        id = d.id.uuidString; goal_id = goalID.uuidString; user_id = userID.uuidString
        amount = d.amount; added_by = d.addedBy; occurred_at = d.date
    }

    func toModel() -> Deposit {
        Deposit(id: UUID(uuidString: id) ?? UUID(), amount: amount, date: occurred_at, addedBy: added_by)
    }
}

private struct NotificationRow: Codable {
    var id: String
    var user_id: String
    var emoji: String
    var title: String
    var body: String
    var kind: String
    var occurred_at: Date
    var is_unread: Bool

    func toModel() -> AppNotification {
        AppNotification(
            id: UUID(uuidString: id) ?? UUID(),
            emoji: emoji, title: title, body: body,
            date: occurred_at, isUnread: is_unread,
            kind: AppNotification.Kind(rawValue: kind) ?? .insight
        )
    }
}

private struct BudgetRow: Codable {
    var user_id: String
    var category: String
    var monthly_cap: Double

    init(model b: CategoryBudget, userID: UUID) {
        user_id = userID.uuidString; category = b.category.rawValue; monthly_cap = b.monthlyCap
    }

    func toModel() -> CategoryBudget? {
        guard let cat = SpendCategory(rawValue: category) else { return nil }
        return CategoryBudget(category: cat, monthlyCap: monthly_cap)
    }
}

private struct AppSettingsRow: Codable {
    var user_id: String
    var privacy_lock_enabled: Bool
    var daily_reminder_enabled: Bool
    var daily_reminder_hour: Int
    var daily_reminder_minute: Int
    var last_seen_rank: Int
    var celebrated_badge_ids: [String]
    var badge_baseline_seeded: Bool

    init(model s: AppSettings, userID: UUID) {
        user_id = userID.uuidString
        privacy_lock_enabled = s.privacyLockEnabled
        daily_reminder_enabled = s.dailyReminderEnabled
        daily_reminder_hour = s.dailyReminderHour
        daily_reminder_minute = s.dailyReminderMinute
        last_seen_rank = s.lastSeenRankRaw
        celebrated_badge_ids = s.celebratedBadgeIDs
        badge_baseline_seeded = s.badgeBaselineSeeded
    }

    func toModel() -> AppSettings {
        var s = AppSettings()
        s.privacyLockEnabled = privacy_lock_enabled
        s.dailyReminderEnabled = daily_reminder_enabled
        s.dailyReminderHour = daily_reminder_hour
        s.dailyReminderMinute = daily_reminder_minute
        s.lastSeenRankRaw = last_seen_rank
        s.celebratedBadgeIDs = celebrated_badge_ids
        s.badgeBaselineSeeded = badge_baseline_seeded
        return s
    }
}

// MARK: - Realtime connection (Phoenix protocol over URLSessionWebSocketTask)
//
// Minimal, defensive Supabase Realtime client. It connects, joins the public
// schema channel for the per-user tables, keeps the socket alive with a
// heartbeat, and calls `onChange` whenever a postgres change arrives. Every
// failure simply tears down and reconnects with backoff; nothing here can crash
// the app. Dormant unless a token is available.
final class RealtimeConnection: @unchecked Sendable {
    private let baseURL: URL
    private let anonKey: String
    private let tokenProvider: @Sendable () async -> String?

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var onChange: (@Sendable () -> Void)?
    private var running = false
    private var ref = 0

    init(baseURL: URL, anonKey: String, tokenProvider: @escaping @Sendable () async -> String?) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.tokenProvider = tokenProvider
    }

    func start(onChange: @escaping @Sendable () -> Void) {
        guard !running else { return }
        running = true
        self.onChange = onChange
        Task { await connectLoop() }
    }

    func stop() {
        running = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func connectLoop() async {
        var backoff: UInt64 = 1_000_000_000
        while running {
            guard let token = await tokenProvider(), !token.isEmpty else { return }   // dormant without auth
            do {
                try await connectOnce(token: token)
            } catch {
                // fall through to backoff/reconnect
            }
            if !running { return }
            try? await Task.sleep(nanoseconds: backoff)
            backoff = min(backoff * 2, 30_000_000_000)   // cap at 30s
        }
    }

    private func connectOnce(token: String) async throws {
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return }
        comps.scheme = (comps.scheme == "https") ? "wss" : "ws"
        comps.path = "/realtime/v1/websocket"
        comps.queryItems = [.init(name: "apikey", value: anonKey), .init(name: "vsn", value: "1.0.0")]
        guard let url = comps.url else { return }

        let session = URLSession(configuration: .default)
        self.session = session
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()

        ref += 1
        let join = """
        {"topic":"realtime:public","event":"phx_join","payload":{"config":{"postgres_changes":[{"event":"*","schema":"public"}]},"access_token":"\(token)"},"ref":"\(ref)"}
        """
        try await task.send(.string(join))
        await heartbeatTick(task)

        // Receive loop.
        while running {
            let message = try await task.receive()
            if case let .string(text) = message, text.contains("postgres_changes") {
                onChange?()
            }
        }
    }

    private func heartbeatTick(_ task: URLSessionWebSocketTask) async {
        Task { [weak self] in
            while self?.running == true {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                guard let self, self.running else { return }
                self.ref += 1
                let hb = "{\"topic\":\"phoenix\",\"event\":\"heartbeat\",\"payload\":{},\"ref\":\"\(self.ref)\"}"
                try? await task.send(.string(hb))
            }
        }
    }
}
