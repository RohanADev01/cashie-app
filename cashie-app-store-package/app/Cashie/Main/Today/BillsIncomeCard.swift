import SwiftUI

/// One Today card for both money coming in (income) and going out (bills), in the
/// same family as "Where it went" (bold title + rows + softCard). Combining them
/// keeps Today compact: when nothing is set it's just two thin "Add" rows under a
/// single header, instead of two full cards. Income sits on top (money in), bills
/// below (money out). Tapping income opens setup; tapping a bill opens its detail;
/// "See all" opens the full bills list.
struct BillsIncomeCard: View {
    @EnvironmentObject var container: AppContainer
    @ObservedObject private var billsStore = BillsStore.shared
    @ObservedObject private var incomeStore = IncomeStore.shared

    @State private var showAddBill = false
    @State private var showIncome = false
    @State private var openBillsList = false
    @State private var selectedBill: RecurringBill?

    private var upcoming: [RecurringBill] {
        Array(billsStore.upcoming(within: 14).prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bills & income")
                    .font(AppFont.text(17, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                Spacer()
                if !billsStore.bills.isEmpty {
                    Button { openBillsList = true } label: { PillLink(title: "See all") }
                        .buttonStyle(.plainTappable)
                }
            }
            .padding(.bottom, 4)

            incomeSection
            Divider().background(Theme.Palette.lineSoft)
            billsSection
        }
        .padding(18)
        .softCard(20)
        .sheet(isPresented: $showIncome) {
            IncomeSheet().presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddBill) {
            AddBillSheet().presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $openBillsList) {
            BillsListSheet().presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedBill) { bill in
            BillDetailSheet(bill: bill).presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder private var incomeSection: some View {
        if let inc = incomeStore.income, inc.isActive {
            Button { showIncome = true } label: { IncomeRowContent(income: inc) }
                .buttonStyle(.plainTappable)
        } else {
            Button { showIncome = true } label: {
                AddRow(emoji: "💵", title: "Add your income",
                       subtitle: "So Safe to Spend knows your pay")
            }
            .buttonStyle(.plainTappable)
        }
    }

    @ViewBuilder private var billsSection: some View {
        if billsStore.bills.isEmpty {
            Button { showAddBill = true } label: {
                AddRow(emoji: "🧾", title: "Add a bill",
                       subtitle: "Rent, subscriptions and regulars")
            }
            .buttonStyle(.plainTappable)
        } else if upcoming.isEmpty {
            Button { openBillsList = true } label: {
                AddRow(emoji: "🧾", title: "Bills",
                       subtitle: "Nothing due in the next two weeks", showsAdd: false)
            }
            .buttonStyle(.plainTappable)
        } else {
            ForEach(Array(upcoming.enumerated()), id: \.element.id) { idx, bill in
                Button { selectedBill = bill } label: { BillRow(bill: bill) }
                    .buttonStyle(.plainTappable)
                if idx < upcoming.count - 1 {
                    Divider().background(Theme.Palette.lineSoft)
                }
            }
        }
    }
}

/// A thin "nothing set yet" row: emoji tile + title + subtitle, with a gold "+"
/// affordance on the right. Used for the empty income / bills slots so the card
/// stays small until the user adds something.
private struct AddRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    var showsAdd: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                GlassTile(cornerRadius: 12)
                Text(emoji).font(.system(size: 18))
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.text(14, weight: .medium))
                    .foregroundColor(Theme.Palette.ink)
                Text(subtitle)
                    .font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if showsAdd {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Palette.gold)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

/// The income row when pay is set: 💵 tile, name + next payday on the left, the
/// per-pay amount + frequency on the right. Same shape as `BillRow`.
private struct IncomeRowContent: View {
    let income: Income

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                GlassTile(cornerRadius: 12)
                Text("💵").font(.system(size: 18))
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(income.name)
                    .font(AppFont.text(14, weight: .medium))
                    .foregroundColor(Theme.Palette.ink)
                    .lineLimit(1)
                Text(income.paydayLabel())
                    .font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.format(income.amount))
                    .font(AppFont.text(14, weight: .semibold))
                    .foregroundColor(Theme.Palette.ink)
                    .monospacedDigit()
                Text(income.frequency.label)
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

/// One bill row, shared by the Today card and the Bills list sheet. Same visual
/// family as CategoryRowFull (emoji tile + body + amount on right).
struct BillRow: View {
    let bill: RecurringBill

    private var dueColor: Color {
        let days = bill.daysUntilDue()
        if days < 0 { return Theme.Palette.red }
        if days <= 1 { return Theme.Palette.streak }
        return Theme.Palette.inkSoft
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                GlassTile(cornerRadius: 12)
                Text(bill.category.emoji).font(.system(size: 18))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(bill.name)
                    .font(AppFont.text(14, weight: .medium))
                    .foregroundColor(Theme.Palette.ink)
                    .lineLimit(1)
                Text(bill.dueLabel())
                    .font(AppFont.text(12))
                    .foregroundColor(dueColor)
            }

            Spacer(minLength: 8)

            Text(Money.format(bill.amount, cents: true))
                .font(AppFont.text(14, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
                .monospacedDigit()
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
