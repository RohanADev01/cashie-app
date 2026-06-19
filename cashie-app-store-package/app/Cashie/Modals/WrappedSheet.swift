import SwiftUI

/// Last 7 days, summarised. Every number on this sheet is derived from the
/// user's transactions; nothing is hard-coded or estimated.
struct WrappedSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss
    @Environment(\.displayScale) private var displayScale
    @State private var posterImage: Image?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("This week, wrapped")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)
                    Spacer()
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Palette.gold)
                        .font(AppFont.text(13, weight: .semibold))
                }
                .padding(.top, 18)

                EmphasizedHeadline(
                    raw: "Your week, <em>wrapped.</em>",
                    font: AppFont.display(40, weight: .bold)
                )

                if hasAnyActivity {
                    netCard
                    daysUnderBudgetCard
                    topCategoryCard
                    rhythmCard
                } else {
                    emptyState
                }

                HStack(spacing: 10) {
                    if hasAnyActivity, let posterImage {
                        ShareLink(
                            item: posterImage,
                            preview: SharePreview("My week, wrapped", image: posterImage)
                        ) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                                    .font(AppFont.text(15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(RoundedRectangle(cornerRadius: 100).fill(Theme.Palette.ink))
                        }
                    }
                    Button("Back") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 100).fill(Theme.Palette.bgCream))
                        .overlay(RoundedRectangle(cornerRadius: 100).stroke(Theme.Palette.line, lineWidth: 1))
                        .foregroundColor(Theme.Palette.ink)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .onAppear { renderPoster() }
    }

    // MARK: - Shareable poster
    //
    // Rendered off-screen via ImageRenderer so the Share button has an image
    // ready the moment the sheet appears. The poster is a self-contained,
    // brand-styled snapshot of the wrap, so receivers see Cashie context
    // without needing extra caption text.

    private func renderPoster() {
        let stats = posterStats
        let poster = WrappedSharePoster(stats: stats)
        let renderer = ImageRenderer(content: poster)
        renderer.scale = max(displayScale, 3)
        renderer.proposedSize = .init(width: 380, height: nil)
        if let uiImage = renderer.uiImage {
            posterImage = Image(uiImage: uiImage)
        }
    }

    private var posterStats: WrappedSharePoster.Stats {
        let saved = container.safeToSpend
        let won = daysLoggedThisWeek
        let count = weekTransactionCount
        let avg = count > 0 ? weeklySpend / Double(count) : 0

        let savedHeadline: String
        if saved > 0 {
            savedHeadline = "Saving \(Money.format(saved, cents: true))"
        } else if saved < 0 {
            savedHeadline = "Over by \(Money.format(-saved, cents: true))"
        } else {
            savedHeadline = "Right at your budget"
        }
        let savedNote = savedNote(saved: saved)

        let daysHeadline = "\(won) / 7 days logged"
        let daysNote = daysLoggedNote(won: won)

        let topLabel: String?
        let topValue: String?
        let topNote: String?
        if let top = weekSpendByCategory.first {
            topLabel = "Top category"
            topValue = top.0.label
            topNote = "\(Money.format(top.1)) across \(top.2) \(top.2 == 1 ? "log" : "logs")."
        } else {
            topLabel = nil
            topValue = nil
            topNote = nil
        }

        let rhythmValue = "\(count) \(count == 1 ? "log" : "logs")"
        let rhythmNote = count > 0
            ? "Average \(Money.format(avg, cents: avg < 100)) per entry."
            : "No spend logged this week."

        return WrappedSharePoster.Stats(
            savedHeadline: savedHeadline,
            savedNote: savedNote,
            daysHeadline: daysHeadline,
            daysNote: daysNote,
            topLabel: topLabel,
            topValue: topValue,
            topNote: topNote,
            rhythmValue: rhythmValue,
            rhythmNote: rhythmNote
        )
    }

    // MARK: - Cards

    private var netCard: some View {
        let saved = container.safeToSpend
        let headline = saved >= 0
            ? "Saving \(Money.format(saved, cents: true)) this month"
            : "Over by \(Money.format(-saved, cents: true)) this month"
        return gradientCard(
            palette: saved >= 0 ? .green : .fire,
            headline: headline,
            sub: savedNote(saved: saved)
        ) {
            Text("💰").font(.system(size: 26))
        }
    }

    private var daysUnderBudgetCard: some View {
        let won = daysLoggedThisWeek
        let headline = won == 0 ? "No logs yet this week" : "\(won) / 7 days logged"
        return gradientCard(
            palette: .fire,
            headline: headline,
            sub: daysLoggedNote(won: won)
        ) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        }
    }

    private var topCategoryCard: some View {
        let top = weekSpendByCategory.first
        if let top {
            return AnyView(card(
                label: "Top category",
                value: top.0.label,
                tone: .ink,
                note: "\(Money.format(top.1)) across \(top.2) \(top.2 == 1 ? "log" : "logs")."
            ))
        }
        return AnyView(EmptyView())
    }

    private var rhythmCard: some View {
        let count = weekTransactionCount
        let avg = count > 0 ? weeklySpend / Double(count) : 0
        return card(
            label: "Logging rhythm",
            value: "\(count) \(count == 1 ? "log" : "logs")",
            tone: .ink,
            note: count > 0
                ? "Average \(Money.format(avg, cents: avg < 100)) per entry."
                : "No spend logged this week."
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing to wrap yet.")
                .font(AppFont.text(17, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
            Text("Log a few things this week and your wrap fills in automatically.")
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private enum Tone { case gold, ink }

    private enum GradientPalette { case green, fire }

    /// Mirrors the gradient hero cards on the YOU tab (weekly wrap + streak)
    /// so the wrap sheet's headline cards feel like extensions of those.
    private func gradientCard<Icon: View>(
        palette: GradientPalette,
        headline: String,
        sub: String,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        let colors: [Color]
        let outline: Color
        let glow: Color
        switch palette {
        case .green:
            colors = [Color(hex: 0x1FCC83), Color(hex: 0x04BA74), Color(hex: 0x036141)]
            outline = Color(hex: 0x036141).opacity(0.35)
            glow = Color(hex: 0x04BA74).opacity(0.28)
        case .fire:
            colors = [Color(hex: 0xFF5E3A), Color(hex: 0xFF823C), Color(hex: 0xFFB24D)]
            outline = Color(hex: 0xFF5E3A).opacity(0.35)
            glow = Color(hex: 0xFF5E3A).opacity(0.4)
        }
        return ZStack {
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.white.opacity(0.32), .clear],
                               center: .topTrailing, startRadius: 4, endRadius: 200)
                RadialGradient(colors: [.black.opacity(0.10), .clear],
                               center: .bottomLeading, startRadius: 4, endRadius: 200)
            }
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 52, height: 52)
                    icon()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(AppFont.text(20, weight: .bold))
                        .foregroundColor(.white)
                    Text(sub)
                        .font(AppFont.text(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.92))
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(outline, lineWidth: 1))
        .shadow(color: glow, radius: 12, y: 5)
    }

    private func card(label: String, value: String, tone: Tone, note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(tone == .gold ? Theme.Palette.ink.opacity(0.7) : Theme.Palette.inkSoft)
            Text(value)
                .font(AppFont.display(40, weight: .heavy))
                .foregroundColor(Theme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(note)
                .font(AppFont.text(13))
                .foregroundColor(tone == .gold ? Theme.Palette.ink.opacity(0.65) : Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tone == .gold ? Theme.Palette.goldPastel : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tone == .gold ? Theme.Palette.gold.opacity(0.3) : Theme.Palette.line, lineWidth: 1)
        )
    }

    // MARK: - Derived

    private var weekStart: Date {
        Calendar.current.startOfDay(for: Date().addingTimeInterval(-86400 * 6))
    }

    private var thisWeekTx: [Transaction] {
        let start = weekStart
        return container.transactions.filter { $0.date >= start }
    }

    private var weeklySpend: Double {
        thisWeekTx.filter { $0.category != .income }.reduce(0) { $0 + $1.amount }
    }

    private var hasAnyActivity: Bool { !thisWeekTx.isEmpty }

    private var weekTransactionCount: Int {
        thisWeekTx.filter { $0.category != .income }.count
    }

    private var weekSpendByCategory: [(SpendCategory, Double, Int)] {
        var totals: [SpendCategory: (Double, Int)] = [:]
        for tx in thisWeekTx where tx.category != .income {
            let cur = totals[tx.category] ?? (0, 0)
            totals[tx.category] = (cur.0 + tx.amount, cur.1 + 1)
        }
        return totals
            .map { ($0.key, $0.value.0, $0.value.1) }
            .sorted { $0.1 > $1.1 }
    }

    /// How many of the last 7 calendar days (today included) the user kept up,
    /// i.e. logged a transaction OR spent a shield on. Matches the streak's
    /// "covered" definition exactly. The old metric counted days that were "on
    /// pace" against the budget, but an idle no-spend day trivially stays under
    /// the prorated cap, so it read 7/7 even when you only showed up a couple
    /// of days.
    private var daysLoggedThisWeek: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var logged = 0
        for back in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -back, to: today) else { continue }
            if container.isCovered(day) { logged += 1 }
        }
        return logged
    }

    /// Note under the net card. Mirrors `container.safeToSpend` (the Today hero)
    /// so the wrap never contradicts it: positive = under the monthly budget,
    /// negative = over.
    private func savedNote(saved: Double) -> String {
        let monthCap = container.budgets.reduce(0) { $0 + $1.monthlyCap }
        guard monthCap > 0 else { return "Set a monthly cap to track savings." }
        if saved > 0 {
            return "Under your monthly budget by \(Money.format(saved, cents: saved < 100))."
        }
        if saved < 0 {
            return "Over your monthly budget by \(Money.format(-saved, cents: -saved < 100))."
        }
        return "Right at your monthly budget."
    }

    private func daysLoggedNote(won: Int) -> String {
        switch won {
        case 7: return "You logged every day this week. Untouchable."
        case 5...6: return "Logged most days this week. Strong rhythm."
        case 3...4: return "A few days logged. Keep the chain going."
        case 1...2: return "A couple of logs this week. Small steps count."
        default: return "Nothing logged this week yet. Tap + to start."
        }
    }

}

/// Self-contained snapshot used by ImageRenderer to produce the shareable
/// "wrapped" image. Takes pre-computed strings so it does not need any
/// EnvironmentObjects (which ImageRenderer does not propagate).
private struct WrappedSharePoster: View {
    struct Stats {
        let savedHeadline: String
        let savedNote: String
        let daysHeadline: String
        let daysNote: String
        let topLabel: String?
        let topValue: String?
        let topNote: String?
        let rhythmValue: String
        let rhythmNote: String
    }

    let stats: Stats

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image("Mascot")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                Text("Cashie")
                    .font(AppFont.text(15, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                Spacer()
                Text("Week wrapped")
                    .font(AppFont.text(10, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkMute)
            }

            EmphasizedHeadline(
                raw: "Your week, <em>wrapped.</em>",
                font: AppFont.display(34, weight: .bold)
            )

            gradientCard(
                palette: .green,
                headline: stats.savedHeadline,
                sub: stats.savedNote,
                emoji: "💰"
            )

            gradientCard(
                palette: .fire,
                headline: stats.daysHeadline,
                sub: stats.daysNote,
                emoji: nil
            )

            if let topLabel = stats.topLabel, let topValue = stats.topValue, let topNote = stats.topNote {
                plainCard(label: topLabel, value: topValue, note: topNote)
            }

            plainCard(label: "Logging rhythm", value: stats.rhythmValue, note: stats.rhythmNote)

            Text("cashie.space")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 380)
        .background(Theme.Palette.bg)
    }

    private enum GradientPalette { case green, fire }

    private func gradientCard(palette: GradientPalette, headline: String, sub: String, emoji: String?) -> some View {
        let colors: [Color]
        let outline: Color
        switch palette {
        case .green:
            colors = [Color(hex: 0x1FCC83), Color(hex: 0x04BA74), Color(hex: 0x036141)]
            outline = Color(hex: 0x036141).opacity(0.35)
        case .fire:
            colors = [Color(hex: 0xFF5E3A), Color(hex: 0xFF823C), Color(hex: 0xFFB24D)]
            outline = Color(hex: 0xFF5E3A).opacity(0.35)
        }
        return ZStack {
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.white.opacity(0.32), .clear],
                               center: .topTrailing, startRadius: 4, endRadius: 200)
                RadialGradient(colors: [.black.opacity(0.10), .clear],
                               center: .bottomLeading, startRadius: 4, endRadius: 200)
            }
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 48, height: 48)
                    if let emoji {
                        Text(emoji).font(.system(size: 24))
                    } else {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(AppFont.text(18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(sub)
                        .font(AppFont.text(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(outline, lineWidth: 1))
    }

    private func plainCard(label: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            Text(value)
                .font(AppFont.display(28, weight: .heavy))
                .foregroundColor(Theme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(note)
                .font(AppFont.text(12))
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }
}
