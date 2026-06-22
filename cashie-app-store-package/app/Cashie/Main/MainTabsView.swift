import SwiftUI

enum MainTab: Hashable {
    case today, spend, goals, you
}

struct MainTabsView: View {
    @EnvironmentObject var container: AppContainer

    /// Lets `-tab spend|goals|you` jump straight to a tab in the simulator.
    private static var initialTab: MainTab {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-tab"), i + 1 < args.count else {
            return .today
        }
        switch args[i + 1] {
        case "spend": return .spend
        case "goals": return .goals
        case "you": return .you
        default: return .today
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Palette.pageBottom.ignoresSafeArea()

            Group {
                switch container.mainTab {
                case .today: TodayTab(onQuickLog: { container.presentQuickLog() })
                case .spend: SpendTab()
                case .goals: GoalsTab()
                case .you: YouTab()
                }
            }
            // Rebuild the active tab when the display currency changes so every
            // money label (including child rows that don't observe Money) refreshes.
            .id(container.currencyCode)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.bottom, 80)

            TabBar(selected: $container.mainTab, onQuickLog: { container.presentQuickLog() })
        }
        .sheet(isPresented: $container.quickLogPresented) {
            QuickLogSheet(prefill: container.quickLogPrefill)
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
                .onDisappear { container.quickLogPrefill = nil }
        }
        // Single, tab-independent presenter for every celebration. Badges and
        // rank-ups use a fullScreenCover (a separate channel from the sheet
        // stack, so they fire immediately over any open sheet); a funded goal
        // keeps its medium sheet. The container's queue guarantees only one is
        // ever active, so the two presentations never collide.
        .fullScreenCover(item: coverCelebration, onDismiss: { container.presentNextCelebration() }) { celebration in
            switch celebration {
            case .badge(let b): BadgeUnlockedSheet(badge: b)
            case .rank(let r): RankUpCelebrationSheet(rank: r)
            case .goal: EmptyView()
            }
        }
        .sheet(item: goalCelebration, onDismiss: { container.presentNextCelebration() }) { celebration in
            if case .goal(let g) = celebration {
                GoalCelebrationSheet(goal: g)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
        }
        .onAppear {
            container.mainTab = MainTabsView.initialTab
            // Post any recurring bills/income whose date passed while the app was
            // away, so Safe to Spend reflects what has actually happened.
            container.processDueRecurring()
            // Catch achievements that grew with time while the app was away
            // (months-active loyalty, a streak day rolling over) with no data
            // mutation to trigger detection.
            container.evaluateAchievements()
        }
        .onShake { container.presentQuickLog() } // dev affordance: shake = open quick log
    }

    /// Non-nil only for badge/rank celebrations, routed to the fullScreenCover.
    private var coverCelebration: Binding<Celebration?> {
        Binding(
            get: {
                switch container.currentCelebration {
                case .badge, .rank: return container.currentCelebration
                default: return nil
                }
            },
            set: { newValue in if newValue == nil { container.currentCelebration = nil } }
        )
    }

    /// Non-nil only for the funded-goal celebration, routed to the sheet.
    private var goalCelebration: Binding<Celebration?> {
        Binding(
            get: {
                if case .goal = container.currentCelebration { return container.currentCelebration }
                return nil
            },
            set: { newValue in if newValue == nil { container.currentCelebration = nil } }
        )
    }
}

private struct TabBar: View {
    @Binding var selected: MainTab
    let onQuickLog: () -> Void

    var body: some View {
        ZStack {
            // The "+" mid-button overhangs the bar.
            HStack(spacing: 0) {
                tabItem(.today, icon: "house.fill", label: "Today")
                tabItem(.spend, icon: "chart.bar.fill", label: "Spend")
                Spacer().frame(width: 64)   // gap for the floating + button
                tabItem(.goals, icon: "flag.fill", label: "Goals")
                tabItem(.you, icon: "person.fill", label: "You")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 18)

            Button(action: onQuickLog) {
                ZStack {
                    Circle().fill(Theme.Palette.ink).frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plainTappable)
            .offset(y: -22)
        }
    }

    private func tabItem(_ id: MainTab, icon: String, label: String) -> some View {
        Button(action: { withAnimation(Theme.Motion.snap) { selected = id } }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(AppFont.text(10, weight: .semibold))
                    .tracking(0.4)
                    .textCase(.uppercase)
            }
            .foregroundColor(selected == id ? Theme.Palette.gold : Theme.Palette.inkSoft)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plainTappable)
    }
}

/// Detect a shake gesture, used as a dev shortcut for Quick Log.
private struct ShakeDetector: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let vc = ShakeViewController()
        vc.onShake = onShake
        return vc
    }
    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

private final class ShakeViewController: UIViewController {
    var onShake: (() -> Void)?
    override var canBecomeFirstResponder: Bool { true }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { onShake?() }
    }
}

extension View {
    func onShake(_ action: @escaping () -> Void) -> some View {
        self.background(ShakeDetector(onShake: action))
    }
}
