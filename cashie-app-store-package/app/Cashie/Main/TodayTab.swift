import SwiftUI

struct TodayTab: View {
    @EnvironmentObject var container: AppContainer
    let onQuickLog: () -> Void
    @State private var showMonthBreakdown = false
    @State private var showBudgets = false
    @State private var showRanks = false
    @State private var showBadges = false
    @State private var detailCategory: SpendCategory?
    @State private var detailGoal: Goal?
    @State private var mascotBob: CGFloat = 0
    @State private var mascotTilt: Double = -3

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    topbar
                    paceRingHero
                    RankHeroCard(progress: container.rankProgress) { showRanks = true }
                    whereItWentSection
                    if container.transactions.isEmpty {
                        AddLogNudge(message: "Log your first spend to bring this to life")
                            .padding(.top, 10)
                    } else if let note = monthOverMonthNote {
                        footerNote(note).padding(.top, 4)
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
        .sheet(item: $detailGoal) { g in
            GoalDetailSheet(goal: g)
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
                        ? "Hey, <em>\(container.user.firstName)</em>"
                        : "<em>Hey there</em>",
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
    // This-week trio). Tapping it jumps to the Spend tab for the full breakdown
    // (budgets are still editable there via "Set budgets").

    private var paceRingHero: some View {
        Button { container.mainTab = .spend } label: {
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
                    PillLink(title: "This month")
                }
                .padding(.bottom, 4)
            }
            .buttonStyle(.plainTappable)
            // Saving goals lead the section, in their own labelled block: each
            // row shows how the goal is tracking toward its target (an overall
            // figure, not a this-month one - hence the separate heading). New
            // goals read $0 until the first deposit. Tapping a goal opens the
            // same detail sheet used on the Goals tab.
            if !container.activeGoals.isEmpty {
                sectionHeading("Saving goals").padding(.top, 6).padding(.bottom, 2)
                ForEach(container.activeGoals) { goal in
                    Button { detailGoal = goal } label: {
                        GoalProgressRow(goal: goal)
                    }
                    .buttonStyle(.plainTappable)
                }
                Divider().background(Theme.Palette.lineSoft)
                sectionHeading("Spending").padding(.top, 12).padding(.bottom, 2)
            }
            // Every category is always listed so the section stays full even on
            // a fresh account: ones with spend sort to the top, the rest sit at
            // the bottom showing $0 until something lands in them.
            ForEach(displayCategories, id: \.0) { item in
                Button { detailCategory = item.0 } label: {
                    CategoryRowFull(
                        category: item.0,
                        spent: item.1,
                        cap: item.2
                    )
                }
                .buttonStyle(.plainTappable)
            }
        }
        .padding(18)
        .softCard(20)
    }

    /// Small uppercase group label used to separate the goals and spending
    /// blocks inside "Where it went", matching the subheads used in the sheets.
    private func sectionHeading(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer()
        }
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
    /// Shared via `AppContainer.safeToSpend` so the Wrapped + You cards match.
    private var safeToSpendValue: Double { container.safeToSpend }

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


    /// Every spend category (income excluded), each with this month's spend and
    /// its monthly cap. Sorted by spend descending so active categories lead and
    /// untouched ones fall to the bottom at $0, keeping the section full even
    /// before anything is logged. Ties (e.g. all $0) keep the canonical
    /// category order so the list is stable.
    private var displayCategories: [(SpendCategory, Double, Double)] {
        var caps: [SpendCategory: Double] = [:]
        for b in container.budgets { caps[b.category] = b.monthlyCap }

        let ordered: [SpendCategory] = SpendCategory.allCases.filter { $0 != .income }
        var rows: [(category: SpendCategory, spent: Double, cap: Double, order: Int)] = []
        for (idx, cat) in ordered.enumerated() {
            let spent = container.monthSpend(in: cat)
            rows.append((category: cat, spent: spent, cap: caps[cat] ?? 0, order: idx))
        }
        rows.sort { lhs, rhs in
            lhs.spent != rhs.spent ? lhs.spent > rhs.spent : lhs.order < rhs.order
        }
        return rows.map { ($0.category, $0.spent, $0.cap) }
    }

}

// MARK: - Category row

private struct CategoryRowFull: View {
    let category: SpendCategory
    let spent: Double
    let cap: Double

    // Three states once a cap is set: on track (green), approaching the cap
    // (amber, from 80%), and at/over the cap (red). The bar, a light wash behind
    // the icon, and the amount on the right all share the state colour.
    private var isOver: Bool { cap > 0 && spent >= cap }
    private var isNear: Bool { cap > 0 && spent >= cap * 0.8 && spent < cap }

    private var stateColor: Color {
        if isOver { return Theme.Palette.red }
        if isNear { return Theme.Palette.winGold }
        return Theme.Palette.gold
    }
    private var iconBackground: Color {
        if isOver { return Theme.Palette.red.opacity(0.10) }
        if isNear { return Theme.Palette.winGold.opacity(0.16) }
        return Theme.Palette.bgCream
    }
    private var amountColor: Color {
        if isOver { return Theme.Palette.red }
        if isNear { return Theme.Palette.winGold }
        return spent > 0 ? Theme.Palette.ink : Theme.Palette.inkMute
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                shape
                    .fill(iconBackground)
                    .overlay(shape.stroke(Theme.Palette.line.opacity(0.7), lineWidth: 1))
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
                            .fill(stateColor)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 4)
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.format(spent))
                    .font(AppFont.text(14, weight: .semibold))
                    .foregroundColor(amountColor)
                    .monospacedDigit()
                Text(cap > 0 ? "of \(Money.format(cap))" : "No cap set")
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
        }
        .padding(.vertical, 14)
    }

    private var progress: CGFloat {
        guard cap > 0 else { return 0 }
        return min(1, CGFloat(spent / cap))
    }
}

/// One saving goal inside "Where it went". Mirrors `CategoryRowFull` so the
/// section reads as one family: emoji tile, name, and a progress bar - but the
/// bar tracks the goal's overall progress toward its target (saved / target),
/// which is what tells the user how they're doing. A brand-new goal shows $0
/// with an empty bar. Funded goals switch the bar to the celebration gold.
private struct GoalProgressRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                GlassTile(cornerRadius: 12)
                Text(goal.emoji).font(.system(size: 18))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 7) {
                Text(goal.name)
                    .font(AppFont.text(14, weight: .medium))
                    .foregroundColor(Theme.Palette.ink)
                    .lineLimit(1)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.ink.opacity(0.06))
                        Capsule()
                            .fill(goal.isAchieved ? Theme.Palette.winGold : Theme.Palette.gold)
                            .frame(width: proxy.size.width * CGFloat(goal.progress))
                    }
                }
                .frame(height: 4)
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.format(goal.currentAmount))
                    .font(AppFont.text(14, weight: .semibold))
                    .foregroundColor(goal.currentAmount > 0 ? Theme.Palette.ink : Theme.Palette.inkMute)
                    .monospacedDigit()
                Text("of \(Money.format(goal.targetAmount))")
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
        }
        .padding(.vertical, 14)
    }
}

