import SwiftUI

/// Set or adjust the monthly cap for every spend category in one place.
struct BudgetsSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    /// Which category's cap editor is open. Accordion: one at a time, hidden
    /// by default until the row is tapped.
    @State private var expandedCategory: SpendCategory? = nil

    /// Suggest-from-income accordion state. The income value isn't persisted —
    /// it's a one-shot input that feeds the preview math and then drives the
    /// per-category cap when "Apply" is tapped.
    @State private var suggestExpanded: Bool = false
    @State private var suggestIncome: Double = 0
    @State private var confirmingSuggestApply: Bool = false

    private var editableCategories: [SpendCategory] {
        SpendCategory.allCases.filter { $0 != .income }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    summary
                    SuggestFromIncomeCard(
                        income: $suggestIncome,
                        isExpanded: suggestExpanded,
                        perCategory: suggestedPerCategoryCap,
                        savings: suggestedSavings,
                        onToggle: {
                            withAnimation(Theme.Motion.snap) { suggestExpanded.toggle() }
                        },
                        onApply: { confirmingSuggestApply = true }
                    )
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
        .confirmationDialog(
            "Replace all category caps?",
            isPresented: $confirmingSuggestApply,
            titleVisibility: .visible
        ) {
            Button("Set every category to \(Money.format(suggestedPerCategoryCap))", role: .destructive) {
                applySuggestion()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This overwrites any caps you've already set. \(Money.format(suggestedSavings)) is set aside for savings.")
        }
    }

    /// 80% of the entered income split evenly across the 8 spendable categories.
    /// Returns 0 until a real income is entered.
    private var suggestedPerCategoryCap: Double {
        guard suggestIncome > 0, !editableCategories.isEmpty else { return 0 }
        return (suggestIncome * 0.8) / Double(editableCategories.count)
    }

    /// 20% set aside for savings, shown alongside the per-category figure so
    /// the user can see where the rest of the income goes. Not a category —
    /// it's just headroom for goals.
    private var suggestedSavings: Double {
        guard suggestIncome > 0 else { return 0 }
        return suggestIncome * 0.2
    }

    private func applySuggestion() {
        let cap = suggestedPerCategoryCap
        for cat in editableCategories {
            container.setBudget(category: cat, cap: cap)
        }
        withAnimation(Theme.Motion.snap) { suggestExpanded = false }
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
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
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

/// Optional helper sitting above the per-category list: type your monthly
/// income, see what an even split would look like, tap Apply to overwrite
/// every category cap in one shot. Designed so a fresh-install user with no
/// idea what to type gets a sensible baseline they can then tune.
private struct SuggestFromIncomeCard: View {
    @Binding var income: Double
    let isExpanded: Bool
    let perCategory: Double
    let savings: Double
    let onToggle: () -> Void
    let onApply: () -> Void

    private var canApply: Bool { income > 0 && perCategory > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.Palette.gold)
                            .shadow(color: Theme.Palette.gold.opacity(0.35), radius: 6, x: 0, y: 3)
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggest from income")
                            .font(AppFont.text(15, weight: .semibold))
                            .foregroundColor(Theme.Palette.ink)
                        Text("80% across categories · 20% savings")
                            .font(AppFont.text(11))
                            .foregroundColor(Theme.Palette.inkSoft)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Palette.inkMute)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plainTappable)

            if isExpanded {
                IncomeInputField(income: $income)
                previewBreakdown
                PrimaryButton(
                    title: canApply ? "Apply to my budgets" : "Enter your income",
                    trailingArrow: false,
                    background: Theme.Palette.gold,
                    isEnabled: canApply,
                    action: onApply
                )
            }
        }
        .padding(14)
        .softCard()
    }

    private var previewBreakdown: some View {
        VStack(spacing: 8) {
            previewRow(
                label: "Each category",
                value: canApply ? Money.format(perCategory) : "—",
                accent: Theme.Palette.ink
            )
            Divider().background(Theme.Palette.lineSoft)
            previewRow(
                label: "Set aside for savings",
                value: canApply ? Money.format(savings) : "—",
                accent: Theme.Palette.gold
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
    }

    private func previewRow(label: String, value: String, accent: Color) -> some View {
        HStack {
            Text(label)
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer()
            Text(value)
                .font(AppFont.text(15, weight: .bold))
                .foregroundColor(accent)
                .monospacedDigit()
        }
    }
}

/// Clone of `CapInputField` for a monthly-income figure. Same look, but binds
/// to a separate state and clamps to $1M so a stray keypad mash can't
/// suggest a $999,999 / category budget.
private struct IncomeInputField: View {
    @Binding var income: Double

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
                    let parsed = Money.parseAmount(newValue) ?? 0
                    income = min(1_000_000, max(0, parsed))
                }
            Text("/ month")
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer(minLength: 0)
            if income > 0 {
                Button {
                    draft = ""
                    income = 0
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
            draft = income > 0 ? Money.plainString(income) : ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focused = true }
        }
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
        .softCard()
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
