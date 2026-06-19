import Foundation

/// Minimal PostHog analytics over plain URLSession — no SDK, matching the
/// hand-rolled Supabase client. Buffers events to disk and flushes them to
/// PostHog's batch endpoint, so events survive offline periods and app kills.
///
/// Dormant (every call a no-op) until a PostHog key is set in `Config`. The
/// `distinct_id` starts as a stable local anonymous id and is upgraded to the
/// Supabase `auth.uid()` via `identify`, so funnels line up across PostHog
/// and the backend.
///
/// An actor so the event buffer is race-free across the concurrent producers
/// (onboarding transitions, foreground flushes).
actor Analytics {
    private let apiKey: String
    private let batchURL: URL
    private let session: URLSession

    private var distinctID: String
    private var pending: [Event]
    private var flushing = false

    private static let anonAccount = "analyticsAnonID"
    private static let maxBuffered = 500

    init?() {
        guard Config.hasPostHog, let host = URL(string: Config.postHogHost) else { return nil }
        self.apiKey = Config.postHogAPIKey
        self.batchURL = host.appendingPathComponent("batch")
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)

        // Stable anonymous id (Keychain) until identify() upgrades it, so the
        // pre-auth events stitch to the identified user.
        if let existing = KeychainStore.get(Self.anonAccount) {
            self.distinctID = existing
        } else {
            let id = "anon_" + UUID().uuidString
            KeychainStore.set(id, for: Self.anonAccount)
            self.distinctID = id
        }
        self.pending = LocalStore.shared.load([Event].self, key: LocalStore.Key.analyticsOutbox) ?? []
    }

    // MARK: - Public API

    /// Records an event with string-valued properties (kept simple so the buffer
    /// stays Codable). Auto-flushes in the background.
    func capture(_ event: String, _ properties: [String: String] = [:]) {
        enqueue(Event(event: event,
                      distinctID: distinctID,
                      timestamp: Self.iso.string(from: Date()),
                      properties: properties))
    }

    /// Upgrades the identity from the anonymous id to the real user id (the
    /// Supabase uid). Emits a `$identify` that stitches prior anonymous events.
    func identify(_ uid: String) {
        guard !uid.isEmpty, uid != distinctID else { return }
        let anon = distinctID
        distinctID = uid
        enqueue(Event(event: "$identify",
                      distinctID: uid,
                      timestamp: Self.iso.string(from: Date()),
                      properties: [:],
                      anonDistinctID: anon))
    }

    /// Sends anything buffered. Safe to call on launch and every foreground.
    func flush() async {
        guard !flushing, !pending.isEmpty else { return }
        flushing = true
        defer { flushing = false }

        let batch = pending
        var body: [String: Any] = ["api_key": apiKey]
        body["batch"] = batch.map { $0.payload() }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        var req = URLRequest(url: batchURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        guard let (_, response) = try? await session.data(for: req),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            return   // keep the buffer; retry on the next flush
        }

        // Drop exactly the events we sent. Anything captured during the await
        // (actor re-entrancy) was appended after `batch`, so it survives.
        if pending.count >= batch.count {
            pending.removeFirst(batch.count)
        } else {
            pending.removeAll()
        }
        persist()
    }

    // MARK: - Internals

    private func enqueue(_ event: Event) {
        pending.append(event)
        if pending.count > Self.maxBuffered {
            pending.removeFirst(pending.count - Self.maxBuffered)
        }
        persist()
        Task { await flush() }
    }

    private func persist() {
        LocalStore.shared.save(pending, key: LocalStore.Key.analyticsOutbox)
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// A buffered analytics event. String-only properties keep it Codable; the
    /// nested PostHog shape is assembled in `payload()` at flush time.
    struct Event: Codable, Sendable {
        var event: String
        var distinctID: String
        var timestamp: String
        var properties: [String: String]
        var anonDistinctID: String?

        func payload() -> [String: Any] {
            var props: [String: Any] = properties
            props["distinct_id"] = distinctID
            if let anonDistinctID { props["$anon_distinct_id"] = anonDistinctID }
            return ["event": event, "timestamp": timestamp, "properties": props]
        }
    }
}
