import SwiftUI

/// Create or edit a recurring bill. Mirrors AddTransactionSheet's form style
/// (uppercase field labels, white rounded inputs, gold "Save" CTA) so it reads
/// as part of the same family. Pass `editing:` to switch to edit mode.
struct AddBillSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var store = BillsStore.shared

    let editing: RecurringBill?

    @State private var name: String
    @State private var amount: String
    @State private var category: SpendCategory
    @State private var nextDue: Date
    @State private var frequency: RecurringBill.Frequency

    init(editing: RecurringBill? = nil) {
        self.editing = editing
        let bill = editing
        _name = State(initialValue: bill?.name ?? "")
        _amount = State(initialValue: bill.map { Money.plainString($0.amount) } ?? "")
        _category = State(initialValue: bill?.category ?? .bills)
        _nextDue = State(initialValue: bill?.nextDue ?? Date())
        _frequency = State(initialValue: bill?.frequency ?? .monthly)
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
                    TextField("Rent", text: $name)
                        .font(AppFont.body)
                }

                categoryField

                field(label: "Next due") {
                    DatePicker("", selection: $nextDue, displayedComponents: [.date])
                        .labelsHidden()
                }

                frequencyField

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
            Text(editing == nil ? "New bill" : "Edit bill")
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

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6).textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            FlowLayout(spacing: 6) {
                ForEach(SpendCategory.allCases.filter { $0 != .income }) { cat in
                    Button(action: { category = cat }) {
                        HStack(spacing: 6) {
                            Text(cat.emoji)
                            Text(cat.label).font(AppFont.text(13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(category == cat ? Theme.Palette.goldLight : Theme.Palette.bgCream))
                        .overlay(Capsule().stroke(category == cat ? Theme.Palette.gold : Theme.Palette.line, lineWidth: 1))
                        .foregroundColor(Theme.Palette.ink)
                    }
                    .buttonStyle(.plainTappable)
                }
            }
        }
    }

    private var frequencyField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Repeats")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6).textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            FlowLayout(spacing: 6) {
                ForEach(RecurringBill.Frequency.allCases, id: \.self) { f in
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

        if let existing = editing {
            var updated = existing
            updated.name = trimmed
            updated.amount = v
            updated.category = category
            updated.nextDue = nextDue
            updated.frequency = frequency
            updated.anchorDay = Calendar.current.component(.day, from: nextDue)   // re-anchor on date edit
            store.update(updated)
        } else {
            let bill = RecurringBill(
                name: trimmed,
                amount: v,
                category: category,
                nextDue: nextDue,
                frequency: frequency
            )
            store.add(bill)
        }
        // If the bill was saved with a due date already in the past, post it (and
        // any missed cycles) to the spend tab right away.
        container.processDueRecurring()
        dismiss()
    }
}
