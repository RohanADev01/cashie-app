import Foundation
import SwiftUI
import UIKit

/// Face ID privacy lock was removed in 1.2. This service is kept as a no-op
/// stub for source compatibility (RootView, PermissionsScreen, CashieApp still
/// reference it via @EnvironmentObject), but it never locks the app, never
/// shows the veil, and never prompts for biometrics. Users upgrading from 1.1
/// who had the lock enabled simply have it disabled on next launch.
///
/// The old LocalAuthentication path was the cause of crashes on lifecycle
/// transitions and the toggle-revert behaviour reported in TestFlight.
@MainActor
final class PrivacyLockService: ObservableObject {
    /// Always false. Kept @Published so SwiftUI views that observe it compile
    /// unchanged; with the stub it never flips on.
    @Published private(set) var isLocked: Bool = false
    /// Always false (we no longer evaluate biometric capability).
    @Published private(set) var canEvaluate: Bool = false

    init() {}

    /// Disables any persisted privacy-lock setting so a 1.1 user who had the
    /// lock on doesn't get stuck behind an invisible veil. Container calls
    /// this once after bootstrap.
    func attach(to container: AppContainer) {
        if container.settings.privacyLockEnabled {
            container.settings.privacyLockEnabled = false
        }
        if container.user.hasFaceID {
            container.user.hasFaceID = false
        }
    }

    /// No-op: there is no lock veil in 1.2+.
    func requestUnlockIfNeeded() {}

    /// No-op: biometric eligibility is irrelevant now.
    func verifyEligibility() -> Bool { false }

    /// No-op: the Face ID enrollment prompt was removed. The completion is
    /// reported as `false` so any lingering caller treats the toggle as "off".
    func authenticateToEnable(_ completion: @escaping (Bool) -> Void) {
        completion(false)
    }
}

/// Retained so previously-presented views compile, but never shown.
struct PrivacyLockVeil: View {
    let onUnlock: () -> Void
    var body: some View { EmptyView() }
}
