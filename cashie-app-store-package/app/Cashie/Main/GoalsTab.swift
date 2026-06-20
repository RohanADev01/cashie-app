import SwiftUI

struct GoalsTab: View {
    @EnvironmentObject var container: AppContainer
    @State private var addingGoal = false
    @State private var detailGoal: Goal?
    @State private var showPastWins = false

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    goalsTracker
                    if container.activeGoals.isEmpty {
                        empty
                    } else {
                        VStack(spacing: 12) {
                            ForEach(container.activeGoals) { g in
                                Button { detailGoal = g } label: {
                                    GoalTile(goal: g)
                                }
                                .buttonStyle(.plainTappable)
                            }
                        }
                    }
                    if !container.pastWins.isEmpty {
                        pastWinsButton
                    }
                    PrimaryButton(title: "+ Start a new goal", trailingArrow: false) {
                        addingGoal = true
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $addingGoal) {
            AddGoalSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $detailGoal) { g in
            GoalDetailSheet(goal: g)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPastWins) {
            PastWinsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Dev affordance: -openGoal jumps straight into the first active
            // goal's detail sheet for screenshots.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-openGoal") {
                // Evaluate inside the delay so goals loaded by bootstrap are picked up.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    detailGoal = container.activeGoals.first
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your goals")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            EmphasizedHeadline(
                raw: "Big <em>destinations</em>",
                font: AppFont.display(36, weight: .bold),
                emColor: Theme.Palette.gold
            )
            Text(subtitle)
                .font(AppFont.text(15, italic: true))
                .foregroundColor(Theme.Palette.inkSoft)
                .padding(.top, 2)
        }
    }

    private var subtitle: String {
        let n = container.activeGoals.count
        let words = ["No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
        let countWord = (0..<words.count).contains(n) ? words[n] : "\(n)"
        if n == 0 {
            return "Nothing in flight yet. Pick something tiny."
        }
        let nudge = n >= 1 ? " Pick one to push this week." : ""
        return "\(countWord) goal\(n == 1 ? "" : "s") in flight.\(nudge)"
    }

    // MARK: - Tracker hero (orange fire-gradient card, mirrors the streak modal
    // hero so Goals reads in the same warm family)

    /// The streak modal's fire gradient, reused so the Goals hero shares the
    /// same warm orange treatment.
    private let fire = [Color(hex: 0xFF5E3A), Color(hex: 0xFF823C), Color(hex: 0xFFB24D)]

    private var goalsTracker: some View {
        let active = container.activeGoals
        let saved = active.reduce(0) { $0 + $1.currentAmount }
        let target = active.reduce(0) { $0 + $1.targetAmount }
        let pct = target > 0 ? min(1, saved / target) : 0
        let pctInt = Int((pct * 100).rounded())

        return ZStack {
            LinearGradient(colors: fire, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.30), .clear],
                           center: .topTrailing, startRadius: 4, endRadius: 320)
            RadialGradient(colors: [.black.opacity(0.10), .clear],
                           center: .bottomLeading, startRadius: 4, endRadius: 280)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.22)).frame(width: 56, height: 56)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(percentHeadline(pctInt: pctInt, active: active.count))
                            .font(AppFont.text(20, weight: .bold))
                            .foregroundColor(.white)
                        Text(trackerSubtitle(saved: saved, target: target,
                                             active: active.count, nearestDays: nearestDaysOut))
                            .font(AppFont.text(12, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                if target > 0 {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.30))
                            Capsule().fill(Color.white)
                                .frame(width: proxy.size.width * CGFloat(pct))
                                .animation(.spring(response: 0.8, dampingFraction: 0.85), value: pct)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(pctInt)% FUNDED")
                            .font(AppFont.text(12, weight: .bold))
                            .tracking(0.4)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Money.format(max(0, target - saved))) to go")
                            .font(AppFont.text(12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        // Soft orange halo so the card glows warm, like the screenshot.
        .shadow(color: Theme.Palette.streak.opacity(0.35), radius: 18, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    private func percentHeadline(pctInt: Int, active: Int) -> String {
        if active == 0 { return "Pick a first goal" }
        if pctInt >= 100 { return "Every goal funded" }
        return "\(pctInt)% of the way there"
    }

    private func trackerSubtitle(saved: Double, target: Double, active: Int, nearestDays: Int?) -> String {
        if active == 0 {
            return "A target turns saving into a streak."
        }
        let pieces = [
            "\(Money.format(saved)) of \(Money.format(target))",
            active == 1 ? "1 goal in flight" : "\(active) goals in flight",
        ]
        let head = pieces.joined(separator: " · ")
        guard let days = nearestDays else { return head }
        if days <= 0 { return "\(head) · next deadline today" }
        if days < 30 { return "\(head) · next in \(days) days" }
        let months = max(1, days / 30)
        return "\(head) · next in \(months) \(months == 1 ? "month" : "months")"
    }

    /// Only goals still in flight count toward "next deadline." A funded
    /// goal isn't on the clock anymore, so it shouldn't surface here.
    private var nearestDaysOut: Int? {
        let cal = Calendar.current
        let inFlight = container.activeGoals.filter { !$0.isAchieved }
        guard let nearest = inFlight.min(by: { $0.targetDate < $1.targetDate }) else { return nil }
        return cal.dateComponents([.day], from: Date(), to: nearest.targetDate).day
    }

    // MARK: - Past wins entry point

    private var pastWinsButton: some View {
        Button { showPastWins = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.Palette.winGoldPastel).frame(width: 36, height: 36)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Palette.winGold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Past wins")
                        .font(AppFont.text(14, weight: .semibold))
                        .foregroundColor(Theme.Palette.ink)
                    Text("\(container.pastWins.count) goal\(container.pastWins.count == 1 ? "" : "s") funded")
                        .font(AppFont.text(11, weight: .medium))
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .padding(16)
            .softCard()
        }
        .buttonStyle(.plainTappable)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Text("Nothing here yet").font(AppFont.display(28, weight: .bold))
            Text("Pick something tiny, a treat in 4 weeks always works.")
                .font(AppFont.callout)
                .foregroundColor(Theme.Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

private struct GoalTile: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    GlassTile(cornerRadius: 10)
                    Text(goal.emoji).font(.system(size: 24))
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(AppFont.text(15, weight: .semibold))
                        .foregroundColor(Theme.Palette.ink)
                    Text(targetLabel)
                        .font(AppFont.text(11, weight: .medium))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                Spacer()
                if goal.isAchieved {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Theme.Palette.winGold)
                } else {
                    Text("\(Int(goal.progress * 100))%")
                        .font(AppFont.text(20, weight: .bold))
                        .foregroundColor(Theme.Palette.ink)
                        .monospacedDigit()
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.lineSoft)
                    Capsule()
                        .fill(goal.isAchieved ? Theme.Palette.winGold : Theme.Palette.gold)
                        .frame(width: proxy.size.width * goal.progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Money.format(goal.currentAmount)) / \(Money.format(goal.targetAmount))")
                    .font(AppFont.text(12, weight: .medium))
                    .foregroundColor(Theme.Palette.inkSoft)
                Spacer()
                paceTag
            }
        }
        .padding(16)
        .softCard()
    }

    private var targetLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        if goal.isAchieved { return "Funded" }
        return "Target · " + f.string(from: goal.targetDate)
    }

    /// Lead with the weekly pace number for in-flight goals; for funded
    /// goals, just say "Funded" in the warm gold so the eye lands on the
    /// completion state, not a pace it doesn't need anymore.
    private var paceTag: some View {
        let weekly = goal.weeklyPace
        if goal.isAchieved {
            return AnyView(Text("Funded")
                .font(AppFont.text(12, weight: .bold))
                .foregroundColor(Theme.Palette.winGold))
        }
        return AnyView(HStack(spacing: 0) {
            Text("~\(Money.symbol)\(Int(weekly.rounded()))")
                .font(AppFont.text(12, weight: .bold))
            Text(" a week")
                .font(AppFont.text(12, weight: .medium))
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .foregroundColor(Theme.Palette.ink))
    }
}
