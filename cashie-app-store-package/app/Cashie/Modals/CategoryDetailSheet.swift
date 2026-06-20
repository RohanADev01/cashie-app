import SwiftUI

/// Drill-in for one category, shows progress against the cap, the
/// transactions that hit it this month, and lets the user edit the cap.
/// Styled like the main screens and the goal detail sheet: a light page
/// background with white `softCard`s.
struct CategoryDetailSheet: View {
    let category: SpendCategory
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    @State private var editing = false

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
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
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                shape
                    .fill(iconBackground)
                    .overlay(shape.stroke(Theme.Palette.line.opacity(0.7), lineWidth: 1))
                Text(category.emoji).font(.system(size: 24))
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
                    .foregroundColor(progressColor)
                Spacer()
                Text("\(Int(progress * 100))% used")
                    .font(AppFont.text(13))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    private var txList: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(monthTransactions) { tx in
                        TransactionRow(tx: tx, showsDate: true).padding(.vertical, 10)
                        if tx.id != monthTransactions.last?.id {
                            Divider().background(Theme.Palette.lineSoft)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .softCard()
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
    /// Same three states as the Today tab "Where it went" rows: green on track,
    /// amber from 80% of the cap, red at/over it — keeps the language consistent.
    private var progressColor: Color {
        if spent >= cap && cap > 0 { return Theme.Palette.red }
        if progress >= 0.80 { return Theme.Palette.winGold }
        return Theme.Palette.gold
    }
    /// Matches the home row's icon tile: a light wash of the state colour.
    private var iconBackground: Color {
        if spent >= cap && cap > 0 { return Theme.Palette.red.opacity(0.10) }
        if progress >= 0.80 { return Theme.Palette.winGold.opacity(0.16) }
        return Theme.Palette.bgCream
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
