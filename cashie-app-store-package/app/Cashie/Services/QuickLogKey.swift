import Foundation
import Security

/// Keychain storage for the per-user Quick Log API key the user pastes into the
/// imported Shortcut's `x-api-key` field. Format: `qlk_` + 48 hex (192-bit).
///
/// The real key is **server-minted** by the `mint-quick-log-key` edge function
/// (which verifies the caller's `pro` entitlement and registers the key's hash),
/// then cached here. See `AppContainer.quickLogKey`. A locally-generated key is
/// only used as a dev fallback when no Supabase backend is configured, so the
/// setup card still has something to show in previews; it is inert server-side.
enum QuickLogKey {
    /// Account holding the server-minted key (the one the endpoint accepts).
    private static let account = "quickLogApiKey"
    /// Separate account for the dev-only inert fallback, so it can never shadow
    /// a real minted key once a backend is configured.
    private static let devAccount = "quickLogApiKeyDev"

    /// The cached server-minted key, if one has been issued on this device.
    static func cached() -> String? {
        guard let k = KeychainStore.get(account), k.hasPrefix("qlk_") else { return nil }
        return k
    }

    static func store(_ key: String) { KeychainStore.set(key, for: account) }
    static func clear() { KeychainStore.delete(account) }

    /// Local, inert key used only when no Supabase backend is configured (dev /
    /// SwiftUI previews) so the setup card still renders. Never accepted by the
    /// server — real keys come from the mint endpoint.
    static func localFallback() -> String {
        if let k = KeychainStore.get(devAccount), k.hasPrefix("qlk_") { return k }
        let k = generateLocal()
        KeychainStore.set(k, for: devAccount)
        return k
    }

    /// Display form that hides the middle so the full secret isn't shown by default.
    static func masked(_ key: String) -> String {
        guard key.count > 12 else { return "••••" }
        return "\(key.prefix(8))••••••••\(key.suffix(4))"
    }

    private static func generateLocal() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
            return "qlk_" + bytes.map { String(format: "%02x", $0) }.joined()
        }
        // Fallback only if the RNG is unavailable; still high-entropy.
        let s = (UUID().uuidString + UUID().uuidString)
            .replacingOccurrences(of: "-", with: "").lowercased()
        return "qlk_" + String(s.prefix(48))
    }
}
