import SwiftUI

struct TransactionDetailSheet: View {
    let transaction: Transaction
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Palette.ink)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Theme.Palette.bgCream))
                    }
                }
                .padding(.top, 18)

                hero
                detailRows
                insights
                Button { confirmingDelete = true } label: {
                    Text("Delete this transaction")
                        .font(AppFont.text(13, weight: .semibold))
                        .foregroundColor(Theme.Palette.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.redSoft))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.red.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plainTappable)
                .padding(.top, 6)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .confirmationDialog(
            "Delete this transaction?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete \(transaction.merchant) · \(Money.format(transaction.amount, cents: transaction.amount < 100))", role: .destructive) {
                delete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the log permanently and updates your budget totals.")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                ZStack {
                    GlassTile(cornerRadius: 12)
                    Text(transaction.category.emoji).font(.system(size: 24))
                }
                .frame(width: 52, height: 52)
                Text(transaction.merchant)
                    .font(AppFont.title2)
            }
            Text((transaction.isIncome ? "+" : "−") + Money.format(transaction.amount, cents: transaction.amount < 100))
                .font(AppFont.display(40, weight: .heavy))
                .foregroundColor(transaction.isIncome ? Theme.Palette.gold : Theme.Palette.ink)
            Text("\(transaction.category.label) · \(formatted)")
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
        }
    }

    private var detailRows: some View {
        VStack(spacing: 0) {
            row("Logged via", transaction.source.rawValue.capitalized)
            row("Note", transaction.note ?? "-")
            row("Budget impact", budgetImpactLabel)
        }
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
    }

    /// This transaction's amount as a percentage of the category's weekly
    /// cap (monthlyCap × 7 / daysInMonth). Falls back to a non-percentage
    /// label when no cap is set, instead of inventing a denominator.
    private var budgetImpactLabel: String {
        guard !transaction.isIncome else { return "Income · no cap" }
        let cap = container.budgets.first(where: { $0.category == transaction.category })?.monthlyCap ?? 0
        guard cap > 0 else { return "No cap set on \(transaction.category.label.lowercased())" }
        let cal = Calendar.current
        let daysInMonth = cal.range(of: .day, in: .month, for: transaction.date)?.count ?? 30
        let weeklyCap = cap * 7.0 / Double(daysInMonth)
        guard weeklyCap > 0 else { return "No cap set on \(transaction.category.label.lowercased())" }
        let pct = Int((transaction.amount / weeklyCap * 100).rounded())
        return "−\(pct)% of weekly \(transaction.category.label.lowercased())"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(AppFont.text(13, weight: .medium))
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer()
            Text(value).font(AppFont.text(13, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
        }
        .padding(.vertical, 10)
    }

    private var insights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cashie notes")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            if let count = ordinalInsight {
                insightCard("✦", count.title, count.body)
            }
            if let timing = timingInsight {
                insightCard("🕒", timing.title, timing.body)
            }
            if ordinalInsight == nil && timingInsight == nil {
                Text("Log a few more in this category and Cashie will pick out patterns here.")
                    .font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkMute)
                    .padding(.vertical, 6)
            }
        }
    }

    private struct Insight { let title: String; let body: String }

    /// "Nth X spend this month" + how that sits against the category cap.
    /// Returns nil for income or if the math can't be computed.
    private var ordinalInsight: Insight? {
        guard !transaction.isIncome else { return nil }
        let cal = Calendar.current
        let monthTx = container.transactions
            .filter {
                $0.category == transaction.category
                && cal.isDate($0.date, equalTo: transaction.date, toGranularity: .month)
            }
            .sorted { $0.date < $1.date }
        guard let idx = monthTx.firstIndex(of: transaction) else { return nil }
        let n = idx + 1
        let monthSpent = monthTx.prefix(n).reduce(0) { $0 + $1.amount }
        let cap = container.budgets.first(where: { $0.category == transaction.category })?.monthlyCap ?? 0
        let title = "\(ordinal(n)) \(transaction.category.label.lowercased()) spend this month"
        let body: String
        if cap > 0 {
            let pct = Int((monthSpent / cap * 100).rounded())
            body = "Brings \(transaction.category.label.lowercased()) to \(pct)% of the monthly cap."
        } else {
            body = "\(Money.format(monthSpent)) on \(transaction.category.label.lowercased()) so far this month."
        }
        return Insight(title: title, body: body)
    }

    /// Hour pattern across the user's transactions in this category. Bins
    /// every log into one of four 6-hour windows, then surfaces the
    /// dominant one with the share of category logs that land there.
    /// Suppressed when there are fewer than three logs to draw from.
    private var timingInsight: Insight? {
        guard !transaction.isIncome else { return nil }
        let cal = Calendar.current
        let pool = container.transactions.filter { $0.category == transaction.category }
        guard pool.count >= 3 else { return nil }
        let windows: [(label: String, range: ClosedRange<Int>)] = [
            ("the morning",   6...11),
            ("midday",        12...16),
            ("the evening",   17...21),
            ("late at night", 22...23), // wraps; handled below
        ]
        var counts = [Int](repeating: 0, count: windows.count)
        for tx in pool {
            let h = cal.component(.hour, from: tx.date)
            for (i, w) in windows.enumerated() {
                if i == 3 { // late-night wraps over midnight
                    if h >= 22 || h <= 5 { counts[i] += 1; break }
                } else if w.range.contains(h) {
                    counts[i] += 1; break
                }
            }
        }
        guard let topIdx = counts.indices.max(by: { counts[$0] < counts[$1] }) else { return nil }
        let topCount = counts[topIdx]
        guard topCount > 0 else { return nil }
        let pct = Int((Double(topCount) / Double(pool.count) * 100).rounded())
        let title = "Most \(transaction.category.label.lowercased()) lands in \(windows[topIdx].label)"
        let body = "\(pct)% of your \(transaction.category.label.lowercased()) logs hit then."
        return Insight(title: title, body: body)
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    private func insightCard(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.text(13, weight: .semibold))
                Text(desc).font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var formatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: transaction.date)
    }

    private func delete() {
        container.deleteTransaction(transaction.id)
        dismiss()
    }
}
