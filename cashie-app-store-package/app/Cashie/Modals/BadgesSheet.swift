import SwiftUI

/// The badges page. Every achievement is laid out as a consistent, compact
/// card (three to a row) so the whole set reads as one collection. The cards
/// themselves are a neutral grey; the colour lives where it matters, on the
/// badge medallions and the progress bars, so earned and in-progress badges
/// still pop. One shared TimelineView drives the whole grid.
struct BadgesSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBadge: Badge?

    private var badges: [Badge] { Badge.all }
    private var earned: Int { container.earnedBadgeCount }
    private var totalXP: Int { container.unlockedBadgeXP }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                closeBar
                header
                summary
                // Grid renders statically (no per-frame animation) so a screen
                // of badges stays cheap. The shine/pulse only plays in the
                // detail modal, on the single badge the user taps.
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(badges) { badge in
                        BadgeCard(badge: badge) { selectedBadge = badge }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(Theme.Palette.bg.ignoresSafeArea())
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailSheet(badge: badge)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var closeBar: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.Palette.bgCream))
            }
            .buttonStyle(.plainTappable)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Achievements")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            EmphasizedHeadline(
                raw: "Your <em>badges.</em>",
                font: AppFont.display(36, weight: .bold),
                emColor: Theme.Palette.gold
            )
            Text("Unlock badges by using Cashie. Each one banks XP toward your rank.")
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
                .padding(.top, 2)
        }
    }

    private var summary: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(earned) of \(badges.count) earned")
                    .font(AppFont.text(18, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                Text("\(formatted(totalXP)) XP banked from badges")
                    .font(AppFont.text(12, weight: .medium))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(Theme.Palette.gold.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(badges.isEmpty ? 0 : Double(earned) / Double(badges.count)))
                    .stroke(Theme.Palette.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(badges.isEmpty ? 0 : Double(earned) / Double(badges.count) * 100))%")
                    .font(AppFont.text(13, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
            }
            .frame(width: 52, height: 52)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Palette.goldPastel))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Palette.gold.opacity(0.25), lineWidth: 1))
    }

    private func formatted(_ v: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

/// One compact, square-ish tile in the badges grid. Same neutral card for
/// every badge; the colour comes through the medallion and the progress bar.
private struct BadgeCard: View {
    let badge: Badge
    var onTap: () -> Void
    @EnvironmentObject var container: AppContainer

    private var unlocked: Bool { container.isBadgeUnlocked(badge) }

    var body: some View {
        VStack(spacing: 8) {
            BadgeView(badge: badge, unlocked: unlocked, size: 48)   // static (t = 0)

            Text(badge.title)
                .font(AppFont.text(11.5, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            footer
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(minHeight: 134)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Palette.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { onTap() }
    }

    @ViewBuilder
    private var footer: some View {
        if unlocked {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("+\(badge.xp)")
                    .font(AppFont.text(11, weight: .bold))
            }
            .foregroundColor(badge.tint)
        } else {
            VStack(spacing: 4) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.ink.opacity(0.08))
                        Capsule()
                            .fill(badge.tint)
                            .frame(width: max(4, proxy.size.width * CGFloat(container.badgeFraction(badge))))
                    }
                }
                .frame(height: 5)
                Text(container.badgeProgressText(badge))
                    .font(AppFont.text(9, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }
}

/// Tapping a badge opens this: what it is, how to earn it, the XP it banks,
/// and how far along you are.
private struct BadgeDetailSheet: View {
    let badge: Badge
    @EnvironmentObject var container: AppContainer

    private var unlocked: Bool { container.isBadgeUnlocked(badge) }

    var body: some View {
        VStack(spacing: 16) {
            medallion
                .padding(.top, 28)

            VStack(spacing: 8) {
                Text(badge.title)
                    .font(AppFont.display(34, weight: .heavy))
                    .foregroundColor(Theme.Palette.ink)
                Text(badge.currentDetail)
                    .font(AppFont.text(15))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            reward

            statusBlock
                .padding(.horizontal, 28)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
        .background(Theme.Palette.bg.ignoresSafeArea())
    }

    @ViewBuilder
    private var medallion: some View {
        if unlocked {
            // ~30fps instead of the display refresh: the pulse/shine are slow,
            // so it looks the same with a quarter of the per-frame work.
            TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 1.0 / 30.0)) { timeline in
                BadgeView(badge: badge, unlocked: true, size: 104,
                          t: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            BadgeView(badge: badge, unlocked: false, size: 104)
        }
    }

    private var reward: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .bold))
            Text("+\(badge.xp) XP toward your rank")
                .font(AppFont.text(13, weight: .bold))
        }
        .foregroundColor(badge.tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(badge.tint.opacity(0.12)))
    }

    @ViewBuilder
    private var statusBlock: some View {
        if unlocked {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                Text("Earned")
            }
            .font(AppFont.text(15, weight: .bold))
            .foregroundColor(Theme.Palette.gold)
        } else {
            VStack(spacing: 8) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.ink.opacity(0.08))
                        Capsule()
                            .fill(badge.tint)
                            .frame(width: max(6, proxy.size.width * CGFloat(container.badgeFraction(badge))))
                    }
                }
                .frame(height: 8)
                HStack {
                    Text(container.badgeProgressText(badge))
                        .font(AppFont.text(13, weight: .bold))
                        .foregroundColor(Theme.Palette.ink)
                        .monospacedDigit()
                    Spacer()
                    Text(remainingText)
                        .font(AppFont.text(13, weight: .medium))
                        .foregroundColor(Theme.Palette.inkSoft)
                }
            }
        }
    }

    private var remainingText: String {
        // Use the currency-adjusted target so "to go" matches the progress bar
        // (a money badge's USD tier is converted via `currentTarget`).
        let remaining = max(0, badge.currentTarget - container.badgeMetric(badge))
        return badge.isMoney ? "\(Money.format(Double(remaining))) to go" : "\(remaining) to go"
    }
}
