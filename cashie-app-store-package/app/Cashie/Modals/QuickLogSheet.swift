import SwiftUI

/// Reusable Quick Log body, same UI used in onboarding "Try it live" and the
/// in-app sheet, so iOS Shortcuts deep-link can land here too.
struct QuickLogBody: View {
    @Binding var amountText: String
    @Binding var category: SpendCategory
    /// Optional, lets the user label the log (e.g. "Lyft"). When nil the
    /// field is hidden - used by onboarding/setup where naming is noise.
    var merchantName: Binding<String>? = nil
    let leftInBudget: Double
    let onLog: () -> Void

    private let categories: [SpendCategory] = [.food, .transport, .bills, .shopping, .fun, .home, .health, .other]
    private let keys: [String] = ["1","2","3","4","5","6","7","8","9",".","0","⌫"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            categoryGrid
            amountDisplay
            FlowLayout(spacing: 6) {
                ForEach([5, 10, 15, 25, 50], id: \.self) { value in
                    chip(value)
                }
            }
            if let merchantName {
                merchantField(binding: merchantName)
            }
            keypad
            PrimaryButton(title: "Log \(formattedAmount) · \(category.label)",
                          trailingArrow: false,
                          isEnabled: canLog,
                          action: onLog)
        }
    }

    /// Only allow logging a real, positive amount, so the CTA is disabled at $0.
    private var canLog: Bool { Money.parseAmount(amountText) != nil }

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(categories) { cat in
                Button(action: { category = cat }) {
                    VStack(spacing: 4) {
                        Text(cat.emoji).font(.system(size: 22))
                        Text(cat.label).font(AppFont.text(11, weight: .semibold))
                            .foregroundColor(Theme.Palette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(category == cat ? Theme.Palette.goldLight : Theme.Palette.bgCream)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(category == cat ? Theme.Palette.gold : Theme.Palette.line, lineWidth: 1)
                    )
                }
                .buttonStyle(.plainTappable)
            }
        }
    }

    private var amountDisplay: some View {
        // Amount on its own row (full width, scales down); the budget hint sits
        // on a second row so a large amount never squeezes it unreadable.
        VStack(alignment: .leading, spacing: 8) {
            Text(formattedAmount)
                .font(AppFont.display(48, weight: .heavy))
                .foregroundColor(Theme.Palette.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Text("Left in budget")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                Spacer(minLength: 8)
                Text(Money.format(leftInBudget - (Double(amountText) ?? 0)))
                    .font(AppFont.text(15, weight: .bold))
                    .foregroundColor(Theme.Palette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private func merchantField(binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name (optional)")
                .font(AppFont.text(10, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            TextField(placeholder, text: binding)
                .font(AppFont.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
        }
    }

    /// Suggests something natural for the chosen category so the field
    /// feels more like the rest of the transaction list.
    private var placeholder: String {
        switch category {
        case .food: return "e.g. Don Antonio"
        case .transport: return "e.g. Lyft"
        case .shopping: return "e.g. Uniqlo"
        case .fun: return "e.g. Bar Belly"
        case .home: return "e.g. Rent"
        case .health: return "e.g. Equinox"
        case .bills: return "e.g. Netflix"
        case .income: return "e.g. Salary"
        case .other: return "Add a name"
        }
    }

    private func chip(_ value: Int) -> some View {
        Button(action: { amountText = "\(value)" }) {
            Text("\(Money.symbol)\(value)")
                .font(AppFont.text(13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.Palette.bgCream))
                .overlay(Capsule().stroke(Theme.Palette.line, lineWidth: 1))
                .foregroundColor(Theme.Palette.ink)
        }
        .buttonStyle(.plainTappable)
    }

    private var keypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(keys, id: \.self) { key in
                Button(action: { tap(key) }) {
                    Text(key)
                        .font(AppFont.text(22, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
                        .foregroundColor(Theme.Palette.ink)
                }
                .buttonStyle(.plainTappable)
            }
        }
    }

    private var formattedAmount: String {
        if let v = Double(amountText) {
            return Money.format(v, cents: v != floor(v))
        }
        return "$0"
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫":
            if !amountText.isEmpty { amountText.removeLast() }
        case ".":
            if !amountText.contains(".") {
                amountText.append(amountText.isEmpty ? "0." : ".")
            }
        default:
            if amountText == "0" { amountText = key }
            else if amountText.count < 8 { amountText.append(key) }
        }
    }
}

struct QuickLogSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    enum Mode: String, CaseIterable, Hashable {
        case expense, income
        var label: String { self == .expense ? "Expense" : "Income" }
    }

    @State private var mode: Mode
    @State private var amountText: String
    @State private var merchantName: String
    @State private var category: SpendCategory
    @State private var didAutosave = false
    @State private var showSetup = false
    private let autosave: Bool

    /// Seeds the sheet from an optional prefill (deep link / App Intent). With no
    /// prefill it opens blank, matching the FAB behaviour.
    init(prefill: QuickLogPrefill? = nil) {
        let p = prefill ?? QuickLogPrefill()
        let isIncome = (p.category == .income)
        _mode = State(initialValue: isIncome ? .income : .expense)
        _amountText = State(initialValue: p.amount.map(Money.plainString) ?? "")
        _merchantName = State(initialValue: p.merchant ?? "")
        _category = State(initialValue: p.category ?? .food)
        autosave = p.autosave
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Quick Log")
                        .font(AppFont.display(28, weight: .bold))
                    Spacer()
                    // Glowing tap-to-log shortcut in place of the old category
                    // label + full-width banner. Opens the Quick Log setup.
                    QuickLogGlowButton { showSetup = true }
                }
                .padding(.top, 18)

                modeToggle

                if mode == .income {
                    incomeBody
                } else {
                    QuickLogBody(amountText: $amountText,
                                 category: $category,
                                 merchantName: $merchantName,
                                 leftInBudget: leftInBudget,
                                 onLog: handleLog)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .onAppear(perform: autosaveIfNeeded)
        .sheet(isPresented: $showSetup) {
            QuickLogSetupSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    /// When opened via a deep link with `autosave=1` and a valid amount, log
    /// immediately and dismiss instead of waiting for confirmation. Guarded so
    /// it fires at most once.
    private func autosaveIfNeeded() {
        guard autosave, !didAutosave else { return }
        didAutosave = true
        guard Money.parseAmount(amountText) != nil else { return }
        if mode == .income { handleIncomeLog() } else { handleLog() }
    }

    /// Segmented Expense / Income toggle. Switching to Income forces the
    /// category, swaps the body and resets typed text so the previous
    /// expense draft doesn't bleed into an income entry.
    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.self) { m in
                Button {
                    mode = m
                    amountText = ""
                    merchantName = ""
                    category = (m == .income) ? .income : .food
                } label: {
                    Text(m.label)
                        .font(AppFont.text(13, weight: .semibold))
                        .foregroundColor(mode == m ? Theme.Palette.ink : Theme.Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(mode == m ? Color.white : Color.clear)
                                .shadow(color: mode == m ? Color.black.opacity(0.05) : .clear, radius: 2, y: 1)
                        )
                }
                .buttonStyle(.plainTappable)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
    }

    /// Income-mode layout: drop the category grid (income has one category),
    /// keep the keypad + chips + name field, paint the amount gold so the
    /// inflow reads visually distinct from the standard expense flow.
    private var incomeBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(formattedAmount)
                    .font(AppFont.display(48, weight: .heavy))
                    .foregroundColor(Theme.Palette.gold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Text("This month")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)
                    Spacer(minLength: 8)
                    Text(Money.format(container.monthIncomeTotal + (Double(amountText) ?? 0)))
                        .font(AppFont.text(15, weight: .bold))
                        .foregroundColor(Theme.Palette.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            FlowLayout(spacing: 6) {
                ForEach([100, 250, 500, 1000], id: \.self) { value in
                    incomeChip(value)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Where from? (optional)")
                    .font(AppFont.text(10, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                TextField("e.g. Salary · Acme", text: $merchantName)
                    .font(AppFont.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
            }
            keypadView
            PrimaryButton(title: "Log \(formattedAmount) · Income",
                          trailingArrow: false,
                          isEnabled: Money.parseAmount(amountText) != nil,
                          action: handleIncomeLog)
        }
    }

    private func incomeChip(_ value: Int) -> some View {
        Button(action: { amountText = "\(value)" }) {
            Text(Money.symbol + (NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)))
                .font(AppFont.text(13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.Palette.bgCream))
                .overlay(Capsule().stroke(Theme.Palette.line, lineWidth: 1))
                .foregroundColor(Theme.Palette.ink)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plainTappable)
    }

    private var keypadView: some View {
        let keys = ["1","2","3","4","5","6","7","8","9",".","0","⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(keys, id: \.self) { key in
                Button(action: { tap(key) }) {
                    Text(key)
                        .font(AppFont.text(22, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
                        .foregroundColor(Theme.Palette.ink)
                }
                .buttonStyle(.plainTappable)
            }
        }
    }

    private var formattedAmount: String {
        if let v = Double(amountText) {
            return Money.format(v, cents: v != floor(v))
        }
        return "$0"
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫":
            if !amountText.isEmpty { amountText.removeLast() }
        case ".":
            if !amountText.contains(".") {
                amountText.append(amountText.isEmpty ? "0." : ".")
            }
        default:
            if amountText == "0" { amountText = key }
            else if amountText.count < 8 { amountText.append(key) }
        }
    }

    private var leftInBudget: Double {
        let cap = container.budgets.first(where: { $0.category == category })?.monthlyCap ?? 0
        let spent = container.monthSpend(in: category)
        return max(0, cap - spent)
    }

    private func handleLog() {
        guard let amount = Double(amountText), amount > 0 else { return }
        let trimmed = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.isEmpty ? defaultMerchant() : trimmed
        let tx = Transaction(merchant: label,
                             amount: amount,
                             category: category,
                             date: Date(),
                             source: .quicklog)
        container.addTransaction(tx)
        dismiss()
    }

    private func handleIncomeLog() {
        guard let amount = Double(amountText), amount > 0 else { return }
        let trimmed = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.isEmpty ? "Income" : trimmed
        let tx = Transaction(merchant: label,
                             amount: amount,
                             category: .income,
                             date: Date(),
                             source: .quicklog)
        container.addTransaction(tx)
        dismiss()
    }

    private func defaultMerchant() -> String {
        switch category {
        case .food: return "Food"
        case .transport: return "Transit"
        case .shopping: return "Shopping"
        case .fun: return "Fun out"
        case .home: return "Home"
        case .health: return "Health"
        case .bills: return "Bill"
        case .income: return "Income"
        case .other: return "Other"
        }
    }
}
