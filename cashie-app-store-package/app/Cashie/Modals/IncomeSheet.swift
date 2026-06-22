import SwiftUI

/// Set or edit the user's income. One income, by design. Mirrors AddBillSheet's
/// form idiom (uppercase field labels, white rounded inputs, gold Save) so it
/// reads as part of the same family. "Clear income" removes it and reverts Safe
/// to Spend to its budget-cap behaviour. Reached from the You tab and from the
/// Today payday chip.
struct IncomeSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var store = IncomeStore.shared

    @State private var amount: String
    @State private var name: String
    @State private var frequency: Income.Frequency
    @State private var nextPayday: Date

    init() {
        let inc = IncomeStore.shared.income
        _amount = State(initialValue: inc.map { Money.plainString($0.amount) } ?? "")
        _name = State(initialValue: inc?.name ?? "Salary")
        _frequency = State(initialValue: inc?.frequency ?? .fortnightly)
        _nextPayday = State(initialValue: inc?.nextPayday ?? Date())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header

                VStack(alignment: .leading, spacing: 6) {
                    Text("Amount")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(0.6).textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)
                    TextField("$0", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(AppFont.display(40, weight: .heavy))
                        .foregroundColor(Theme.Palette.ink)
                }

                field(label: "Name") {
                    TextField("Salary", text: $name)
                        .font(AppFont.body)
                }

                frequencyField

                field(label: "Next payday") {
                    DatePicker("", selection: $nextPayday, displayedComponents: [.date])
                        .labelsHidden()
                }

                if store.income != nil {
                    Button(role: .destructive, action: clear) {
                        Text("Clear income")
                            .font(AppFont.text(14, weight: .semibold))
                            .foregroundColor(Theme.Palette.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plainTappable)
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
    }

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer()
            Text("Income")
                .font(AppFont.headline)
            Spacer()
            Button("Save", action: save)
                .foregroundColor(Theme.Palette.gold)
                .fontWeight(.semibold)
                .opacity(canSave ? 1 : 0.4)
                .disabled(!canSave)
        }
        .font(AppFont.text(14, weight: .medium))
        .padding(.top, 18)
    }

    private var frequencyField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pays")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6).textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            FlowLayout(spacing: 6) {
                ForEach(Income.Frequency.allCases, id: \.self) { f in
                    Button(action: { frequency = f }) {
                        Text(f.label)
                            .font(AppFont.text(13, weight: .medium))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(frequency == f ? Theme.Palette.goldLight : Theme.Palette.bgCream))
                            .overlay(Capsule().stroke(frequency == f ? Theme.Palette.gold : Theme.Palette.line, lineWidth: 1))
                            .foregroundColor(Theme.Palette.ink)
                    }
                    .buttonStyle(.plainTappable)
                }
            }
        }
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6).textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            content()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
        }
    }

    private var canSave: Bool {
        Money.parseAmount(amount) != nil
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard let v = Money.parseAmount(amount) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if var existing = store.income {
            existing.name = trimmed
            existing.amount = v
            existing.frequency = frequency
            existing.nextPayday = nextPayday
            existing.anchorDay = Calendar.current.component(.day, from: nextPayday)   // re-anchor on date edit
            store.set(existing)
        } else {
            store.set(Income(name: trimmed, amount: v, frequency: frequency, nextPayday: nextPayday))
        }
        // If the payday saved is already in the past, post it (and any missed
        // paydays) as received income right away.
        container.processDueRecurring()
        dismiss()
    }

    private func clear() {
        store.clear()
        dismiss()
    }
}
