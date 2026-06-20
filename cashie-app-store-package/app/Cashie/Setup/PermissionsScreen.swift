import SwiftUI
import UserNotifications

/// Onboarding "permissions" step. Only notifications are surfaced; Face ID was
/// removed (the lock veil and biometric prompt were causing crashes on
/// foreground/background lifecycle right after this screen). The notifications
/// toggle reads the real system authorization status, so users who already
/// allowed see it on, and users who declined see it off.
struct PermissionsScreen: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    /// Latest known iOS authorization status for notifications. Drives the
    /// toggle so it reflects reality, not just local user intent.
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    /// True while the request prompt is in flight, so onChange doesn't fire
    /// twice (once for our optimistic flip, once when status refreshes).
    @State private var requesting = false

    private var notificationsOn: Binding<Bool> {
        Binding(
            get: { notifStatus == .authorized || notifStatus == .provisional },
            set: { newValue in handleToggle(newValue) }
        )
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                BackBar(onBack: { container.advanceOnboarding(to: .nameInput) },
                        pageLabel: "Setup · 01 / 03")

                Text("Optional extras")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(
                    raw: "Want <em>any of these?</em>",
                    font: AppFont.display(34, weight: .bold)
                )

                Text("Turn on what helps. You can change it later in Settings → You.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    PermissionRow(emoji: "🔔",
                                  title: "Notifications",
                                  desc: "Goal wins, weekly Wrapped, gentle nudges only.",
                                  isOn: notificationsOn)
                }
                .padding(.top, 18)

                if notifStatus == .denied {
                    Text("Notifications are off in iOS Settings. Tap above to open Settings, or change it later in Settings → You.")
                        .font(AppFont.text(12))
                        .foregroundColor(Theme.Palette.inkMute)
                        .padding(.top, 4)
                }

                Spacer()

                PrimaryButton(title: "Continue") {
                    let on = notifStatus == .authorized || notifStatus == .provisional
                    container.user.hasNotifications = on
                    // Privacy lock is always off in 1.2 (Face ID removed).
                    container.settings.privacyLockEnabled = false
                    container.user.hasFaceID = false
                    container.advanceOnboarding(to: .backTapIntro)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
        .task { await refreshAuthorizationStatus() }
        .onChange(of: scenePhase) { phase in
            // Returning from iOS Settings should refresh the toggle.
            if phase == .active {
                Task { await refreshAuthorizationStatus() }
            }
        }
    }

    private func handleToggle(_ newValue: Bool) {
        if newValue {
            switch notifStatus {
            case .notDetermined:
                requestNotifications()
            case .denied:
                // Can't re-prompt once denied; send the user to iOS Settings.
                openSystemSettings()
            case .authorized, .provisional, .ephemeral:
                break  // Already on; nothing to do.
            @unknown default:
                requestNotifications()
            }
        } else {
            // System notifications can only be turned off via iOS Settings.
            openSystemSettings()
        }
    }

    private func requestNotifications() {
        guard !requesting else { return }
        requesting = true
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                Task { @MainActor in
                    requesting = false
                    await refreshAuthorizationStatus()
                }
            }
    }

    private func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { notifStatus = settings.authorizationStatus }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

private struct PermissionRow: View {
    let emoji: String
    let title: String
    let desc: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 13).fill(Theme.Palette.goldPastel))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(AppFont.text(15, weight: .semibold))
                Text(desc).font(AppFont.text(13))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.Palette.gold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
    }
}
