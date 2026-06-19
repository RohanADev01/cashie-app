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
    @State private var showBudgets = false
    @State private var pendingRemoval: Deposit?

    /// Always read the latest copy from the container so deposits added in
    /// this sheet update the hero/progress immediately.
    private var liveGoal: Goal {
        container.goals.first(where: { $0.id == goal.id }) ?? goal
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
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
                weekBudgetCard
                deposits
                archiveAction
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $editing) {
            EditGoalSheet(goal: liveGoal)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBudgets) {
            BudgetsSheet()
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
            Text("This frees up \(Money.format(dep.amount)) in your weekly budget.")
        }
    }

    private var hero: some View {
        HStack(spacing: 16) {
            Text(liveGoal.emoji).font(.system(size: 56))
            VStack(alignment: .leading, spacing: 4) {
                Text(liveGoal.name).font(AppFont.title1)
                Text("\(Money.format(liveGoal.currentAmount)) of \(Money.format(liveGoal.targetAmount))")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)
                ProgressRing(progress: liveGoal.progress)
                    .frame(width: 80, height: 80)
                    .padding(.top, 8)
            }
            Spacer()
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

    /// Inline form for adding a deposit. Replaces the old alert so the
    /// user can see the weekly budget impact while typing the amount.
    private var depositForm: some View {
        let info = weekInfo
        let typed = Money.parseAmount(depositAmount) ?? 0
        let headroom = max(0, liveGoal.targetAmount - liveGoal.currentAmount)
        let actual = min(typed, headroom)
        let willCap = typed > headroom && headroom > 0
        let projectedSpent = info.spent + actual
        let projectedLeft = info.cap - projectedSpent
        let projectedOver = info.cap > 0 && projectedSpent > info.cap

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

            if info.cap > 0 {
                HStack {
                    Text("After this deposit, this week")
                        .font(AppFont.text(12))
                        .foregroundColor(Theme.Palette.inkSoft)
                    Spacer()
                    Text(projectedOver
                         ? "~\(Money.format(projectedSpent - info.cap)) over budget"
                         : "~\(Money.format(max(0, projectedLeft))) left")
                        .font(AppFont.text(12, weight: .semibold))
                        .foregroundColor(projectedOver ? Theme.Palette.red : Theme.Palette.gold)
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
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Palette.line, lineWidth: 1))
    }

    /// Always-visible "this week" budget summary so users see how much
    /// headroom they have before they tap Add money. Tapping it opens
    /// Manage Budgets, since the weekly headroom is derived from the caps.
    private var weekBudgetCard: some View {
        let info = weekInfo
        let pct = info.cap > 0 ? min(1, info.spent / info.cap) : 0
        let overCap = info.cap > 0 && info.spent > info.cap
        let remaining = max(0, info.cap - info.spent)

        return Button { showBudgets = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("This week's budget")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)
                    Spacer()
                    Text("Set budgets →")
                        .font(AppFont.text(11, weight: .medium))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.gold)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Money.format(info.spent, cents: info.spent < 100))
                        .font(AppFont.display(24, weight: .heavy))
                        .foregroundColor(Theme.Palette.ink)
                        .monospacedDigit()
                    if info.cap > 0 {
                        Text("of \(Money.format(info.cap, cents: info.cap < 100))")
                            .font(AppFont.text(12))
                            .foregroundColor(Theme.Palette.inkSoft)
                    }
                    Spacer()
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.ink.opacity(0.06))
                        Capsule()
                            .fill(overCap ? Theme.Palette.red : Theme.Palette.gold)
                            .frame(width: proxy.size.width * CGFloat(pct))
                    }
                }
                .frame(height: 4)
                HStack {
                    Text(info.cap <= 0
                         ? "Set caps in budgets to track weekly headroom"
                         : (overCap
                            ? "~\(Money.format(info.spent - info.cap)) over weekly cap"
                            : "~\(Money.format(remaining)) left to spend or save this week"))
                        .font(AppFont.text(11, weight: .medium))
                        .foregroundColor(overCap ? Theme.Palette.red : Theme.Palette.inkSoft)
                    Spacer()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Palette.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
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
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private struct WeekInfo {
        let spent: Double
        let cap: Double
    }

    /// Mirrors the home tab's weekly tracker: rolling 7-day window where
    /// outflows include both expenses and goal deposits, weighed against
    /// a prorated weekly cap derived from the user's monthly category caps.
    private var weekInfo: WeekInfo {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekStart = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let txs = container.transactions.filter {
            $0.category != .income && $0.date >= weekStart
        }
        let weekDeposits = container.goals.flatMap(\.deposits)
            .filter { $0.date >= weekStart }
        let spent = txs.reduce(0) { $0 + $1.amount }
            + weekDeposits.reduce(0) { $0 + $1.amount }
        let monthCap = container.budgets.reduce(0) { $0 + $1.monthlyCap }
        let daysInMonth = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        let weeklyCap = monthCap * 7.0 / Double(daysInMonth)
        return WeekInfo(spent: spent, cap: weeklyCap)
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
