import Foundation
import LocalAuthentication
import SwiftUI
import UIKit

/// Gates the app behind biometric/device-passcode auth when the user has
/// turned on "Privacy lock" in settings. Re-locks when the app moves to
/// the background and re-evaluates on foreground.
@MainActor
final class PrivacyLockService: ObservableObject {
    @Published private(set) var isLocked: Bool = false
    @Published private(set) var canEvaluate: Bool

    private weak var settingsSource: AppContainer?
    private var didEnterBackgroundObserver: NSObjectProtocol?
    private var willResignActiveObserver: NSObjectProtocol?
    private var willEnterForegroundObserver: NSObjectProtocol?

    init() {
        var error: NSError?
        let context = LAContext()
        self.canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Wires the service to the container so it can read the persisted
    /// `privacyLockEnabled` flag at the right moment.
    func attach(to container: AppContainer) {
        self.settingsSource = container
        observeLifecycle()
    }

    private func observeLifecycle() {
        let center = NotificationCenter.default
        didEnterBackgroundObserver = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lockIfEnabled()
            }
        }
        // Raise the veil the instant the app deactivates (app switcher, Control
        // Center, an incoming call) so the system snapshot can never capture
        // balances or transactions while the lock is enabled.
        willResignActiveObserver = center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lockIfEnabled()
            }
        }
        willEnterForegroundObserver = center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestUnlockIfNeeded()
            }
        }
    }

    private func lockIfEnabled() {
        guard let source = settingsSource, source.settings.privacyLockEnabled else { return }
        isLocked = true
    }

    func requestUnlockIfNeeded() {
        guard isLocked else { return }
        guard canEvaluate else {
            #if targetEnvironment(simulator)
            // Simulator has no biometrics: passthrough so dev work isn't blocked.
            isLocked = false
            #else
            // Real device that cannot evaluate biometrics/passcode: fail CLOSED.
            // Never auto-reveal financial data; the user retries from the veil.
            #endif
            return
        }
        let context = LAContext()
        context.localizedFallbackTitle = "Use passcode"
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Unlock Cashie") { [weak self] success, _ in
            Task { @MainActor in
                if success { self?.isLocked = false }
            }
        }
    }

    /// Called when the user toggles the privacy lock on; verifies the device
    /// can actually evaluate before letting them enable.
    func verifyEligibility() -> Bool {
        var error: NSError?
        let context = LAContext()
        let ok = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        canEvaluate = ok
        return ok
    }

    /// Prompts Face ID / device passcode so the user can confirm turning the
    /// lock on, and reports whether they authenticated. On a simulator without
    /// enrolled biometrics it returns true so testing isn't blocked.
    func authenticateToEnable(_ completion: @escaping (Bool) -> Void) {
        var error: NSError?
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            #if targetEnvironment(simulator)
            completion(true)
            #else
            completion(false)
            #endif
            return
        }
        context.localizedFallbackTitle = "Use passcode"
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Turn on Face ID to lock Cashie") { success, _ in
            Task { @MainActor in completion(success) }
        }
    }
}

/// Full-screen veil shown while the app is locked.
struct PrivacyLockVeil: View {
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Theme.Palette.gold)
                    .padding(20)
                    .background(Circle().fill(Theme.Palette.goldPastel))
                Text("Cashie is locked")
                    .font(AppFont.display(28, weight: .bold))
                Text("Authenticate to see your money.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)
                Button(action: onUnlock) {
                    Text("Unlock")
                        .font(AppFont.text(15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.Palette.ink))
                }
                .buttonStyle(.plainTappable)
                .padding(.top, 6)
            }
        }
    }
}
