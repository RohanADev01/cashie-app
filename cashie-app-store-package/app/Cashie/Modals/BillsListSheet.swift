import SwiftUI

/// Full bills list. Reached from the You tab ("Bills" row) and from the Today
/// "See all" link on UpcomingBillsCard. Two sections: Upcoming (next 14 days)
/// and All bills. + Add in the header opens AddBillSheet.
struct BillsListSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var store = BillsStore.shared

    @State private var showAdd = false
    @State private var selected: RecurringBill?

    private var upcoming: [RecurringBill] {
        store.upcoming(within: 14)
    }

    private var all: [RecurringBill] {
        store.bills.sorted { $0.nextDue < $1.nextDue }
    }

    private var monthlyTotal: Double {
        store.upcomingThisMonth()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                if store.bills.isEmpty {
                    emptyState
                } else {
                    monthlyTotalCard
                    if !upcoming.isEmpty {
                        sectionHeading("Upcoming")
                        list(upcoming)
                    }
                    sectionHeading("All bills")
                    list(all)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showAdd) {
            AddBillSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selected) { bill in
            BillDetailSheet(bill: bill)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            Button("Done") { dismiss() }
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer()
            Text("Bills")
                .font(AppFont.headline)
            Spacer()
            Button(action: { showAdd = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add")
                        .font(AppFont.text(13, weight: .semibold))
                }
                .foregroundColor(Theme.Palette.gold)
            }
        }
        .font(AppFont.text(14, weight: .medium))
        .padding(.top, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🧾")
                .font(.system(size: 42))
                .padding(.top, 36)
            Text("No bills yet")
                .font(AppFont.text(17, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
            Text("Add your rent, subscriptions and other regulars so Safe to Spend can plan around them.")
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: { showAdd = true }) {
                Text("Add your first bill")
                    .font(AppFont.text(15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.Palette.gold))
            }
            .buttonStyle(.plainTappable)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var monthlyTotalCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Due this month")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            Text(Money.format(monthlyTotal, cents: true))
                .font(AppFont.display(36, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .softCard(20)
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(AppFont.text(11, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundColor(Theme.Palette.inkSoft)
            .padding(.top, 4)
    }

    private func list(_ items: [RecurringBill]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, bill in
                Button { selected = bill } label: {
                    BillRow(bill: bill)
                }
                .buttonStyle(.plainTappable)
                if idx < items.count - 1 {
                    Divider().background(Theme.Palette.lineSoft)
                }
            }
        }
        .padding(18)
        .softCard(20)
    }
}
