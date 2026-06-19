import Foundation

/// Hand-rolled Supabase (GoTrue) auth client. Gives every install a durable
/// anonymous session so RLS-scoped writes work and the app has a stable
/// `auth.uid()` that analytics + the backend can share. No third-party SDK: plain
/// URLSession against the GoTrue REST endpoints, mirroring `LiveSupabaseService`.
///
/// Dormant unless `Config.hasSupabase` (an anon key is present). When dormant
/// the initialiser returns `nil`, `accessToken()` is never called, and the app
/// stays fully offline-first on the local store.
///
/// The session (access + refresh token, expiry, user id) is cached in memory and
/// persisted to the Keychain so it survives relaunches. We only care about users
/// who keep the app installed: deleting the app drops the session and a fresh
/// anonymous identity is minted on next launch (by design).
///
/// An actor so concurrent token requests (the SyncEngine pushing while bootstrap
/// reads the uid) serialise and never spawn duplicate anonymous users.
actor AuthClient {
    struct Session: Codable, Sendable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var userID: String
    }

    private let baseURL: URL
    private let anonKey: String
    private let session: URLSession
    private let keychainAccount = "supabaseAuthSession"

    private var cached: Session?
    /// In-flight establish/refresh, shared by concurrent callers.
    private var inFlight: Task<Session?, Never>?

    init?(baseURL: URL = Config.supabaseURL, anonKey: String = Config.supabaseAnonKey) {
        guard Config.hasSupabase else { return nil }
        self.baseURL = baseURL
        self.anonKey = anonKey
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)
        self.cached = Self.loadFromKeychain(account: keychainAccount)
    }

    // MARK: - Public

    /// A valid access token, establishing or refreshing the session as needed.
    /// `nil` when Supabase auth is unavailable (anonymous sign-ins disabled, or
    /// offline on first run) — the caller then stays offline-first.
    func accessToken() async -> String? {
        await validSession()?.accessToken
    }

    /// The current user id (`auth.uid()`), establishing a session if needed.
    func userID() async -> UUID? {
        guard let s = await validSession() else { return nil }
        return UUID(uuidString: s.userID)
    }

    // MARK: - Session lifecycle

    private func validSession() async -> Session? {
        // Fast path: a still-valid cached token (60s skew guard).
        if let s = cached, s.expiresAt.timeIntervalSinceNow > 60 { return s }
        // Coalesce concurrent establish/refresh into one network call.
        if let task = inFlight { return await task.value }

        let snapshot = cached
        let task = Task<Session?, Never> {
            if let s = snapshot {
                // Have a session but the access token expired: refresh it. On
                // failure we return nil (stay offline this launch) rather than
                // minting a brand-new anonymous user, so identity never churns
                // on a transient network blip.
                return await self.refresh(s.refreshToken)
            }
            // No session yet: create a durable anonymous one.
            return await self.signInAnonymously()
        }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }

    private func signInAnonymously() async -> Session? {
        let body = Data(#"{"data":{},"gotrue_meta_security":{}}"#.utf8)
        return await postToken(path: "auth/v1/signup", query: [], body: body)
    }

    private func refresh(_ refreshToken: String) async -> Session? {
        let body = (try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])) ?? Data()
        return await postToken(path: "auth/v1/token",
                               query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                               body: body)
    }

    /// POSTs to a GoTrue endpoint that returns a session token payload, parses it,
    /// and persists the result. Returns nil on any non-2xx / parse failure.
    private func postToken(path: String, query: [URLQueryItem], body: Data) async -> Session? {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { return nil }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        // GoTrue expects the anon key as the bearer too (matches the supabase
        // client's default headers); there is no user token yet at sign-in.
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        guard let (data, response) = try? await session.data(for: req),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let parsed = Self.parse(data) else { return nil }

        cached = parsed
        Self.saveToKeychain(parsed, account: keychainAccount)
        return parsed
    }

    // MARK: - Parsing

    /// Parses a GoTrue token response: `access_token`, `refresh_token`,
    /// `expires_in`/`expires_at`, and the nested `user.id`.
    private static func parse(_ data: Data) -> Session? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String,
              let refresh = obj["refresh_token"] as? String else { return nil }

        let expiresAt: Date
        if let ts = obj["expires_at"] as? Double {
            expiresAt = Date(timeIntervalSince1970: ts)
        } else {
            expiresAt = Date().addingTimeInterval((obj["expires_in"] as? Double) ?? 3600)
        }

        let userID = (obj["user"] as? [String: Any])?["id"] as? String
            ?? subFromJWT(access)
        guard let uid = userID, !uid.isEmpty else { return nil }

        return Session(accessToken: access, refreshToken: refresh, expiresAt: expiresAt, userID: uid)
    }

    /// Extracts the `sub` claim from a JWT without verifying the signature
    /// (server-side RLS does the real enforcement). Mirrors the parser in
    /// `LiveSupabaseService.currentUserID`.
    private static func subFromJWT(_ token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var b64 = String(segments[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["sub"] as? String
    }

    // MARK: - Keychain persistence

    private static func loadFromKeychain(account: String) -> Session? {
        guard let raw = KeychainStore.get(account), let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    private static func saveToKeychain(_ s: Session, account: String) {
        guard let data = try? JSONEncoder().encode(s), let str = String(data: data, encoding: .utf8) else { return }
        KeychainStore.set(str, for: account)
    }
}
