import SwiftUI
import UserNotifications

struct PermissionsScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var privacyLock: PrivacyLockService
    // Opt-in: both start off so the user actively chooses what they want,
    // rather than having them switched on for them.
    @State private var notifications = false
    @State private var faceID = false

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

                Text("Both off for now. Turn on whatever helps.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    PermissionRow(emoji: "🔔",
                                  title: "Notifications",
                                  desc: "Goal wins, weekly Wrapped, gentle nudges only.",
                                  isOn: $notifications)
                    PermissionRow(emoji: "👤",
                                  title: "Face ID",
                                  desc: "Quick unlock. Keeps spending data private.",
                                  isOn: $faceID)
                }
                .padding(.top, 18)

                Text("You can change either later in Settings → You.")
                    .font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkMute)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)

                Spacer()

                PrimaryButton(title: "Continue") {
                    container.user.hasFaceID = faceID
                    container.user.hasNotifications = notifications
                    // Engage the actual privacy lock when Face ID was enabled.
                    container.settings.privacyLockEnabled = faceID
                    container.advanceOnboarding(to: .backTapIntro)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
            // Turning a toggle on fires the real system dialog. If the user
            // declines, flip it back off so the UI reflects reality.
            .onChange(of: notifications) { on in if on { requestNotifications() } }
            .onChange(of: faceID) { on in if on { requestFaceID() } }
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    if !granted { notifications = false }
                }
            }
    }

    private func requestFaceID() {
        privacyLock.authenticateToEnable { ok in
            if !ok { faceID = false }
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
