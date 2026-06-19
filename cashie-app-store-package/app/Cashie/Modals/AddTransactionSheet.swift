import SwiftUI

struct AddTransactionSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    enum Mode: String, CaseIterable, Hashable {
        case expense, income
        var label: String { self == .expense ? "Expense" : "Income" }
    }

    @State private var mode: Mode = .expense
    @State private var amount: String = ""
    @State private var merchant: String = ""
    @State private var category: SpendCategory = .food
    @State private var when: Date = Date()
    @State private var note: String = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Palette.inkSoft)
                    Spacer()
                    Text(mode == .income ? "New income" : "New transaction")
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

                modeToggle

                VStack(alignment: .leading, spacing: 6) {
                    Text("Amount").font(AppFont.text(11, weight: .semibold))
                        .tracking(0.6).textCase(.uppercase).foregroundColor(Theme.Palette.inkSoft)
                    TextField("$0", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(AppFont.display(40, weight: .heavy))
                        .foregroundColor(mode == .income ? Theme.Palette.gold : Theme.Palette.ink)
                }

                field(label: mode == .income ? "Where from?" : "What was it?") {
                    TextField(mode == .income ? "Salary · Acme" : "Don Antonio", text: $merchant)
                        .font(AppFont.body)
                }

                if mode == .expense {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category").font(AppFont.text(11, weight: .semibold))
                            .tracking(0.6).textCase(.uppercase).foregroundColor(Theme.Palette.inkSoft)
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

                field(label: "When") {
                    DatePicker("", selection: $when, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                field(label: "Note (optional)") {
                    TextField("Anything to remember?", text: $note)
                        .font(AppFont.body)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.text(11, weight: .semibold))
                .tracking(0.6).textCase(.uppercase).foregroundColor(Theme.Palette.inkSoft)
            content()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.self) { m in
                Button {
                    mode = m
                    if m == .income {
                        category = .income
                    } else if category == .income {
                        category = .food
                    }
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

    private var canSave: Bool {
        Money.parseAmount(amount) != nil
            && !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard let v = Money.parseAmount(amount) else { return }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMerchant.isEmpty else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let tx = Transaction(
            merchant: trimmedMerchant,
            amount: v,
            category: mode == .income ? .income : category,
            date: when,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        container.addTransaction(tx)
        dismiss()
    }
}
