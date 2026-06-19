import SwiftUI

/// Set or adjust the monthly cap for every spend category in one place.
struct BudgetsSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    /// Which category's cap editor is open. Accordion: one at a time, hidden
    /// by default until the row is tapped.
    @State private var expandedCategory: SpendCategory? = nil

    private var editableCategories: [SpendCategory] {
        SpendCategory.allCases.filter { $0 != .income }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                summary
                VStack(spacing: 12) {
                    ForEach(editableCategories) { cat in
                        BudgetRow(
                            category: cat,
                            spent: container.monthSpend(in: cat),
                            cap: capBinding(for: cat),
                            isExpanded: expandedCategory == cat,
                            onToggle: {
                                withAnimation(Theme.Motion.snap) {
                                    expandedCategory = (expandedCategory == cat) ? nil : cat
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly budgets")
                    .font(AppFont.title2)
                    .foregroundColor(Theme.Palette.ink)
                Text("Set a cap per category")
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
        let total = editableCategories.reduce(0.0) { $0 + cap(for: $1) }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Total cap")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                Spacer()
                Text(Money.format(total))
                    .font(AppFont.text(22, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                    .monospacedDigit()
            }
            HStack(alignment: .firstTextBaseline) {
                Text(dailyRateLabel(total: total))
                    .font(AppFont.text(12, weight: .medium))
                    .foregroundColor(Theme.Palette.inkSoft)
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Theme.Palette.gold.opacity(0.07)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Palette.gold.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Theme.Palette.gold.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    /// Spreads the monthly cap evenly across the days in the current month
    /// so users have an intuitive "I can spend $X today" anchor.
    private func dailyRateLabel(total: Double) -> String {
        let cal = Calendar.current
        let days = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        guard total > 0, days > 0 else { return "Set caps to see your daily rate" }
        let perDay = total / Double(days)
        return "\(Money.format(perDay, cents: perDay < 100)) per day"
    }

    private func cap(for category: SpendCategory) -> Double {
        container.budgets.first(where: { $0.category == category })?.monthlyCap ?? 0
    }

    private func capBinding(for category: SpendCategory) -> Binding<Double> {
        Binding(
            get: { cap(for: category) },
            set: { container.setBudget(category: category, cap: $0) }
        )
    }
}

private struct BudgetRow: View {
    let category: SpendCategory
    let spent: Double
    @Binding var cap: Double
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    ZStack {
                        GlassTile(cornerRadius: 10)
                        Text(category.emoji).font(.system(size: 18))
                    }
                    .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.label)
                            .font(AppFont.text(15, weight: .semibold))
                            .foregroundColor(Theme.Palette.ink)
                        Text("\(Money.format(spent)) spent this month")
                            .font(AppFont.text(11))
                            .foregroundColor(Theme.Palette.inkSoft)
                    }
                    Spacer(minLength: 8)
                    Text(cap > 0 ? Money.format(cap) : "Set cap")
                        .font(AppFont.text(15, weight: .bold))
                        .foregroundColor(cap > 0 ? Theme.Palette.ink : Theme.Palette.gold)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Palette.inkMute)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plainTappable)

            if isExpanded {
                CapInputField(cap: $cap)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Theme.Palette.gold.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Palette.gold.opacity(isExpanded ? 0.3 : 0.16), lineWidth: 1)
        )
    }
}

/// Clean, minimal manual entry for a monthly cap: type the exact maximum on a
/// number pad. Commits live to the bound value; the keyboard "Done" dismisses.
/// Shared by the budgets sheet and the per-category drill-in. The "x" clears
/// the cap back to none.
struct CapInputField: View {
    @Binding var cap: Double
    var autofocus: Bool = true

    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(Money.symbol)
                .font(AppFont.display(24, weight: .bold))
                .foregroundColor(Theme.Palette.inkSoft)
            TextField("0", text: $draft)
                .font(AppFont.display(28, weight: .heavy))
                .foregroundColor(Theme.Palette.ink)
                .monospacedDigit()
                .keyboardType(.decimalPad)
                .focused($focused)
                .onChange(of: draft) { newValue in
                    cap = max(0, Money.parseAmount(newValue) ?? 0)
                }
            Text("/ month")
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer(minLength: 0)
            if cap > 0 {
                Button {
                    draft = ""
                    cap = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Palette.inkMute)
                }
                .buttonStyle(.plainTappable)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(focused ? Theme.Palette.gold : Theme.Palette.line,
                        lineWidth: focused ? 2 : 1)
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
                    .font(AppFont.text(15, weight: .semibold))
                    .foregroundColor(Theme.Palette.gold)
            }
        }
        .onAppear {
            draft = cap > 0 ? Money.plainString(cap) : ""
            if autofocus {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focused = true }
            }
        }
    }
}
