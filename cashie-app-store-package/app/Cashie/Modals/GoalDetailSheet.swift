import SwiftUI

struct GoalDetailSheet: View {
    let goal: Goal
    /// When set, the "Edit goal" button hands the user off to the closure
    /// instead of presenting the inline EditGoalSheet. Used when this sheet
    /// is reached from outside the Goals tab (e.g. the home Where-it-Went
    /// breakdown), so the user can finish editing on the dedicated tab.
    var onRequestEdit: (() -> Void)? = nil
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss
    @State private var addingDeposit = false
    @State private var depositAmount: String = "20"
    @State private var editing = false
    @State private var pendingRemoval: Deposit?

    /// Always read the latest copy from the container so deposits added in
    /// this sheet update the hero/progress immediately.
    private var liveGoal: Goal {
        container.goals.first(where: { $0.id == goal.id }) ?? goal
    }

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.Palette.ink)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Theme.Palette.bgCream))
                        }
                    }
                    .padding(.top, 18)

                    hero
                    if addingDeposit {
                        depositForm
                    } else {
                        actions
                    }
                    deposits
                    archiveAction
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $editing) {
            EditGoalSheet(goal: liveGoal)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Remove this deposit?",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { dep in
            Button("Remove \(Money.format(dep.amount))", role: .destructive) {
                container.removeDeposit(dep.id, from: liveGoal.id)
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: { dep in
            Text("This takes \(Money.format(dep.amount)) back out of this goal.")
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 14) {
            // Emoji in a GlassTile, matching how goals read on the Goals tab and
            // the home "Where it went" rows.
            ZStack {
                GlassTile(cornerRadius: 14)
                Text(liveGoal.emoji).font(.system(size: 28))
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(liveGoal.name)
                    .font(AppFont.title2)
                    .foregroundColor(Theme.Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(Money.format(liveGoal.currentAmount)) of \(Money.format(liveGoal.targetAmount))")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)
            }

            Spacer(minLength: 12)

            // Progress ring sits on the right, balancing the emoji + text rather
            // than stacking under them with the right half left empty.
            ProgressRing(progress: liveGoal.progress)
                .frame(width: 64, height: 64)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if !liveGoal.isAchieved {
                Button {
                    addingDeposit = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add money").font(AppFont.text(14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 100).fill(Theme.Palette.ink))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plainTappable)
            }
            Button {
                if let onRequestEdit {
                    onRequestEdit()
                } else {
                    editing = true
                }
            } label: {
                Text("Edit goal")
                    .font(AppFont.text(14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 100).fill(Theme.Palette.bgCream))
                    .overlay(RoundedRectangle(cornerRadius: 100).stroke(Theme.Palette.line, lineWidth: 1))
                    .foregroundColor(Theme.Palette.ink)
            }
            .buttonStyle(.plainTappable)
        }
    }

    /// Bottom-of-sheet action that mirrors the celebration sheet for
    /// funded-but-active goals, and the Past wins "restore" flow for
    /// archived ones. Hidden for in-flight goals.
    @ViewBuilder
    private var archiveAction: some View {
        if liveGoal.isArchived {
            Button {
                container.unarchiveGoal(liveGoal.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Restore to active goals")
                        .font(AppFont.text(14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 100).fill(Theme.Palette.bgCream))
                .overlay(RoundedRectangle(cornerRadius: 100).stroke(Theme.Palette.line, lineWidth: 1))
                .foregroundColor(Theme.Palette.ink)
            }
            .buttonStyle(.plainTappable)
        } else if liveGoal.isAchieved {
            Button {
                container.archiveGoal(liveGoal.id)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                    Text("Move to Past wins")
                        .font(AppFont.text(14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 100).fill(Theme.Palette.ink))
                .foregroundColor(.white)
            }
            .buttonStyle(.plainTappable)
        }
    }

    /// Inline form for adding a deposit. Just the amount and a gentle note if
    /// you're putting in more than the goal still needs — no weekly-budget math,
    /// since a goal only ever cares about its own target.
    private var depositForm: some View {
        let typed = Money.parseAmount(depositAmount) ?? 0
        let headroom = max(0, liveGoal.targetAmount - liveGoal.currentAmount)
        let actual = min(typed, headroom)
        let willCap = typed > headroom && headroom > 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("Adding to \(liveGoal.name)")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)

            HStack(spacing: 8) {
                Text(Money.symbol)
                    .font(AppFont.text(20, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkSoft)
                TextField("0", text: $depositAmount)
                    .keyboardType(.decimalPad)
                    .font(AppFont.display(28, weight: .heavy))
                    .foregroundColor(Theme.Palette.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))

            if willCap {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Palette.gold)
                    Text("Only \(Money.format(headroom)) needed to fund this goal. Logging \(Money.format(actual)).")
                        .font(AppFont.text(12))
                        .foregroundColor(Theme.Palette.inkSoft)
                }
            }

            HStack(spacing: 10) {
                Button {
                    addingDeposit = false
                    depositAmount = "20"
                } label: {
                    Text("Cancel")
                        .font(AppFont.text(14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 100).fill(Theme.Palette.bgCream))
                        .overlay(RoundedRectangle(cornerRadius: 100).stroke(Theme.Palette.line, lineWidth: 1))
                        .foregroundColor(Theme.Palette.ink)
                }
                .buttonStyle(.plainTappable)
                Button {
                    if let v = Money.parseAmount(depositAmount) {
                        container.addDeposit(Deposit(amount: v, date: Date()), to: liveGoal.id)
                    }
                    addingDeposit = false
                    depositAmount = "20"
                } label: {
                    Text("Add")
                        .font(AppFont.text(14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 100).fill(Theme.Palette.ink))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plainTappable)
                .disabled(Money.parseAmount(depositAmount) == nil)
                .opacity(Money.parseAmount(depositAmount) == nil ? 0.5 : 1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    private var deposits: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent deposits")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            if liveGoal.deposits.isEmpty {
                Text("Nothing yet, Cashie will pace you.")
                    .font(AppFont.text(13))
                    .foregroundColor(Theme.Palette.inkMute)
                    .padding(.vertical, 10)
            } else {
                ForEach(liveGoal.deposits) { d in
                    HStack {
                        Circle().fill(Theme.Palette.gold).frame(width: 8, height: 8)
                        Text(formatted(d.date))
                            .font(AppFont.text(13))
                            .foregroundColor(Theme.Palette.inkSoft)
                        Spacer()
                        Text("+\(Money.format(d.amount))")
                            .font(AppFont.text(14, weight: .semibold))
                            .foregroundColor(Theme.Palette.gold)
                        Button {
                            pendingRemoval = d
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.Palette.inkMute)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plainTappable)
                        .accessibilityLabel("Remove deposit of \(Money.format(d.amount))")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .softCard()
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.lineSoft, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.Palette.gold,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.smooth, value: progress)
            Text("\(Int(progress * 100))%")
                .font(AppFont.text(15, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
        }
    }
}
