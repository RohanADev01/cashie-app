import SwiftUI

/// One bill: amount + name on top, due chip, then row actions (Mark paid /
/// Edit / Pause / Delete). Mark paid both rolls `nextDue` forward AND logs a
/// real Transaction so the month's Safe to Spend stays consistent.
struct BillDetailSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var store = BillsStore.shared

    let bill: RecurringBill

    @State private var showEdit = false
    @State private var confirmDelete = false

    private var current: RecurringBill? {
        store.bills.first { $0.id == bill.id }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                hero
                actions
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showEdit) {
            if let b = current {
                AddBillSheet(editing: b)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .alert("Delete this bill?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                store.delete(bill.id)
                dismiss()
            }
        } message: {
            Text("\(bill.name) will be removed. Logged transactions stay.")
        }
    }

    private var header: some View {
        HStack {
            Button("Done") { dismiss() }
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer()
            Text("Bill")
                .font(AppFont.headline)
            Spacer()
            Color.clear.frame(width: 40, height: 1)
        }
        .font(AppFont.text(14, weight: .medium))
        .padding(.top, 18)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(bill.category.emoji).font(.system(size: 22))
                Text(bill.name)
                    .font(AppFont.text(17, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
            }
            Text(Money.format(bill.amount, cents: true))
                .font(AppFont.display(48, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
            HStack(spacing: 6) {
                Text(bill.dueLabel())
                    .font(AppFont.text(13, weight: .semibold))
                Text("·").foregroundColor(Theme.Palette.inkSoft)
                Text(bill.frequency.label)
                    .font(AppFont.text(13))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            .foregroundColor(Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .softCard(20)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: markPaidAndLog) {
                Text("Mark as paid")
                    .font(AppFont.text(15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.Palette.gold))
            }
            .buttonStyle(.plainTappable)

            HStack(spacing: 10) {
                Button(action: { showEdit = true }) {
                    actionLabel("Edit", color: Theme.Palette.ink)
                }
                .buttonStyle(.plainTappable)

                Button(action: pause) {
                    actionLabel(bill.isActive ? "Pause" : "Resume", color: Theme.Palette.ink)
                }
                .buttonStyle(.plainTappable)
            }

            Button(action: { confirmDelete = true }) {
                actionLabel("Delete", color: Theme.Palette.red)
            }
            .buttonStyle(.plainTappable)
        }
    }

    private func actionLabel(_ title: String, color: Color) -> some View {
        Text(title)
            .font(AppFont.text(14, weight: .semibold))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private func markPaidAndLog() {
        // Log a real transaction so spend totals reflect the bill, then roll
        // the bill's nextDue forward one cycle. Order matters: log first so
        // BillsStore's update doesn't race with AppContainer's evaluations.
        let tx = Transaction(
            merchant: bill.name,
            amount: bill.amount,
            category: bill.category,
            date: Date(),
            note: "Recurring bill",
            source: .bill
        )
        container.addTransaction(tx)
        store.markPaid(bill.id)
        dismiss()
    }

    private func pause() {
        store.setActive(bill.id, active: !bill.isActive)
        dismiss()
    }
}
