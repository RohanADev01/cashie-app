import SwiftUI

struct TodayTab: View {
    @EnvironmentObject var container: AppContainer
    let onQuickLog: () -> Void
    @State private var showMonthBreakdown = false
    @State private var showBudgets = false
    @State private var showRanks = false
    @State private var showBadges = false
    @State private var detailCategory: SpendCategory?
    @State private var mascotBob: CGFloat = 0
    @State private var mascotTilt: Double = -3

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    topbar
                    paceRingHero.padding(.top, 18)
                    RankHeroCard(progress: container.rankProgress) { showRanks = true }
                        .padding(.top, 14)
                    whereItWentSection.padding(.top, 28)
                    if let note = monthOverMonthNote {
                        footerNote(note).padding(.top, 22)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $detailCategory) { cat in
            CategoryDetailSheet(category: cat)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMonthBreakdown) {
            MonthBreakdownSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBudgets) {
            BudgetsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showRanks) {
            RanksLadderSheet()
        }
        .fullScreenCover(isPresented: $showBadges) {
            BadgesSheet()
        }
        // Celebrations (badge/rank/goal) are detected at the data layer and
        // presented from MainTabsView, so they fire regardless of the active
        // tab. Nothing to wire up here.
        .onAppear {
            // Dev screenshot helpers fire ONCE per launch. TodayTab is rebuilt
            // every time the user returns to the Home tab (MainTabsView swaps
            // tabs with a `switch`), so a plain onAppear would re-open the sheet
            // on every Home tap. The static guard keeps it a true one-shot.
            guard !Self.didRunLaunchOpens else { return }
            Self.didRunLaunchOpens = true
            let args = ProcessInfo.processInfo.arguments
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if args.contains("-openBadges") { showBadges = true }
                if args.contains("-openRanks") { showRanks = true }
                if args.contains("-openMonth") { showMonthBreakdown = true }
                if args.contains("-openBudgets") { showBudgets = true }
            }
        }
    }

    /// One-shot guard for the `-open*` launch-arg screenshot helpers above.
    /// Static so it survives TodayTab being torn down and rebuilt on tab
    /// switches; otherwise the sheet would reopen every time Home is tapped.
    private static var didRunLaunchOpens = false

    // MARK: - Top bar

    private var topbar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateLabel)
                    .font(AppFont.text(11, weight: .medium))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                EmphasizedHeadline(
                    raw: container.user.hasName
                        ? "Hey, <em>\(container.user.firstName).</em>"
                        : "<em>Hey there.</em>",
                    font: AppFont.display(36, weight: .bold),
                    emColor: Theme.Palette.gold
                )
                .padding(.top, 2)
            }
            Spacer()
            mascotAvatar
        }
    }

    private var mascotAvatar: some View {
        Image("Mascot")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: 52, height: 52)
            .rotationEffect(.degrees(mascotTilt))
            .offset(y: mascotBob)
            .shadow(color: Theme.Palette.gold.opacity(0.25), radius: 8, x: 0, y: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    mascotBob = -4
                }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                    mascotTilt = 3
                }
            }
    }

    // MARK: - Pace ring hero
    //
    // Single consolidated hero (replaces the old Safe-to-spend / This-month /
    // This-week trio). Tappable: opens the same Manage Budgets sheet the
    // Spend tab uses, so users can adjust their monthly caps from home.

    private var paceRingHero: some View {
        Button { showBudgets = true } label: {
            PaceRingCard(
                safeToSpendWhole: amountWhole,
                safeToSpendCents: amountCents,
                negative: safeToSpendNegative,
                monthRatio: monthBudgetRatio,
                hasCap: monthHasCap,
                dailyAllowance: container.dailyBudgetAllowance,
                daysLeft: container.daysLeftInMonth
            )
        }
        .buttonStyle(.plainTappable)
    }

    private var monthHasCap: Bool {
        container.budgets.reduce(0) { $0 + $1.monthlyCap } > 0
    }

    /// Fraction of the monthly cap consumed: this month's expenses plus goal
    /// deposits over the total cap. Mirrors `safeToSpendValue`, which is the
    /// remaining headroom from the same inputs.
    private var monthBudgetRatio: Double {
        let cal = Calendar.current
        let spend = container.transactions
            .filter { $0.category != .income && cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
        let cap = container.budgets.reduce(0) { $0 + $1.monthlyCap }
        guard cap > 0 else { return 0 }
        return (spend + container.monthDepositsTotal) / cap
    }

    // MARK: - Where it went (this month, real top categories, tappable header)

    private var whereItWentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { showMonthBreakdown = true } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Where it went")
                        .font(AppFont.text(17, weight: .bold))
                        .foregroundColor(Theme.Palette.ink)
                    Spacer()
                    Text("This month →")
                        .font(AppFont.text(11, weight: .medium))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.gold)
                }
                .padding(.bottom, 4)
            }
            .buttonStyle(.plainTappable)
            if topCategories.isEmpty {
                Text("Nothing logged yet this month.")
                    .font(AppFont.text(13))
                    .foregroundColor(Theme.Palette.inkMute)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
                    .padding(.top, 6)
            } else {
                if container.monthDepositsTotal > 0 {
                    Button { showMonthBreakdown = true } label: {
                        SavingRow(amount: container.monthDepositsTotal,
                                  goalCount: depositGoalCount)
                    }
                    .buttonStyle(.plainTappable)
                }
                ForEach(topCategories, id: \.0) { item in
                    Button { detailCategory = item.0 } label: {
                        CategoryRowFull(
                            category: item.0,
                            spent: item.1,
                            cap: item.2,
                            tint: tint(spent: item.1, cap: item.2)
                        )
                    }
                    .buttonStyle(.plainTappable)
                }
            }
        }
    }

    /// Number of distinct goals that received at least one deposit this
    /// month - used in the "Saving" row's "across N goals" subline.
    private var depositGoalCount: Int {
        let cal = Calendar.current
        return container.goals.filter { goal in
            goal.deposits.contains { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        }.count
    }

    // MARK: - Footer note

    private func footerNote(_ text: String) -> some View {
        Text("\"\(text)\"")
            .font(AppFont.text(12))
            .foregroundColor(Theme.Palette.inkSoft.opacity(0.85))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    /// Picks the category where the user is spending the most less this month
    /// vs. last month, with a meaningful baseline. Returns nil when nothing
    /// is worth highlighting (no real change, baseline too small, or up MoM).
    private var monthOverMonthNote: String? {
        let minBaseline: Double = 20
        let minDelta: Double = 0.05  // at least 5% drop to be worth saying

        let candidates: [(SpendCategory, Double)] = SpendCategory.allCases.compactMap { cat in
            let now = container.monthSpend(in: cat, monthOffset: 0)
            let prev = container.monthSpend(in: cat, monthOffset: -1)
            guard prev >= minBaseline, now < prev else { return nil }
            let drop = (prev - now) / prev
            guard drop >= minDelta else { return nil }
            return (cat, drop)
        }

        guard let best = candidates.max(by: { $0.1 < $1.1 }) else { return nil }
        let pct = Int((best.1 * 100).rounded())
        return "You're spending \(pct)% less on \(best.0.label.lowercased()) than last month."
    }

    // MARK: - Derived data

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · d MMM"
        return f.string(from: Date())
    }

    /// "Safe to spend" = total monthly caps minus this month's expenses
    /// minus this month's goal deposits. Treating deposits as outflows
    /// makes "saving for the trip" feel like spending the month's budget
    /// on the trip, instead of pretending the money came from nowhere.
    /// Goes negative once you've spent past the cap, so the hero can show it.
    private var safeToSpendValue: Double {
        let cal = Calendar.current
        let monthSpend = container.transactions
            .filter { $0.category != .income && cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
        let monthCap = container.budgets.reduce(0) { $0 + $1.monthlyCap }
        return monthCap - monthSpend - container.monthDepositsTotal
    }

    /// Over the monthly cap (small epsilon so a tiny rounding miss isn't "-$0").
    private var safeToSpendNegative: Bool { safeToSpendValue < -0.005 }

    // Whole + cents are formatted from the absolute value; the minus sign is
    // rendered separately by the card so it reads "-$50.40", not "$-50.40".
    private var amountWhole: String {
        let value = abs(safeToSpendValue)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
    }

    private var amountCents: String {
        let v = abs(safeToSpendValue)
        let cents = Int((v - floor(v)) * 100 + 0.5)
        return String(format: ".%02d", cents)
    }


    private var topCategories: [(SpendCategory, Double, Double)] {
        container.budgets
            .compactMap { b -> (SpendCategory, Double, Double)? in
                let spent = container.monthSpend(in: b.category)
                guard spent > 0 else { return nil }
                return (b.category, spent, b.monthlyCap)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0 }
    }

    /// Brand green by default; red only once the category is over its
    /// monthly cap.
    private func tint(spent: Double, cap: Double) -> Color {
        guard cap > 0 else { return Theme.Palette.gold }
        return spent > cap ? Theme.Palette.red : Theme.Palette.gold
    }
}

// MARK: - Section head + divider label

private struct SectionHead: View {
    let title: String
    let trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.text(17, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(AppFont.text(11, weight: .medium))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
            }
        }
        .padding(.bottom, 4)
    }
}

private struct DividerLabel: View {
    let text: String
    let numeral: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(text)
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.ink)
                Spacer()
                Text(numeral)
                    .font(AppFont.text(11, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .padding(.bottom, 8)
            Rectangle().fill(Theme.Palette.line).frame(height: 1)
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Category row

private struct CategoryRowFull: View {
    let category: SpendCategory
    let spent: Double
    let cap: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                GlassTile(cornerRadius: 12)
                Text(category.emoji).font(.system(size: 18))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 7) {
                Text(category.label)
                    .font(AppFont.text(14, weight: .medium))
                    .foregroundColor(Theme.Palette.ink)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.ink.opacity(0.06))
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 4)
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.format(spent))
                    .font(AppFont.text(14, weight: .semibold))
                    .foregroundColor(Theme.Palette.ink)
                    .monospacedDigit()
                Text("of \(Money.format(cap))")
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
        }
        .padding(.vertical, 14)
        .overlay(
            Rectangle().fill(Theme.Palette.lineSoft).frame(height: 1),
            alignment: .bottom
        )
    }

    private var progress: CGFloat {
        guard cap > 0 else { return 0 }
        return min(1, CGFloat(spent / cap))
    }
}

/// Synthetic "Saving" row that sits in Where it Went so users see goal
/// deposits as part of the month's outflows alongside expenses.
private struct SavingRow: View {
    let amount: Double
    let goalCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                GlassTile(cornerRadius: 12)
                Text("🌱").font(.system(size: 18))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text("Saving")
                    .font(AppFont.text(14, weight: .medium))
                    .foregroundColor(Theme.Palette.ink)
                Text(goalCount == 1
                     ? "From this month's budget · 1 goal"
                     : "From this month's budget · \(goalCount) goals")
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkSoft)
            }

            Spacer()

            Text(Money.format(amount))
                .font(AppFont.text(14, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
                .monospacedDigit()
        }
        .padding(.vertical, 14)
        .overlay(
            Rectangle().fill(Theme.Palette.lineSoft).frame(height: 1),
            alignment: .bottom
        )
    }
}

