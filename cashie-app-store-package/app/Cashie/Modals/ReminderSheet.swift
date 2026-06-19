import SwiftUI

/// Single-screen daily reminder configuration. One toggle, one time picker.
struct ReminderSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                toggleCard
                if container.settings.dailyReminderEnabled {
                    timeCard
                }
                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .onChange(of: container.settings) { newValue in
            Task { await ReminderScheduler.sync(with: newValue) }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications").font(AppFont.title2)
                Text("One nudge, your choice when.")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6).textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.Palette.bgCream))
            }
            .buttonStyle(.plainTappable)
        }
        .padding(.top, 14)
    }

    private var toggleCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Palette.gold)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.goldPastel))
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily log reminder").font(AppFont.text(15, weight: .semibold))
                Text("A gentle prompt to capture today's spend.")
                    .font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Toggle("", isOn: Binding(
                get: { container.settings.dailyReminderEnabled },
                set: { newValue in
                    container.settings.dailyReminderEnabled = newValue
                    container.user.hasNotifications = newValue
                }
            ))
            .labelsHidden()
            .tint(Theme.Palette.gold)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var timeCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Palette.gold)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.goldPastel))
            Text("Time").font(AppFont.text(15, weight: .semibold))
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: {
                        var c = DateComponents()
                        c.hour = container.settings.dailyReminderHour
                        c.minute = container.settings.dailyReminderMinute
                        return Calendar.current.date(from: c) ?? Date()
                    },
                    set: { newDate in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                        var s = container.settings
                        s.dailyReminderHour = comps.hour ?? s.dailyReminderHour
                        s.dailyReminderMinute = comps.minute ?? s.dailyReminderMinute
                        container.settings = s
                    }
                ),
                displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var footer: some View {
        Text("We only send the one. No streak guilt-trips.")
            .font(AppFont.text(11))
            .foregroundColor(Theme.Palette.inkMute)
    }
}
