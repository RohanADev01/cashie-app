import Foundation

/// JSON-on-disk persistence. One file per collection inside the app's
/// Application Support directory so transactions, goals, budgets, user
/// profile, notifications and settings survive relaunches.
///
/// On first run, no file exists; callers fall back to seed data and persist
/// it on the first write.
final class LocalStore {
    static let shared = LocalStore()

    private let queue = DispatchQueue(label: "cashie.localstore", qos: .utility)
    private let fm = FileManager.default
    private let baseURL: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        let support = (try? fm.url(for: .applicationSupportDirectory,
                                   in: .userDomainMask,
                                   appropriateFor: nil,
                                   create: true)) ?? fm.temporaryDirectory
        var dir = support.appendingPathComponent("Cashie", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        // Keep this plaintext financial data out of iCloud / iTunes / Finder
        // backups. It re-syncs from Supabase when sync is enabled, so excluding
        // it is lossless and stops the data leaking into an unencrypted backup.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        self.baseURL = dir
    }

    private func url(for key: String) -> URL {
        baseURL.appendingPathComponent("\(key).json")
    }

    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        queue.sync {
            let u = url(for: key)
            guard let data = try? Data(contentsOf: u) else { return nil }
            return try? decoder.decode(T.self, from: data)
        }
    }

    func save<T: Encodable>(_ value: T, key: String) {
        queue.sync {
            let u = url(for: key)
            if let data = try? encoder.encode(value) {
                // Encrypt at rest and make unreadable while the device is locked.
                try? data.write(to: u, options: [.atomic, .completeFileProtection])
            }
        }
    }

    /// Delete the file backing a single key (used to clear an optional value such
    /// as income, where saving an encoded `null` would otherwise linger).
    func remove(key: String) {
        queue.sync {
            try? fm.removeItem(at: url(for: key))
        }
    }

    func wipe() {
        queue.sync {
            guard let entries = try? fm.contentsOfDirectory(atPath: baseURL.path) else { return }
            for name in entries {
                try? fm.removeItem(atPath: baseURL.appendingPathComponent(name).path)
            }
        }
    }
}

extension LocalStore {
    enum Key {
        static let user = "user"
        static let transactions = "transactions"
        static let goals = "goals"
        static let notifications = "notifications"
        static let budgets = "budgets"
        static let settings = "settings"
        /// Recurring bills (local-only, on-device). The transactions they auto-post
        /// sync via the normal transaction path; the rule definitions stay local.
        static let bills = "bills"
        /// The user's single income (local-only, on-device). Same rationale as bills.
        static let income = "income"
        static let seeded = "seededFlag"
        /// Durable queue of pending remote-sync operations (the offline outbox).
        static let outbox = "syncOutbox"
        /// Local-only onboarding progress (current step + in-flight quiz answers
        /// / relatability chips) used to resume onboarding after a relaunch.
        /// Never synced; routing must not depend on the network.
        static let onboarding = "onboardingProgress"
        /// Durable buffer of analytics events not yet delivered to PostHog.
        static let analyticsOutbox = "analyticsOutbox"
    }
}
