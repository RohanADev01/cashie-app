import SwiftUI

/// Drill-in for one category, shows progress against the cap, the
/// transactions that hit it this month, and lets the user edit the cap.
struct CategoryDetailSheet: View {
    let category: SpendCategory
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    @State private var editing = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                progressCard
                budgetEditor
                txList
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                GlassTile(cornerRadius: 12)
                Text(category.emoji).font(.system(size: 22))
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.label)
                    .font(AppFont.title2)
                    .foregroundColor(Theme.Palette.ink)
                Text("This month")
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

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(Money.format(spent))
                    .font(AppFont.display(48, weight: .heavy))
                    .foregroundColor(Theme.Palette.ink)
                    .monospacedDigit()
                Text("of \(Money.format(cap))")
                    .font(AppFont.text(13))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.ink.opacity(0.06))
                    Capsule()
                        .fill(progressColor)
                        .frame(width: proxy.size.width * progress)
                        .animation(Theme.Motion.smooth, value: progress)
                }
            }
            .frame(height: 6)
            HStack {
                Label(remainingLabel, systemImage: remaining >= 0 ? "checkmark.seal" : "exclamationmark.triangle")
                    .font(AppFont.text(13, weight: .semibold))
                    .foregroundColor(remaining >= 0 ? Theme.Palette.gold : Theme.Palette.red)
                Spacer()
                Text("\(Int(progress * 100))% used")
                    .font(AppFont.text(13))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var budgetEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Monthly cap")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                Spacer()
                Button(editing ? "Done" : "Edit") {
                    withAnimation(Theme.Motion.snap) { editing.toggle() }
                }
                .font(AppFont.text(13, weight: .semibold))
                .foregroundColor(Theme.Palette.gold)
            }
            if editing {
                CapInputField(cap: Binding(
                    get: { cap },
                    set: { container.setBudget(category: category, cap: $0) }
                ))
            } else {
                Text("Tap edit to set this category's monthly cap.")
                    .font(AppFont.text(13))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var txList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transactions")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                Spacer()
                Text("\(monthTransactions.count) total")
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            if monthTransactions.isEmpty {
                Text("No \(category.label.lowercased()) spend yet this month.")
                    .font(AppFont.text(13))
                    .foregroundColor(Theme.Palette.inkMute)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
            } else {
                VStack(spacing: 0) {
                    ForEach(monthTransactions) { tx in
                        TransactionRow(tx: tx, showsDate: true).padding(.vertical, 10)
                        if tx.id != monthTransactions.last?.id {
                            Divider().background(Theme.Palette.lineSoft)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
            }
        }
    }

    // MARK: - Derived

    private var spent: Double { container.monthSpend(in: category) }
    private var cap: Double {
        container.budgets.first(where: { $0.category == category })?.monthlyCap ?? 0
    }
    private var progress: CGFloat {
        guard cap > 0 else { return 0 }
        return min(1, CGFloat(spent / cap))
    }
    private var remaining: Double { cap - spent }
    private var remainingLabel: String {
        remaining >= 0
            ? "\(Money.format(remaining)) left"
            : "\(Money.format(abs(remaining))) over"
    }
    /// Same threshold as the Today tab "Where it went" rows: green under 80%
    /// of the cap, red at/above 80% - keeps the language consistent.
    private var progressColor: Color {
        progress >= 0.80 ? Theme.Palette.red : Theme.Palette.gold
    }
    private var monthTransactions: [Transaction] {
        let cal = Calendar.current
        return container.transactions
            .filter {
                $0.category == category
                && cal.isDate($0.date, equalTo: Date(), toGranularity: .month)
            }
            .sorted { $0.date > $1.date }
    }
}


