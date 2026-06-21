import SwiftUI

/// Archive of goals the user has already funded and acknowledged. Lets them
/// look back without crowding the active list, and bring one back if they
/// want to top it up.
struct PastWinsSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    @State private var detailGoal: Goal?

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summary
                    if container.pastWins.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(container.pastWins) { g in
                                Button { detailGoal = g } label: {
                                    row(for: g)
                                }
                                .buttonStyle(.plainTappable)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .sheet(item: $detailGoal) { g in
            GoalDetailSheet(goal: g)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Past wins")
                    .font(AppFont.title2)
                    .foregroundColor(Theme.Palette.ink)
                Text("Goals you've funded")
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
        let total = container.pastWins.reduce(0) { $0 + $1.targetAmount }
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.Palette.winGoldPastel).frame(width: 48, height: 48)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Palette.winGold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(container.pastWins.count) funded · \(Money.format(total))")
                    .font(AppFont.text(15, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                Text("Tap a win to revisit, or restore it to active.")
                    .font(AppFont.text(11))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No past wins yet.")
                .font(AppFont.text(15, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
            Text("Fund a goal and it lands here once you celebrate it.")
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .softCard()
    }

    private func row(for goal: Goal) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.Palette.winGoldGradient)
                Text(goal.emoji).font(.system(size: 22))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.name)
                    .font(AppFont.text(15, weight: .semibold))
                    .foregroundColor(Theme.Palette.ink)
                Text(metaLabel(for: goal))
                    .font(AppFont.text(11, weight: .medium))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
            Button {
                container.unarchiveGoal(goal.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Restore")
                        .font(AppFont.text(11, weight: .semibold))
                }
                .foregroundColor(Theme.Palette.winGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.Palette.winGoldPastel))
                .overlay(Capsule().stroke(Theme.Palette.winGold.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plainTappable)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(16)
    }

    private func metaLabel(for goal: Goal) -> String {
        let amount = Money.format(goal.targetAmount)
        guard let when = goal.archivedAt else { return amount + " · funded" }
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return "\(amount) · funded \(f.string(from: when))"
    }
}
