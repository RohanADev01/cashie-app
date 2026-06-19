import SwiftUI

/// Drilldown shown when the user taps "This month →" on the home screen.
/// Renders a card per category with this month's spend, cap, share of the
/// total, and tap-through to the existing CategoryDetailSheet.
struct MonthBreakdownSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategory: SpendCategory?
    @State private var selectedGoalID: UUID?
    @State private var showBudgets = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                summary
                if rows.isEmpty && savingsRows.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10),
                                  GridItem(.flexible(), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(rows, id: \.category) { row in
                            Button { selectedCategory = row.category } label: {
                                CategoryBreakdownCard(row: row, monthTotal: monthTotal)
                            }
                            .buttonStyle(.plainTappable)
                        }
                        ForEach(savingsRows, id: \.id) { row in
                            Button { selectedGoalID = row.id } label: {
                                SavingsBreakdownCard(row: row, monthTotal: monthTotal)
                            }
                            .buttonStyle(.plainTappable)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .sheet(item: $selectedCategory) { cat in
            CategoryDetailSheet(category: cat)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBudgets) {
            BudgetsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding<GoalSelection?>(
            get: { selectedGoalID.flatMap { id in
                container.goals.first(where: { $0.id == id }).map { GoalSelection(goal: $0) }
            } },
            set: { selectedGoalID = $0?.goal.id }
        )) { sel in
            GoalDetailSheet(goal: sel.goal, onRequestEdit: {
                container.mainTab = .goals
                selectedGoalID = nil
                dismiss()
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    /// Sheet-item wrapper so the binding has an `Identifiable` payload while
    /// the source of truth stays a `UUID?` we can clear on dismiss.
    private struct GoalSelection: Identifiable {
        let goal: Goal
        var id: UUID { goal.id }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthLabel)
                    .font(AppFont.title2)
                    .foregroundColor(Theme.Palette.ink)
                Text("Where it went")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
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

    private var summary: some View {
        let cap = container.budgets.reduce(0) { $0 + $1.monthlyCap }
        let pct = cap > 0 ? min(1, monthTotal / cap) : 0
        let overCap = cap > 0 && monthTotal > cap
        let remaining = max(0, cap - monthTotal)
        return Button { showBudgets = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                // "Set budgets" lives on its own row so it never competes with
                // the amount for horizontal space.
                HStack {
                    Text("Spent this month")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)
                    Spacer(minLength: 8)
                    Text("Set budgets →")
                        .font(AppFont.text(11, weight: .medium))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.gold)
                }
                // Amount + "of cap" get the full width and scale down rather
                // than wrap when the numbers are large.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Money.format(monthTotal))
                        .font(AppFont.display(40, weight: .heavy))
                        .foregroundColor(Theme.Palette.ink)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .layoutPriority(1)
                    Text("of \(Money.format(cap))")
                        .font(AppFont.text(13))
                        .foregroundColor(Theme.Palette.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.ink.opacity(0.06))
                        Capsule()
                            .fill(overCap ? Theme.Palette.red : Theme.Palette.gold)
                            .frame(width: proxy.size.width * pct)
                    }
                }
                .frame(height: 6)
                HStack {
                    Text("\(Int(pct * 100))% of monthly cap")
                        .font(AppFont.text(12))
                        .foregroundColor(Theme.Palette.inkSoft)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(Money.format(remaining)) left")
                        .font(AppFont.text(12, weight: .semibold))
                        .foregroundColor(Theme.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No spend logged \(monthLabel.lowercased()).")
                .font(AppFont.text(15, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
            Text("Anything you log will start showing up here as cards.")
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    // MARK: - Derived

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: Date())
    }

    private var rows: [BreakdownRow] {
        SpendCategory.allCases.compactMap { cat -> BreakdownRow? in
            guard cat != .income else { return nil }
            let spent = container.monthSpend(in: cat)
            guard spent > 0 else { return nil }
            let cap = container.budgets.first(where: { $0.category == cat })?.monthlyCap ?? 0
            let count = monthTransactionCount(in: cat)
            return BreakdownRow(category: cat, spent: spent, cap: cap, count: count)
        }
        .sorted { $0.spent > $1.spent }
    }

    /// Per-goal deposits made this month. Each goal that received a
    /// deposit during the current calendar month becomes its own card,
    /// alongside the spend categories. Treats deposits as outflows so the
    /// breakdown matches Where-it-went's "Saving" line on home.
    var savingsRows: [SavingsRow] {
        let cal = Calendar.current
        return container.goals.compactMap { goal in
            let amount = goal.deposits
                .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }
            guard amount > 0 else { return nil }
            let count = goal.deposits.filter {
                cal.isDate($0.date, equalTo: Date(), toGranularity: .month)
            }.count
            return SavingsRow(id: goal.id, name: goal.name, emoji: goal.emoji,
                              amount: amount, count: count)
        }
        .sorted { $0.amount > $1.amount }
    }

    private var monthTotal: Double {
        rows.reduce(0) { $0 + $1.spent }
            + savingsRows.reduce(0) { $0 + $1.amount }
    }

    private func monthTransactionCount(in category: SpendCategory) -> Int {
        let cal = Calendar.current
        return container.transactions.filter {
            $0.category == category
            && cal.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }.count
    }

    struct BreakdownRow {
        let category: SpendCategory
        let spent: Double
        let cap: Double
        let count: Int
    }

    struct SavingsRow {
        let id: UUID
        let name: String
        let emoji: String
        let amount: Double
        let count: Int
    }
}

private struct CategoryBreakdownCard: View {
    let row: MonthBreakdownSheet.BreakdownRow
    let monthTotal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    GlassTile(cornerRadius: 10)
                    Text(row.category.emoji).font(.system(size: 18))
                }
                .frame(width: 34, height: 34)
                Spacer()
                Text("\(sharePct)%")
                    .font(AppFont.text(11, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.Palette.bgCream))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.category.label)
                    .font(AppFont.text(12, weight: .semibold))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                Text(Money.format(row.spent))
                    .font(AppFont.display(26, weight: .heavy))
                    .foregroundColor(Theme.Palette.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.ink.opacity(0.06))
                    Capsule()
                        .fill(barColor)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 4)
            HStack {
                Text(capLabel)
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .lineLimit(1)
                Spacer()
                Text("\(row.count) \(row.count == 1 ? "log" : "logs")")
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkMute)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var sharePct: Int {
        guard monthTotal > 0 else { return 0 }
        return Int((row.spent / monthTotal * 100).rounded())
    }

    private var progress: CGFloat {
        guard row.cap > 0 else { return 0 }
        return min(1, CGFloat(row.spent / row.cap))
    }

    private var barColor: Color {
        guard row.cap > 0 else { return Theme.Palette.inkMute }
        return row.spent > row.cap ? Theme.Palette.red : Theme.Palette.gold
    }

    private var capLabel: String {
        if row.cap > 0 {
            return "of \(Money.format(row.cap))"
        }
        return "no cap set"
    }
}

private struct SavingsBreakdownCard: View {
    let row: MonthBreakdownSheet.SavingsRow
    let monthTotal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    GlassTile(cornerRadius: 10)
                    Text(row.emoji).font(.system(size: 18))
                }
                .frame(width: 34, height: 34)
                Spacer()
                Text("\(sharePct)%")
                    .font(AppFont.text(11, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.Palette.bgCream))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(AppFont.text(12, weight: .semibold))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .lineLimit(1)
                Text(Money.format(row.amount))
                    .font(AppFont.display(26, weight: .heavy))
                    .foregroundColor(Theme.Palette.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            HStack {
                Text("Saved this month")
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkSoft)
                Spacer()
                Text("\(row.count) \(row.count == 1 ? "deposit" : "deposits")")
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkMute)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var sharePct: Int {
        guard monthTotal > 0 else { return 0 }
        return Int((row.amount / monthTotal * 100).rounded())
    }
}
