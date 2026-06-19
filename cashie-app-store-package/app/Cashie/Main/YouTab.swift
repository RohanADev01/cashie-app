import SwiftUI

struct YouTab: View {
    @EnvironmentObject var container: AppContainer
    @State private var showWrapped = false
    @State private var showArchetype = false
    @State private var showQuickLogSetup = false
    @State private var showReminders = false
    @State private var showPrivacy = false
    @State private var showSubscription = false
    @State private var showHelp = false
    @State private var showBadges = false
    @State private var showStreak = false
    @State private var showCurrency = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    profileHeader
                    weeklyWrapCard
                    Button { showStreak = true } label: { streakCard }
                        .buttonStyle(.plainTappable)
                    archetypeCard
                    statGrid
                    DividerLabel(text: "Settings", numeral: "I.")
                        .padding(.top, 8)
                    settingsList
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showWrapped) {
            WrappedSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showArchetype) {
            ArchetypeSheet(
                archetype: container.user.archetype,
                traits: container.user.traits
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQuickLogSetup) {
            QuickLogSetupSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReminders) {
            ReminderSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacySheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showBadges) {
            BadgesSheet()
        }
        .fullScreenCover(isPresented: $showStreak) {
            StreakCalendarSheet()
        }
        .sheet(isPresented: $showCurrency) {
            CurrencyPickerSheet(
                title: "Currency",
                subtitle: "Show every amount in this currency.",
                cta: "Done",
                initialCode: Money.currencyCode
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Reach Cashie", isPresented: $showHelp) {
            Button("Email support") { openHelp() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Send a note to cashieapp@outlook.com and a real person will get back.")
        }
        .onAppear {
            // Dev affordance: jump straight into a sheet for screenshots. Fires
            // ONCE per launch. YouTab is rebuilt every time the user returns to
            // the You tab, so without the static guard these would reopen on
            // every You-tab tap.
            guard !Self.didRunLaunchOpens else { return }
            Self.didRunLaunchOpens = true
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-openStreak") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showStreak = true }
            }
            if args.contains("-openWrapped") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showWrapped = true }
            }
        }
    }

    /// One-shot guard for the `-open*` launch-arg screenshot helpers, static so
    /// it survives YouTab being rebuilt on tab switches (see TodayTab).
    private static var didRunLaunchOpens = false

    private func openHelp() {
        guard let url = URL(string: "mailto:cashieapp@outlook.com?subject=Cashie%20support") else { return }
        UIApplication.shared.open(url)
    }

    /// Subscription row: paying users have nothing to choose here, so we
    /// route them straight to Today instead of putting up a paywall-style
    /// sheet. Free users still get the full subscription sheet so they can
    /// see the Pro plans.
    private func handleSubscriptionTap() {
        if container.subscriptions.isSubscribed {
            container.mainTab = .today
        } else {
            showSubscription = true
        }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your profile")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            EmphasizedHeadline(
                raw: container.user.hasName
                    ? "Hey, <em>\(container.user.firstName).</em>"
                    : "<em>Hey there.</em>",
                font: AppFont.display(36, weight: .bold),
                emColor: Theme.Palette.gold
            )
            .padding(.top, 4)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Archetype card (tap to revisit the reveal)

    private var archetypeCard: some View {
        Button(action: { showArchetype = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.goldPastel)
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(Theme.Palette.gold.opacity(0.25), lineWidth: 1))
                    Text(container.user.archetype.emoji)
                        .font(.system(size: 24))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.user.archetype.name)
                        .font(AppFont.text(17, weight: .semibold))
                        .foregroundColor(Theme.Palette.ink)
                    Text("\(container.user.archetype.matchPercent)% match · tap for the breakdown")
                        .font(AppFont.text(12, weight: .medium))
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.Palette.gold.opacity(0.25), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
    }

    // MARK: - Weekly wrap card (entry point to WrappedSheet)

    private var weeklyWrapCard: some View {
        Button(action: { showWrapped = true }) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: 0x1FCC83),
                        Color(hex: 0x04BA74),
                        Color(hex: 0x036141),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(colors: [.white.opacity(0.28), .clear],
                               center: .topTrailing, startRadius: 4, endRadius: 220)
                RadialGradient(colors: [.black.opacity(0.14), .clear],
                               center: .bottomLeading, startRadius: 4, endRadius: 200)
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.20))
                            .frame(width: 52, height: 52)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weeklyHeadline)
                            .font(AppFont.text(20, weight: .bold))
                            .foregroundColor(.white)
                        Text(weeklySub)
                            .font(AppFont.text(12, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: 0x036141).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x04BA74).opacity(0.28), radius: 8, x: 0, y: 4)
    }

    // MARK: - "Saved this week" — derived from the same weekly cap the
    // tracker on Today uses, so the two surfaces always agree. Saved means
    // "this week's prorated cap minus this week's spend, floored at zero."

    private var weeklySaved: Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekStart = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let spent = container.transactions
            .filter { $0.category != .income && $0.date >= weekStart }
            .reduce(0) { $0 + $1.amount }
        let monthCap = container.budgets.reduce(0) { $0 + $1.monthlyCap }
        let daysInMonth = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        let weeklyCap = monthCap * 7.0 / Double(daysInMonth)
        return max(0, weeklyCap - spent)
    }

    private var weeklyHeadline: String {
        if weeklySaved > 0 {
            return "Saved \(Money.format(weeklySaved, cents: weeklySaved < 100)) this week"
        }
        return "This week, wrapped"
    }

    private var weeklySub: String {
        if weeklySaved > 0 {
            return "Under your weekly cap · tap for the wrap"
        }
        return "Tap to see where the week went"
    }

    // MARK: - Streak (matches the fire-gradient card on the dashboard)

    private var streakCard: some View {
        ZStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xFF5E3A), Color(hex: 0xFF823C), Color(hex: 0xFFB24D)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(colors: [.white.opacity(0.32), .clear],
                               center: .topTrailing, startRadius: 4, endRadius: 200)
                RadialGradient(colors: [.black.opacity(0.10), .clear],
                               center: .bottomLeading, startRadius: 4, endRadius: 200)
            }
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(streakHeadline)
                        .font(AppFont.text(20, weight: .bold))
                        .foregroundColor(.white)
                    Text(streakSubtitle)
                        .font(AppFont.text(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.92))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: 0xFF5E3A).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0xFF5E3A).opacity(0.4), radius: 14, y: 6)
    }

    // MARK: - 2x2 stats

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            stat("Total saved", Money.format(container.derivedTotalSaved))
            stat("With Cashie", "\(container.derivedMonthsActive) mo.")
            stat("Badges earned", "\(container.earnedBadgeCount)")
            stat("Goals active", "\(container.goals.count)")
        }
    }

    // MARK: - Streak copy

    private var streakHeadline: String {
        let days = container.loggedStreak
        if days == 0 { return "No streak yet" }
        if days == 1 { return "1 day streak" }
        return "\(days) day streak"
    }

    private var streakSubtitle: String {
        if container.loggedStreak == 0 {
            return "Log a spend today to start your streak."
        }
        let shields = container.shieldsRemainingInWeek(of: Date())
        return "Tap to open · \(shields) shields left this week."
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppFont.text(22, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
                .monospacedDigit()
            Text(label)
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    // MARK: - Settings list (SF Symbols, monochrome ink)

    private var settingsList: some View {
        VStack(spacing: 0) {
            row(systemImage: "rosette",
                label: "Badges · \(container.earnedBadgeCount) of \(Badge.all.count)",
                accent: Theme.Palette.gold, action: { showBadges = true })
            row(systemImage: "sparkles", label: "Last week, wrapped",
                accent: Theme.Palette.gold, action: { showWrapped = true })
            row(systemImage: "hand.tap.fill",
                label: container.user.quickLogSetup
                    ? "Quick Log · re-run setup"
                    : "Set up Quick Log",
                accent: Theme.Palette.gold,
                action: { showQuickLogSetup = true })
            row(systemImage: "bell", label: "Notifications",
                action: { showReminders = true })
            row(systemImage: "dollarsign.circle",
                label: "Currency · \(Money.symbol) \(Money.currencyCode)",
                action: { showCurrency = true })
            row(systemImage: "lock.shield", label: "Privacy & data",
                action: { showPrivacy = true })
            row(systemImage: "creditcard", label: "Subscription · Cashie Pro",
                action: { handleSubscriptionTap() })
            row(systemImage: "envelope", label: "Get help",
                action: { showHelp = true }, isLast: true)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private func row(systemImage: String,
                     label: String,
                     accent: Color = Theme.Palette.ink,
                     action: @escaping () -> Void,
                     isLast: Bool = false) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accent)
                        .frame(width: 28, height: 28)
                    Text(label)
                        .font(AppFont.text(15, weight: .semibold))
                        .foregroundColor(Theme.Palette.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Palette.inkMute)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                if !isLast {
                    Divider().padding(.leading, 56)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
    }
}

/// Re-declared here because the version in TodayTab is `private`; both pages use the same divider.
private struct DividerLabel: View {
    let text: String
    let numeral: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(text)
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.ink)
                Spacer()
                Text(numeral)
                    .font(AppFont.text(11, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .padding(.bottom, 8)
            Rectangle().fill(Theme.Palette.line).frame(height: 1)
        }
        .padding(.bottom, 6)
    }
}
