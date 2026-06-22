import SwiftUI
import StoreKit

struct YouTab: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.requestReview) private var requestReview
    @State private var showWrapped = false
    @State private var showArchetype = false
    @State private var showQuickLogSetup = false
    @State private var showReminders = false
    @State private var showPrivacy = false
    @State private var showSubscription = false
    @State private var showHelp = false
    @State private var showStreak = false
    @State private var showCurrency = false
    @State private var showBills = false
    @State private var showIncome = false

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    profileHeader
                    weeklyWrapCard
                    Button { showStreak = true } label: { streakCard }
                        .buttonStyle(.plainTappable)
                    archetypeCard
                    statGrid
                    DividerLabel(text: "Settings", numeral: "I.")
                        .padding(.top, 8)
                    rateCard
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
                // Fall back to representative scores when the quiz hasn't run yet,
                // so the impulse/planning/etc. stats card always shows.
                traits: container.user.traits.isEmpty ? Trait.defaults : container.user.traits
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
        .sheet(isPresented: $showBills) {
            BillsListSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showIncome) {
            IncomeSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacySheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
            // A dismissible duplicate of the onboarding paywall, so users can
            // review plans and switch between monthly/yearly from here.
            SubscriptionPaywallSheet()
                .presentationDetents([.large])
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
            if args.contains("-openSubscription") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showSubscription = true }
            }
            if args.contains("-openQuickLogSetup") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showQuickLogSetup = true }
            }
            if args.contains("-openArchetype") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showArchetype = true }
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

    /// Subscription row: opens the dismissible paywall for everyone. Free users
    /// see the Pro plans; existing subscribers use the same screen to switch
    /// between the monthly and yearly plans.
    private func handleSubscriptionTap() {
        showSubscription = true
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
                    ? "Hey, <em>\(container.user.firstName)</em>"
                    : "<em>Hey there</em>",
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
                // Matches the saving + streak cards: a flat brand-green circle
                // with the archetype emoji, same 48pt size.
                ZStack {
                    Circle()
                        .fill(Theme.Palette.gold)
                        .frame(width: 48, height: 48)
                    Text(container.user.archetype.emoji)
                        .font(.system(size: 24))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.user.archetype.name)
                        .font(AppFont.text(17, weight: .bold))
                        .foregroundColor(Theme.Palette.ink)
                    Text("\(container.user.archetype.matchPercent)% match · tap for the breakdown")
                        .font(AppFont.text(12, weight: .medium))
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .softCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
    }

    // MARK: - Weekly wrap card (entry point to WrappedSheet)

    private var weeklyWrapCard: some View {
        Button(action: { showWrapped = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.gold)
                        .frame(width: 48, height: 48)
                    TwinkleIcon()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(weeklyHeadline)
                        .font(AppFont.text(17, weight: .bold))
                        .foregroundColor(Theme.Palette.ink)
                    Text(weeklySub)
                        .font(AppFont.text(12, weight: .medium))
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .softCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
    }

    // MARK: - "Saving this month" — mirrors AppContainer.safeToSpend (the Today
    // hero) exactly, so this card never contradicts it. Positive = under the
    // monthly budget, negative = over.

    private var weeklyHeadline: String {
        let s = container.safeToSpend
        if s > 0 { return "Saving \(Money.format(s, cents: true)) this month" }
        if s < 0 { return "Over by \(Money.format(-s, cents: true)) this month" }
        return "Right at your budget"
    }

    private var weeklySub: String {
        container.safeToSpend > 0
            ? "Under your monthly budget · tap for the wrap"
            : "Tap to see where the month went"
    }

    // MARK: - Streak (matches the fire-gradient card on the dashboard)

    private var streakCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.streak)
                    .frame(width: 48, height: 48)
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(streakHeadline)
                    .font(AppFont.text(17, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                Text(streakSubtitle)
                    .font(AppFont.text(12, weight: .medium))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.Palette.inkMute)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .softCard()
        .contentShape(Rectangle())
    }

    // MARK: - 2x2 stats

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            stat("Total saved", Money.format(container.derivedTotalSaved))
            stat("With Cashie", "\(container.derivedMonthsActive) mo.")
            stat("Badges earned", "\(container.earnedBadgeCount)")
            stat("Goals active", "\(container.goals.count)")
        }
    }

    // MARK: - Streak copy

    /// Caption beside the big streak number. The number itself carries the
    /// count, so this is just the label (or the empty state).
    private var streakHeadline: String {
        container.loggedStreak == 0 ? "No streak yet" : "\(container.loggedStreak) day streak"
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
        .padding(18)
        .softCard()
    }

    // MARK: - Rate prompt

    private var rateCard: some View {
        Button(action: rateOnAppStore) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Enjoying Cashie?")
                        .font(AppFont.text(15, weight: .bold))
                        .foregroundColor(Theme.Palette.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.Palette.inkMute)
                }
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: 0xFFC83D))
                    }
                }
                Text("Tap to rate us five stars on the App Store.")
                    .font(AppFont.text(12, weight: .medium))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
    }

    /// Opens the App Store write-review page when we have the numeric app id;
    /// before launch (id not set yet) it falls back to the in-app review prompt.
    private func rateOnAppStore() {
        container.track("rate_tapped")
        let id = Config.appStoreID
        if !id.isEmpty,
           let url = URL(string: "https://apps.apple.com/app/id\(id)?action=write-review") {
            UIApplication.shared.open(url)
        } else {
            requestReview()
        }
    }

    // MARK: - Settings list (SF Symbols, monochrome ink)

    private var settingsList: some View {
        VStack(spacing: 0) {
            row(systemImage: "hand.tap.fill",
                label: container.user.quickLogSetup
                    ? "Quick Log · re-run setup"
                    : "Set up Quick Log",
                accent: Theme.Palette.gold,
                action: { showQuickLogSetup = true })
            row(systemImage: "doc.text",                  // NEW
                label: "Bills",
                action: { showBills = true })
            row(systemImage: "banknote",                  // NEW
                label: "Income",
                action: { showIncome = true })
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
        .padding(.vertical, 4)
        .softCard()
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

/// A gently flickering flame for the streak card: a soft scale + sway loop so
/// the streak feels alive rather than a static glyph.
private struct FlameIcon: View {
    var size: CGFloat = 22
    @State private var animate = false
    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundColor(Theme.Palette.streak)
            .scaleEffect(animate ? 1.1 : 0.95)
            .rotationEffect(.degrees(animate ? 3 : -3), anchor: .bottom)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}

/// A static sparkle for the saving card.
private struct TwinkleIcon: View {
    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
    }
}

/// Shared section divider label used by the You tab.
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
