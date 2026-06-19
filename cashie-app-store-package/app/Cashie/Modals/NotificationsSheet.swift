import SwiftUI

struct NotificationsSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Your nudges").font(AppFont.display(28, weight: .bold))
                    Spacer()
                    Button("Mark read") {
                        container.markNotificationsRead()
                    }
                    .font(AppFont.text(13, weight: .semibold))
                    .foregroundColor(Theme.Palette.gold)
                }
                .padding(.top, 18)

                Text("Wins, streaks, and the occasional gentle nudge. No noise.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)

                ForEach(grouped, id: \.label) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.label)
                            .font(AppFont.text(11, weight: .semibold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundColor(Theme.Palette.inkMute)
                            .padding(.top, 12)
                        VStack(spacing: 0) {
                            ForEach(group.items) { n in
                                NotifRow(notif: n)
                                if n.id != group.items.last?.id {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
    }

    private var grouped: [(label: String, items: [AppNotification])] {
        let cal = Calendar.current
        let today = container.notifications.filter { cal.isDateInToday($0.date) }
        let earlier = container.notifications.filter { !cal.isDateInToday($0.date) }
        var out: [(String, [AppNotification])] = []
        if !today.isEmpty { out.append(("Today", today)) }
        if !earlier.isEmpty { out.append(("Earlier", earlier)) }
        return out
    }
}

private struct NotifRow: View {
    let notif: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(notif.emoji)
                .font(.system(size: 22))
                .frame(width: 42, height: 42)
                .background(Circle().fill(background))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(notif.title).font(AppFont.text(14, weight: .semibold))
                    Spacer()
                    if notif.isUnread {
                        Circle().fill(Theme.Palette.gold).frame(width: 8, height: 8)
                    }
                }
                Text(notif.body).font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkSoft)
                Text(formatted)
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkMute)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var background: Color {
        switch notif.kind {
        case .goal: return Theme.Palette.goldPastel
        case .streak: return Theme.Palette.goldLight
        case .budget: return Color(hex: 0xE83F3F).opacity(0.1)
        case .wrapped: return Theme.Palette.bgCream
        case .insight: return Theme.Palette.bgCream
        case .milestone: return Theme.Palette.goldPastel
        }
    }

    private var formatted: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: notif.date, relativeTo: Date())
    }
}
