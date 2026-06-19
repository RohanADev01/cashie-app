import SwiftUI

struct SpendTab: View {
    @EnvironmentObject var container: AppContainer
    @State private var periodOffset: Int = 0   // 0 = current month, -1 = previous, ...
    @State private var selectedTx: Transaction?
    @State private var showBudgets = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    periodPager
                        .padding(.top, 22)
                    // Drag along the chart to scrub the running spend at each
                    // point. (Manage Budgets is still reachable from the spend
                    // figure above.)
                    SpendChart(values: cumulativeTotals)
                        .frame(height: 140)
                        .padding(.top, 14)
                    transactionsList
                        .padding(.top, 24)
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
        .sheet(isPresented: $showBudgets) {
            BudgetsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your spending")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            EmphasizedHeadline(
                raw: "Where it <em>goes.</em>",
                font: AppFont.display(36, weight: .bold),
                emColor: Theme.Palette.gold
            )
            .padding(.top, 4)
            .padding(.bottom, 22)

            // Tapping the spend figure opens Manage Budgets, same as the chart.
            Button { showBudgets = true } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(periodKicker)
                            .font(AppFont.text(11, weight: .semibold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundColor(Theme.Palette.inkSoft)
                        Spacer()
                        Text("Set budgets →")
                            .font(AppFont.text(11, weight: .medium))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundColor(Theme.Palette.gold)
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
        }
    }

    private var periodPager: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(Theme.Motion.snap) { periodOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.Palette.bgCream))
                    .overlay(Circle().stroke(Theme.Palette.line, lineWidth: 1))
            }
            .buttonStyle(.plainTappable)

            Text(periodLabel)
                .font(AppFont.text(13, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.ink)
                .frame(maxWidth: .infinity)
                .monospacedDigit()

            Button {
                withAnimation(Theme.Motion.snap) { periodOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(periodOffset < 0 ? Theme.Palette.ink : Theme.Palette.inkMute)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.Palette.bgCream))
                    .overlay(Circle().stroke(Theme.Palette.line, lineWidth: 1))
            }
            .buttonStyle(.plainTappable)
            .disabled(periodOffset >= 0)
            .opacity(periodOffset >= 0 ? 0.5 : 1)
        }
    }

    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(grouped, id: \.day) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(group.day).font(AppFont.subhead).foregroundColor(Theme.Palette.ink)
                        Spacer()
                        Text("−\(Money.format(group.total, cents: true))")
                            .font(AppFont.text(13, weight: .semibold))
                            .foregroundColor(Theme.Palette.inkSoft)
                    }
                    VStack(spacing: 0) {
                        ForEach(group.txs) { tx in
                            Button { selectedTx = tx } label: {
                                TransactionRow(tx: tx)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plainTappable)
                            if tx.id != group.txs.last?.id {
                                Divider().background(Theme.Palette.lineSoft)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.lineSoft, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Data

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

    private var periodSpend: Double {
        periodTransactions
            .filter { $0.category != .income }
            .reduce(0) { $0 + $1.amount }
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
        for tx in periodTransactions where tx.category != .income {
            let idx = cal.dateComponents([.day], from: r.start, to: tx.date).day ?? 0
            if idx >= 0 && idx < dayCount {
                values[idx] += tx.amount
            }
        }
        return values
    }

    private var grouped: [(day: String, total: Double, txs: [Transaction])] {
        let cal = Calendar.current
        let dayMonth = DateFormatter(); dayMonth.dateFormat = "EEE d MMM"
        let bucket = DateFormatter(); bucket.dateFormat = "yyyy-MM-dd"
        let bucketed = Dictionary(grouping: periodTransactions) {
            bucket.string(from: $0.date)
        }
        return bucketed.keys.sorted(by: >).map { key in
            let txs = bucketed[key]!.sorted { $0.date > $1.date }
            let total = txs.filter { $0.category != .income }.reduce(0) { $0 + $1.amount }
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
            return (day: label, total: total, txs: txs)
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

    private var amountLabel: String {
        let prefix = tx.isIncome ? "+" : "−"
        return prefix + Money.format(tx.amount, cents: true)
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
