import SwiftUI
import Combine

struct SpendTab: View {
    @EnvironmentObject var container: AppContainer
    @State private var periodOffset: Int = 0   // 0 = current month, -1 = previous, ...
    @State private var selectedTx: Transaction?
    @State private var selectedGoal: Goal?
    @State private var showBudgets = false
    @State private var showQuickLogSetup = false

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    heroHeader
                    summaryCard
                    transactionsList
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $selectedTx) { tx in
            TransactionDetailSheet(transaction: tx)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedGoal) { goal in
            GoalDetailSheet(goal: goal)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQuickLogSetup) {
            QuickLogSetupSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBudgets) {
            BudgetsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var heroHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your spending")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                EmphasizedHeadline(
                    raw: "Where it <em>went</em>",
                    font: AppFont.display(36, weight: .bold),
                    emColor: Theme.Palette.gold
                )
                .padding(.top, 4)
            }
            Spacer(minLength: 12)
            QuickLogGlowButton(attentionShake: true) { showQuickLogSetup = true }
        }
    }

    /// The month switcher, the month's spend figure and its running-total chart,
    /// all in one soft card so they read as a single connected unit. The month
    /// nav sits at the top; tapping the figure opens Manage Budgets; dragging
    /// along the chart scrubs the running spend at each point.
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { showBudgets = true } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        Text(periodKicker)
                            .font(AppFont.text(11, weight: .semibold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundColor(Theme.Palette.inkSoft)
                        Spacer()
                        PillLink(title: "Set budgets")
                    }
                    .padding(.bottom, 8)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(Money.symbol)
                            .font(AppFont.text(22, weight: .semibold))
                            .foregroundColor(Theme.Palette.ink.opacity(0.6))
                            .baselineOffset(14)
                        Text(periodSpendWhole)
                            .font(AppFont.text(48, weight: .bold))
                            .foregroundColor(Theme.Palette.ink)
                            .monospacedDigit()
                        Text(periodSpendCents)
                            .font(AppFont.text(22, weight: .semibold))
                            .foregroundColor(Theme.Palette.ink.opacity(0.5))
                            .monospacedDigit()
                    }
                    Text(heroSub)
                        .font(AppFont.text(13))
                        .foregroundColor(Theme.Palette.inkSoft)
                        .padding(.top, 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plainTappable)

            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    SpendChart(values: cumulativeTotals)
                        .frame(height: 140)
                    chartAxis
                }
                periodNav
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(20)
    }

    /// Minimal month switcher shown under the chart: the month in ink with small
    /// ink chevrons on each side, no pill or button chrome, matching the flat
    /// style of the rest of the app. Doubles as the chart's x-axis label.
    private var periodNav: some View {
        HStack(spacing: 16) {
            navArrow(system: "chevron.left", enabled: true) {
                withAnimation(Theme.Motion.snap) { periodOffset -= 1 }
            }
            Text(periodLabel)
                .font(AppFont.text(13, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
                .monospacedDigit()
                .frame(minWidth: 118)
                .multilineTextAlignment(.center)
            navArrow(system: "chevron.right", enabled: periodOffset < 0) {
                withAnimation(Theme.Motion.snap) { periodOffset += 1 }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Small, chrome-less ink chevron used by the month switcher.
    private func navArrow(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(enabled ? Theme.Palette.ink : Theme.Palette.inkFaint)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
        .disabled(!enabled)
    }

    /// Date ticks under the chart so the x-axis reads as the month timeline: the
    /// first plotted day, the middle, and the last (today, for the current
    /// month), aligned to the chart's edges.
    private var chartAxis: some View {
        let count = cumulativeTotals.count
        return HStack(spacing: 0) {
            Text(axisLabel(dayIndex: 0))
            Spacer()
            if count > 2 {
                Text(axisLabel(dayIndex: count / 2))
                Spacer()
            }
            if count > 1 {
                Text(axisLabel(dayIndex: count - 1))
            }
        }
        .font(AppFont.text(10, weight: .medium))
        .foregroundColor(Theme.Palette.inkMute)
        .monospacedDigit()
    }

    private func axisLabel(dayIndex: Int) -> String {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: dayIndex, to: periodRange.start) ?? periodRange.start
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }


    @ViewBuilder private var transactionsList: some View {
        if grouped.isEmpty {
            emptyTransactions
        } else {
            transactionGroups
        }
    }

    @ViewBuilder private var emptyTransactions: some View {
        if periodOffset == 0 {
            AddLogNudge(message: "No spends logged yet\nTap the + to add your first")
                .padding(.top, 48)
        } else {
            Text("Nothing logged this month")
                .font(AppFont.text(14, italic: true))
                .foregroundColor(Theme.Palette.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
    }

    private var transactionGroups: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(grouped, id: \.day) { group in
                // Each day reads as its own "Where it went"-style card: a bold
                // date header with the day's total on the right (ink, monospaced),
                // then the rows, all inside one soft card for visual consistency
                // with the home screen.
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(group.day)
                            .font(AppFont.text(17, weight: .bold))
                            .foregroundColor(Theme.Palette.ink)
                        Spacer()
                        Text(Money.format(group.total, cents: true))
                            .font(AppFont.text(14, weight: .semibold))
                            .foregroundColor(Theme.Palette.ink)
                            .monospacedDigit()
                    }
                    .padding(.bottom, 4)

                    ForEach(group.items) { item in
                        Button { open(item) } label: {
                            row(for: item)
                                .padding(.vertical, 11)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plainTappable)
                        if item.id != group.items.last?.id {
                            Divider().background(Theme.Palette.lineSoft)
                        }
                    }
                }
                .padding(18)
                .softCard(20)
            }
        }
    }

    // MARK: - Data

    /// One row in the spend log: either a real transaction or a goal deposit
    /// surfaced as a savings outflow. Deposits aren't stored as transactions,
    /// so we synthesise these for display only (no extra rows in the DB).
    private enum SpendItem: Identifiable {
        case tx(Transaction)
        case deposit(goal: Goal, deposit: Deposit)

        var id: UUID {
            switch self {
            case .tx(let t): return t.id
            case .deposit(_, let d): return d.id
            }
        }
        var date: Date {
            switch self {
            case .tx(let t): return t.date
            case .deposit(_, let d): return d.date
            }
        }
        /// Amount that counts toward the period's spend. Deposits count as
        /// outflow (money set aside); income contributes nothing to spend. This
        /// keeps the Spend tab's total in step with the Today ring, which
        /// already folds deposits into the month's outflow.
        var spendAmount: Double {
            switch self {
            case .tx(let t): return t.category == .income ? 0 : t.amount
            case .deposit(_, let d): return d.amount
            }
        }
    }

    @ViewBuilder private func row(for item: SpendItem) -> some View {
        switch item {
        case .tx(let tx): TransactionRow(tx: tx)
        case .deposit(let goal, let deposit): DepositLogRow(goal: goal, deposit: deposit)
        }
    }

    private func open(_ item: SpendItem) {
        switch item {
        case .tx(let tx): selectedTx = tx
        case .deposit(let goal, _): selectedGoal = goal
        }
    }

    // MARK: - Period (week/month + offset)

    /// Inclusive start..<end for the currently selected month.
    private var periodRange: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.dateInterval(of: .month, for: now)?.start ?? now
        let shifted = cal.date(byAdding: .month, value: periodOffset, to: monthStart) ?? monthStart
        let end = cal.date(byAdding: .month, value: 1, to: shifted) ?? shifted
        return (shifted, end)
    }

    private var periodTransactions: [Transaction] {
        let r = periodRange
        return container.transactions
            .filter { $0.date >= r.start && $0.date < r.end }
    }

    /// Transactions and goal deposits for the selected month, merged into a
    /// single log feed.
    private var periodItems: [SpendItem] {
        let r = periodRange
        let txItems = periodTransactions.map { SpendItem.tx($0) }
        let depItems = container.goals.flatMap { goal in
            goal.deposits
                .filter { $0.date >= r.start && $0.date < r.end }
                .map { SpendItem.deposit(goal: goal, deposit: $0) }
        }
        return txItems + depItems
    }

    private var periodSpend: Double {
        periodItems.reduce(0) { $0 + $1.spendAmount }
    }

    private var periodSpendWhole: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: Int(periodSpend))) ?? "\(Int(periodSpend))"
    }

    private var periodSpendCents: String {
        let cents = Int((periodSpend - floor(periodSpend)) * 100 + 0.5)
        return String(format: ".%02d", cents)
    }

    private var periodKicker: String {
        switch periodOffset {
        case 0: return "Spent this month"
        case -1: return "Spent last month"
        default: return "Spent \(abs(periodOffset)) months ago"
        }
    }

    private var periodLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: periodRange.start)
    }

    private var heroSub: String {
        let monthBudget = container.budgets.reduce(0) { $0 + $1.monthlyCap }
        let remaining = monthBudget - periodSpend
        let label = remaining >= 0 ? "under budget" : "over budget"
        return "\(Money.format(abs(remaining))) \(label)"
    }

    private var daysLeftInMonth: Int {
        let cal = Calendar.current
        let last = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        return last - cal.component(.day, from: Date())
    }

    /// Running month-to-date spend for the chart. The filled-area style
    /// reads as a trajectory, so each point is total spent through that day
    /// (not the day's individual outflow). For past months we plot the full
    /// month; for the current month we stop at today so the line doesn't
    /// nosedive across days that haven't happened yet.
    private var cumulativeTotals: [Double] {
        let daily = dailyTotals
        var running: Double = 0
        return daily.map { day in
            running += day
            return running
        }
    }

    /// Per-day spend buckets, used as the building block for `cumulativeTotals`.
    private var dailyTotals: [Double] {
        let cal = Calendar.current
        let r = periodRange
        let monthDays = max(1, cal.dateComponents([.day], from: r.start, to: r.end).day ?? 7)
        let today = cal.startOfDay(for: Date())
        let isCurrent = today >= r.start && today < r.end
        let dayCount: Int
        if isCurrent {
            let elapsed = (cal.dateComponents([.day], from: r.start, to: today).day ?? 0) + 1
            dayCount = min(monthDays, max(1, elapsed))
        } else {
            dayCount = monthDays
        }
        var values = Array(repeating: 0.0, count: dayCount)
        for item in periodItems {
            let idx = cal.dateComponents([.day], from: r.start, to: item.date).day ?? 0
            if idx >= 0 && idx < dayCount {
                values[idx] += item.spendAmount
            }
        }
        return values
    }

    private var grouped: [(day: String, total: Double, items: [SpendItem])] {
        let cal = Calendar.current
        let dayMonth = DateFormatter(); dayMonth.dateFormat = "EEE d MMM"
        let bucket = DateFormatter(); bucket.dateFormat = "yyyy-MM-dd"
        let bucketed = Dictionary(grouping: periodItems) {
            bucket.string(from: $0.date)
        }
        return bucketed.keys.sorted(by: >).map { key in
            let items = bucketed[key]!.sorted { $0.date > $1.date }
            let total = items.reduce(0) { $0 + $1.spendAmount }
            let date = bucket.date(from: key) ?? Date()
            let prefix: String? =
                cal.isDateInToday(date) ? "Today" :
                cal.isDateInYesterday(date) ? "Yesterday" : nil
            let label: String
            if let prefix {
                label = "\(prefix) · \(dayMonth.string(from: date))"
            } else {
                label = dayMonth.string(from: date)
            }
            return (day: label, total: total, items: items)
        }
    }
}

struct TransactionRow: View {
    let tx: Transaction
    /// Lists that already group rows under a date header (Spend tab) leave
    /// this off; flat lists (Category drill-in) turn it on so each row
    /// carries its own date stamp.
    var showsDate: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                GlassTile(cornerRadius: 10)
                Text(tx.category.emoji).font(.system(size: 18))
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.merchant)
                    .font(AppFont.text(15, weight: .medium))
                    .foregroundColor(Theme.Palette.ink)
                Text(subtitle)
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
            Text(amountLabel)
                .font(AppFont.text(15, weight: .semibold))
                .foregroundColor(tx.isIncome ? Theme.Palette.gold : Theme.Palette.ink)
        }
    }

    private var subtitle: String {
        if showsDate {
            return "\(tx.category.label) · \(dateLabel) · \(timeLabel)"
        }
        return "\(tx.category.label) · \(timeLabel)"
    }

    // Plain amount, no +/− sign. Income is distinguished by its green colour
    // (see foregroundColor above), expenses render in ink.
    private var amountLabel: String {
        Money.format(tx.amount, cents: true)
    }

    private var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: tx.date)
    }

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(tx.date) { return "Today" }
        if cal.isDateInYesterday(tx.date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: tx.date)
    }
}

/// A goal deposit shown in the spend log. Mirrors `TransactionRow` so the feed
/// reads consistently, but uses the goal's emoji and reads as savings rather
/// than a purchase. Tapping it opens the goal (where the deposit can be removed).
struct DepositLogRow: View {
    let goal: Goal
    let deposit: Deposit

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                GlassTile(cornerRadius: 10)
                Text(goal.emoji).font(.system(size: 18))
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("Saved to \(goal.name)")
                    .font(AppFont.text(15, weight: .medium))
                    .foregroundColor(Theme.Palette.ink)
                Text("Savings · \(timeLabel)")
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
            Text(Money.format(deposit.amount, cents: true))
                .font(AppFont.text(15, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
        }
    }

    private var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: deposit.date)
    }
}

/// A small, glowing circular "Log with a tap" button. Subtle (icon-only) but a
/// soft gold halo pings outward to draw the eye. Shared by the Spend tab header
/// and the Quick Log modal; tapping opens the Quick Log setup.
struct QuickLogGlowButton: View {
    /// When true, the button shakes every few seconds to draw the eye, until the
    /// user first taps it, then it stops for good (persisted).
    var attentionShake: Bool = false
    var action: () -> Void

    @State private var pulse = false
    @State private var shakeAttempts: CGFloat = 0
    @AppStorage("quickLogGlowDiscovered") private var discovered = false

    private let shakeTimer = Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            if !discovered { discovered = true }
            action()
        } label: {
            ZStack {
                // Halo behind the button, radiating gold outward and fading.
                Circle()
                    .fill(Theme.Palette.gold.opacity(0.45))
                    .frame(width: 44, height: 44)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0.0 : 0.5)
                Circle()
                    .fill(Theme.Palette.gold)
                    .frame(width: 44, height: 44)
                    .shadow(color: Theme.Palette.gold.opacity(0.5), radius: 8, x: 0, y: 3)
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)   // stable layout; the halo overflows visually
        }
        .buttonStyle(.plainTappable)
        .accessibilityLabel("Log with a tap")
        .modifier(GiftJiggleEffect(animatableData: shakeAttempts))
        .onReceive(shakeTimer) { _ in
            guard attentionShake, !discovered else { return }
            withAnimation(.easeInOut(duration: 0.6)) { shakeAttempts += 1 }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

/// A "gift waiting to be opened" jiggle: the view grows then settles while
/// rocking side to side a couple of times, all in place (around its own centre).
/// Each whole-number increment of `animatableData` plays one burst.
private struct GiftJiggleEffect: GeometryEffect {
    var scaleAmount: CGFloat = 0.16   // peak growth (~+16%)
    var angle: CGFloat = 0.22         // max tilt in radians (~12.5°)
    var wobbles: CGFloat = 2          // rocks side to side this many times
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        // Fractional progress through the current burst (0 -> 1), so the grow
        // always swells outward (never inverts on alternate bursts).
        let t = animatableData - floor(animatableData)
        let scale = 1 + scaleAmount * sin(t * .pi)
        let rot = angle * sin(t * .pi * wobbles * 2)
        let cx = size.width / 2
        let cy = size.height / 2
        let transform = CGAffineTransform.identity
            .translatedBy(x: cx, y: cy)
            .rotated(by: rot)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -cx, y: -cy)
        return ProjectionTransform(transform)
    }
}

private struct SpendChart: View {
    let values: [Double]
    /// The point the user is scrubbing, nil when resting.
    @State private var activeIndex: Int? = nil

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let maxVal = max(values.max() ?? 1, 1)
            let count = values.count
            let stepX = count > 1 ? w / CGFloat(count - 1) : w
            let pts = values.enumerated().map { idx, v in
                CGPoint(x: CGFloat(idx) * stepX,
                        y: h - (CGFloat(v / maxVal) * h * 0.9) - 6)
            }

            ZStack(alignment: .topLeading) {
                // Filled area under the line.
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: CGPoint(x: first.x, y: h))
                    p.addLine(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                    if let last = pts.last { p.addLine(to: CGPoint(x: last.x, y: h)) }
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Theme.Palette.gold.opacity(0.35), Theme.Palette.gold.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))

                // The line itself.
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(Theme.Palette.gold, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let i = activeIndex, pts.indices.contains(i) {
                    let pt = pts[i]
                    // Vertical guide from the baseline up to the scrubbed point.
                    Path { p in
                        p.move(to: CGPoint(x: pt.x, y: h))
                        p.addLine(to: CGPoint(x: pt.x, y: pt.y))
                    }
                    .stroke(Theme.Palette.gold.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    // Highlighted dot.
                    Circle().fill(Theme.Palette.gold)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(pt)
                    // Value at this point, in the user's currency.
                    Text(Money.format(values[i]))
                        .font(AppFont.text(12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.Palette.ink))
                        .fixedSize()
                        .position(x: min(max(pt.x, 36), w - 36), y: max(pt.y - 20, 12))
                } else if let last = pts.last {
                    Circle().fill(Theme.Palette.gold)
                        .frame(width: 8, height: 8)
                        .position(last)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        guard count > 0 else { return }
                        let idx = Int((g.location.x / max(stepX, 1)).rounded())
                        activeIndex = min(max(idx, 0), count - 1)
                    }
                    .onEnded { _ in activeIndex = nil }
            )
        }
    }
}
