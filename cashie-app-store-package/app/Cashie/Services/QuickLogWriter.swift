import Foundation

/// UI-free, process-safe writer used by background App Intents (Back Tap,
/// Action Button, Siri) to log a spend without launching the app's UI.
///
/// A silent intent runs in a short-lived instance of the app process that has
/// no `AppContainer` and no SwiftUI graph, so it must NOT go through
/// `AppContainer.addTransaction`. Instead it appends straight to the durable
/// layer the app already reconciles on next launch/foreground:
///   1. `LocalStore.transactions` so the entry shows the next time the app opens,
///      even fully offline.
///   2. `LocalStore.outbox` as a `PendingOp(.addTransaction)`, identical to what
///      `SyncEngine` writes, so it syncs to Supabase once a remote/auth is live.
actor QuickLogWriter {
    static let shared = QuickLogWriter()
    private let store = LocalStore.shared

    func write(_ tx: Transaction) {
        // 1) Durable local truth.
        var txs = store.load([Transaction].self, key: LocalStore.Key.transactions) ?? []
        txs.insert(tx, at: 0)
        store.save(txs, key: LocalStore.Key.transactions)

        // 2) Outbox op, so it reaches Supabase when the app next syncs. Matches
        // the encoding SyncEngine uses for its own pending ops.
        var outbox = store.load([PendingOp].self, key: LocalStore.Key.outbox) ?? []
        let payload = (try? JSONEncoder.sync.encode(tx)) ?? Data()
        outbox.append(PendingOp(kind: .addTransaction, payload: payload, dedupeKey: nil))
        store.save(outbox, key: LocalStore.Key.outbox)
    }

    /// A natural fallback name when the user didn't label the spend, matching the
    /// in-app Quick Log defaults.
    nonisolated static func defaultMerchant(for category: SpendCategory) -> String {
        switch category {
        case .food: return "Food"
        case .transport: return "Transit"
        case .shopping: return "Shopping"
        case .fun: return "Fun out"
        case .home: return "Home"
        case .health: return "Health"
        case .bills: return "Bill"
        case .income: return "Income"
        case .other: return "Other"
        }
    }
}
