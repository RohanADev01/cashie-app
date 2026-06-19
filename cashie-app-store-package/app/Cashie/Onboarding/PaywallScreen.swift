import SwiftUI

/// Used by `ContrastScreen` to toggle a before/after pill. Kept here for source
/// compatibility.
enum PaywallStage: Hashable { case without, with }

// MARK: - Rescue funnel

/// How far the exit-intent rescue funnel has progressed for this user.
/// Persisted so the funnel survives relaunches: full price first, the mid
/// offer once they signal leaving, the deep offer once on a later open, then
/// locked at full price forever.
private enum RescueStage: String {
    case none
    case midDeclined = "mid_declined"
    case deepDeclined = "deep_declined"
}
private let rescueStageKey = "paywallRescueStage"
private let paywallViewCountKey = "paywallViewCount"

private func loadRescueStage() -> RescueStage {
    RescueStage(rawValue: UserDefaults.standard.string(forKey: rescueStageKey) ?? "") ?? .none
}
private func saveRescueStage(_ stage: RescueStage) {
    UserDefaults.standard.set(stage.rawValue, forKey: rescueStageKey)
}

/// The two exit-intent rescue tiers. Full price ($79.99) is always shown first;
/// these only appear after the user signals they're leaving. Mid first, deep
/// once on a later open, then the price locks at full forever.
///
/// Marketing prices are fixed USD for everyone; Apple charges the localized
/// amount at checkout (same convention as the base plan cards).
enum RescueTier: String, Identifiable {
    case mid
    case deep

    var id: String { rawValue }

    var offering: Offering {
        switch self {
        case .mid:
            return Offering(
                id: "cashie_pro_yearly_mid",
                displayTitle: "Cashie Pro · Yearly",
                displayPrice: "$35.88",
                billingPeriod: "year",
                monthlyEquivalent: "$2.99 / mo",
                oldPrice: "$79.99"
            )
        case .deep:
            return Offering(
                id: "cashie_pro_yearly_special",
                displayTitle: "Cashie Pro · Yearly",
                displayPrice: "$23.88",
                billingPeriod: "year",
                monthlyEquivalent: "$1.99 / mo",
                oldPrice: "$79.99"
            )
        }
    }

    var priceUSD: String { self == .mid ? "35.88" : "23.88" }
    /// vs the $9.99/mo run-rate, for the headline save badge.
    var savePercent: String { self == .mid ? "70%" : "80%" }
    var badge: String { self == .mid ? "ONE-TIME OFFER" : "FINAL OFFER" }
    var badgeIcon: String { self == .mid ? "gift.fill" : "exclamationmark.circle.fill" }
    var headlineRaw: String {
        self == .mid ? "A gift: <em>70% off.</em>" : "Last chance: <em>80% off.</em>"
    }
    var subhead: String {
        self == .mid
            ? "A one-time welcome offer, just for you. Less than a coffee a month, locked in for a year."
            : "The lowest Cashie ever goes, and you won't see it again. Less than a soda a month."
    }
    var ctaTitle: String { self == .mid ? "Claim 70% off" : "Claim 80% off" }
    var surface: String { self == .mid ? "rescue_mid" : "rescue_deep" }
}

struct PaywallScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState
    @Environment(\.scenePhase) private var scenePhase

    @State private var offerings: [Offering] = []
    @State private var selectedID: String = "cashie_pro_yearly"
    @State private var purchasing = false

    @State private var bob: CGFloat = 0
    @State private var tilt: Double = -3

    @State private var rescueStage: RescueStage = loadRescueStage()
    @State private var activeRescue: RescueTier? = nil
    /// Becomes true only after a genuine background, so we don't mistake the
    /// launch-time `.inactive → .active` transition for a return-from-leaving.
    @State private var hasBackgrounded = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 360, intensity: 0.08)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    mascot
                    headlineBlock
                    trustBadges
                    plansBlock
                    ctaBlock
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 28)
            }
        }
        .task { await loadOfferings() }
        .onAppear {
            UserDefaults.standard.set(true, forKey: "hasReachedPaywall")
            trackPaywallViewed()
            handleDevAffordance()
            // Cold-launch continuation: if the mid offer was already declined in
            // a previous session, surface the final (deep) offer once on this
            // open. Never auto-shows anything to a first-time viewer.
            if rescueStage == .midDeclined { scheduleAutoRescue(.deep, trigger: "relaunch") }
        }
        .onChange(of: scenePhase) { phase in
            // Backgrounding a hard paywall is the genuine "I'm leaving" signal.
            // On return (and only after a real background, not the launch-time
            // .inactive→.active blip), surface the next rescue tier once.
            if phase == .background {
                hasBackgrounded = true
            } else if phase == .active, hasBackgrounded {
                hasBackgrounded = false
                maybeRescueOnReturn()
            }
        }
        .fullScreenCover(item: $activeRescue) { tier in
            RescueModal(
                tier: tier,
                onClose: { declineRescue(tier) },
                onPurchase: {
                    completePurchase(surface: tier.surface, plan: tier.offering.id, priceUSD: tier.priceUSD)
                }
            )
            .environmentObject(container)
        }
    }

    // MARK: Loading

    private func loadOfferings() async {
        offerings = (try? await container.subscriptions.loadOfferings()) ?? []
        // Always anchor on yearly (the @State default). Never auto-select
        // monthly — it's the decoy that makes annual look smart, not the
        // recommended plan. If yearly somehow isn't loaded we keep the default.
        if offerings.contains(where: { $0.id == "cashie_pro_yearly" }) {
            selectedID = "cashie_pro_yearly"
        }
    }

    // MARK: Exit-intent / rescue funnel

    /// The "Maybe later" tap (only shown while `rescueStage == .none`).
    private func handleExitIntent() {
        guard rescueStage == .none, activeRescue == nil, !purchasing else { return }
        container.track("paywall_dismissed",
                        ["placement": "onboarding", "variant": "two_tier", "saw_rescue": "true"])
        presentRescue(.mid, trigger: "dismiss")
    }

    /// Surfaces a rescue tier on return-from-background. Never shows the mid
    /// offer to someone who hasn't engaged unless they actually left and came
    /// back; never shows the deep offer until the mid offer was declined.
    private func maybeRescueOnReturn() {
        guard activeRescue == nil, !purchasing, !UserDefaults.standard.bool(forKey: "isSubscribed") else { return }
        switch rescueStage {
        case .none:        scheduleAutoRescue(.mid, trigger: "reopen")
        case .midDeclined: scheduleAutoRescue(.deep, trigger: "reopen")
        case .deepDeclined: break
        }
    }

    private func scheduleAutoRescue(_ tier: RescueTier, trigger: String) {
        guard activeRescue == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard activeRescue == nil, !purchasing,
                  !UserDefaults.standard.bool(forKey: "isSubscribed") else { return }
            // Re-confirm the stage still matches the tier we intended.
            let ok = (tier == .mid && rescueStage == .none)
                  || (tier == .deep && rescueStage == .midDeclined)
            guard ok else { return }
            presentRescue(tier, trigger: trigger)
        }
    }

    private func presentRescue(_ tier: RescueTier, trigger: String) {
        container.track("rescue_offer_viewed",
                        ["tier": tier.rawValue, "price_usd": tier.priceUSD,
                         "trigger": trigger, "variant": "two_tier"])
        withAnimation(Theme.Motion.smooth) { activeRescue = tier }
    }

    private func declineRescue(_ tier: RescueTier) {
        container.track("rescue_offer_dismissed",
                        ["tier": tier.rawValue, "price_usd": tier.priceUSD])
        rescueStage = (tier == .mid) ? .midDeclined : .deepDeclined
        saveRescueStage(rescueStage)
        activeRescue = nil
    }

    // MARK: Mascot (animated)

    private var mascot: some View {
        Image("Mascot")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 100)
            .rotationEffect(.degrees(tilt))
            .offset(y: bob)
            .shadow(color: Theme.Palette.gold.opacity(0.30), radius: 22, x: 0, y: 14)
            .padding(.top, 2)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = -8 }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { tilt = 3 }
            }
    }

    // MARK: Headline

    private var headlineBlock: some View {
        VStack(spacing: 8) {
            EmphasizedHeadline(
                raw: "Less stress. <em>More life.</em>",
                font: AppFont.display(36, weight: .heavy)
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            Text("No more “where did it go?”. No more midnight bank-app dread. Just a number you trust, and the life that fits in it.")
                .font(AppFont.text(13.5))
                .foregroundColor(Theme.Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
        }
    }

    // MARK: Trust hero

    private var trustBadges: some View {
        VStack(spacing: 14) {
            starFan
            laurelHeadline
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var laurelHeadline: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "laurel.leading")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(Theme.Palette.gold)
                .shadow(color: Theme.Palette.gold.opacity(0.55), radius: 10, x: 0, y: 0)
                .shadow(color: Theme.Palette.gold.opacity(0.30), radius: 22, x: 0, y: 0)
            EmphasizedHeadline(
                raw: "Join <em>100k+</em> others",
                font: AppFont.display(22, weight: .heavy),
                emColor: Theme.Palette.gold
            )
            .shadow(color: Theme.Palette.gold.opacity(0.20), radius: 8, x: 0, y: 0)
            Image(systemName: "laurel.trailing")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(Theme.Palette.gold)
                .shadow(color: Theme.Palette.gold.opacity(0.55), radius: 10, x: 0, y: 0)
                .shadow(color: Theme.Palette.gold.opacity(0.30), radius: 22, x: 0, y: 0)
        }
    }

    private var starFan: some View {
        HStack(spacing: 4) {
            star(rotation: -10, lift: 2, size: 18)
            star(rotation: -5, lift: 0, size: 20)
            star(rotation: 0, lift: -2, size: 22)
            star(rotation: 5, lift: 0, size: 20)
            star(rotation: 10, lift: 2, size: 18)
        }
    }

    private static let starYellow = Color(hex: 0xF7C636)

    private func star(rotation: Double, lift: CGFloat, size: CGFloat) -> some View {
        Image(systemName: "star.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundColor(Self.starYellow)
            .rotationEffect(.degrees(rotation))
            .offset(y: lift)
            .shadow(color: Self.starYellow.opacity(0.65), radius: 6, x: 0, y: 0)
            .shadow(color: Self.starYellow.opacity(0.35), radius: 16, x: 0, y: 0)
    }

    // MARK: Plans (always full price — the rescue offers live in RescueModal)

    private var plansBlock: some View {
        HStack(spacing: 12) {
            PlanCard(
                title: "Monthly",
                bigPrice: "$9.99",
                cadence: "per month",
                footnote: "billed monthly",
                badge: nil,
                oldPrice: nil,
                isSelected: selectedID == "cashie_pro_monthly"
            ) { selectPlan("cashie_pro_monthly") }

            PlanCard(
                title: "Yearly",
                bigPrice: "$79.99",
                cadence: "per year",
                footnote: "≈ $6.67 / mo",
                badge: "SAVE 33%",
                oldPrice: nil,
                isSelected: selectedID == "cashie_pro_yearly"
            ) { selectPlan("cashie_pro_yearly") }
        }
    }

    private func selectPlan(_ id: String) {
        selectedID = id
        container.track("plan_selected",
                        ["plan": id, "price_usd": id == "cashie_pro_monthly" ? "9.99" : "79.99"])
    }

    // MARK: CTA

    private var ctaBlock: some View {
        VStack(spacing: 10) {
            PrimaryButton(
                title: purchasing ? "Subscribing…" : "Let's do this",
                background: Theme.Palette.green
            ) { handleStart() }
            .disabled(purchasing)

            // Price + auto-renewal disclosure. Required on the subscribing
            // screen (App Store Guideline 3.1.2). No free trial.
            Text(disclosureText)
                .font(AppFont.text(11, weight: .medium))
                .foregroundColor(Theme.Palette.inkMute)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 10, weight: .semibold))
                Text("Cancel anytime · encrypted")
            }
            .font(AppFont.text(11, weight: .medium))
            .foregroundColor(Theme.Palette.inkMute)

            // Exit-intent capture. On a hard paywall this surfaces the one-time
            // rescue offer rather than letting the user past — it's hidden once
            // the mid offer has been seen (the deep offer arrives on next open).
            if rescueStage == .none {
                Button(action: handleExitIntent) {
                    Text("Maybe later")
                        .font(AppFont.text(12, weight: .semibold))
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                .buttonStyle(.plainTappable)
                .padding(.top, 2)
            }

            Button(action: handleRestore) {
                Text("Restore purchase")
                    .font(AppFont.text(11, weight: .semibold))
                    .underline()
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            .buttonStyle(.plainTappable)

            HStack(spacing: 8) {
                Button { openExternal(Config.termsOfUseURL) } label: {
                    Text("Terms of Use")
                        .font(AppFont.text(11, weight: .semibold))
                        .underline()
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                .buttonStyle(.plainTappable)
                Text("·")
                    .font(AppFont.text(11, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkMute)
                Button { openExternal(Config.privacyPolicyURL) } label: {
                    Text("Privacy Policy")
                        .font(AppFont.text(11, weight: .semibold))
                        .underline()
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                .buttonStyle(.plainTappable)
            }
            .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    /// Required disclosure. Prices shown in USD; Apple charges the localized
    /// amount at checkout. No trial.
    private var disclosureText: String {
        let (price, period) = selectedID == "cashie_pro_monthly" ? ("$9.99", "month") : ("$79.99", "year")
        return "\(price)/\(period), shown in USD. You're billed in your local currency. Auto-renews until cancelled, cancel anytime."
    }

    private func openExternal(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Purchase

    private func handleStart() {
        guard !purchasing else { return }
        purchasing = true
        let plan = selectedID
        let price = plan == "cashie_pro_monthly" ? "9.99" : "79.99"
        container.track("checkout_started", ["plan": plan, "price_usd": price, "surface": "paywall"])
        // Fallback when offerings haven't loaded yet: StoreKitService resolves
        // the real product by id internally (and DEBUG-succeeds on simctl).
        let offering = offerings.first(where: { $0.id == plan }) ?? Offering(
            id: plan,
            displayTitle: "Cashie Pro",
            displayPrice: "",
            billingPeriod: plan == "cashie_pro_monthly" ? "month" : "year",
            monthlyEquivalent: ""
        )
        Task {
            let result = (try? await container.subscriptions.purchase(offering)) ?? .cancelled
            await MainActor.run {
                purchasing = false
                if result == .success {
                    completePurchase(surface: "paywall", plan: plan, priceUSD: price)
                } else {
                    container.track("checkout_abandoned",
                                    ["plan": plan, "surface": "paywall", "reason": "cancelled"])
                }
            }
        }
    }

    private func completePurchase(surface: String, plan: String, priceUSD: String) {
        container.track("purchase_completed",
                        ["plan": plan, "price_usd": priceUSD, "surface": surface,
                         "billing_period": plan.contains("monthly") ? "month" : "year"])
        markSubscribed()
        container.advanceOnboarding(to: .welcomeIn)
    }

    private func markSubscribed() {
        UserDefaults.standard.set(true, forKey: "isSubscribed")
        UserDefaults.standard.removeObject(forKey: "hasReachedPaywall")
    }

    private func handleRestore() {
        container.track("restore_tapped", ["surface": "paywall"])
        Task {
            if let ok = try? await container.subscriptions.restore(), ok {
                await MainActor.run {
                    container.track("restore_succeeded", ["surface": "paywall"])
                    markSubscribed()
                    container.advanceOnboarding(to: .welcomeIn)
                }
            }
        }
    }

    // MARK: Analytics + dev

    private func trackPaywallViewed() {
        let n = UserDefaults.standard.integer(forKey: paywallViewCountKey) + 1
        UserDefaults.standard.set(n, forKey: paywallViewCountKey)
        container.track("paywall_viewed",
                        ["placement": "onboarding", "variant": "two_tier",
                         "default_plan": selectedID, "view_index": String(n)])
    }

    private func handleDevAffordance() {
        #if DEBUG
        // Dev: `-rescue reset|mid|deep` to reset or preview a rescue tier.
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-rescue"), args.indices.contains(i + 1) else { return }
        switch args[i + 1] {
        case "reset":
            rescueStage = .none; saveRescueStage(.none)
        case "mid":
            rescueStage = .none; saveRescueStage(.none)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { presentRescue(.mid, trigger: "dev") }
        case "deep":
            rescueStage = .midDeclined; saveRescueStage(.midDeclined)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { presentRescue(.deep, trigger: "dev") }
        default:
            break
        }
        #endif
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let title: String
    let bigPrice: String
    let cadence: String
    let footnote: String
    let badge: String?
    let oldPrice: String?
    let isSelected: Bool
    var accent: Color = Theme.Palette.green
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppFont.text(12, weight: .semibold))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundColor(Theme.Palette.inkSoft)
                        if let badge {
                            Text(badge)
                                .font(AppFont.text(9, weight: .heavy))
                                .tracking(0.8)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 4).fill(accent))
                        }
                    }
                    Spacer(minLength: 0)
                    tickbox
                }

                Spacer(minLength: 6)

                if let oldPrice {
                    Text(oldPrice)
                        .font(AppFont.text(13, weight: .semibold))
                        .strikethrough(true, color: Theme.Palette.inkMute)
                        .foregroundColor(Theme.Palette.inkMute)
                        .lineLimit(1)
                }

                Text(bigPrice)
                    .font(AppFont.display(34, weight: .heavy))
                    .foregroundColor(Theme.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(cadence)
                    .font(AppFont.text(11, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkSoft)

                Text(footnote)
                    .font(AppFont.text(10))
                    .foregroundColor(Theme.Palette.inkMute)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .frame(minHeight: 168)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accent.opacity(0.06) : Theme.Palette.bgCream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? accent : Theme.Palette.line,
                            lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .animation(Theme.Motion.snap, value: isSelected)
        }
        .buttonStyle(.plainTappable)
    }

    private var tickbox: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? accent : Theme.Palette.line, lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle().fill(accent).frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
            }
        }
        .animation(Theme.Motion.snap, value: isSelected)
    }
}

// MARK: - Exit-intent rescue modal

/// One screen, two tiers. Shown only at exit-intent (never auto-popped to a
/// fresh viewer). No live countdown — the urgency is the genuinely one-time
/// framing, and once dismissed the stage advances so the price actually
/// reverts (no fake restarting timer).
struct RescueModal: View {
    let tier: RescueTier
    let onClose: () -> Void
    let onPurchase: () -> Void

    @EnvironmentObject var container: AppContainer
    @State private var bob: CGFloat = 0
    @State private var tilt: Double = -3
    @State private var purchasing = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack {
                Theme.Palette.green.opacity(0.10)
                    .frame(height: 260)
                    .blur(radius: 70)
                Spacer()
            }
            .ignoresSafeArea()

            ConfettiBackground(style: .celebration)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                closeBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        mascot
                        header
                        offerCard
                        cta
                        disclosure
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)
                }
            }
        }
        .interactiveDismissDisabled(true)
    }

    private var closeBar: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.Palette.bgCream))
                    .overlay(Circle().stroke(Theme.Palette.line, lineWidth: 1))
            }
            .buttonStyle(.plainTappable)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var mascot: some View {
        Image("Mascot")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: 110, height: 110)
            .rotationEffect(.degrees(tilt))
            .offset(y: bob)
            .shadow(color: Theme.Palette.gold.opacity(0.3), radius: 22, x: 0, y: 14)
            .padding(.top, 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = -8 }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { tilt = 3 }
            }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: tier.badgeIcon)
                Text(tier.badge)
            }
            .font(AppFont.text(10, weight: .heavy))
            .tracking(1.5)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.Palette.green))

            EmphasizedHeadline(
                raw: tier.headlineRaw,
                font: AppFont.display(40, weight: .heavy),
                emColor: Theme.Palette.green
            )
            .multilineTextAlignment(.center)
            .padding(.top, 2)

            Text(tier.subhead)
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
        }
    }

    private var offerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YEARLY")
                    .font(AppFont.text(11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("SAVE \(tier.savePercent)")
                    .font(AppFont.text(10, weight: .heavy))
                    .tracking(1)
                    .foregroundColor(Theme.Palette.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white))
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(tier.offering.displayPrice)
                    .font(AppFont.display(58, weight: .heavy))
                    .foregroundColor(.white)
                Text("/year")
                    .font(AppFont.text(15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                Text("$79.99")
                    .font(AppFont.text(15, weight: .semibold))
                    .strikethrough(true, color: .white.opacity(0.7))
                    .foregroundColor(.white.opacity(0.7))
                Text("normally")
                    .font(AppFont.text(12))
                    .foregroundColor(.white.opacity(0.6))
            }

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("THAT'S")
                    .font(AppFont.text(9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(tier.offering.monthlyEquivalent) (\(tier.savePercent) off monthly)")
                    .font(AppFont.text(15, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Theme.Palette.green, Color(hex: 0x025A38)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Theme.Palette.green.opacity(0.3), radius: 22, x: 0, y: 12)
    }

    private var cta: some View {
        PrimaryButton(
            title: purchasing ? "Subscribing…" : tier.ctaTitle,
            background: Theme.Palette.green
        ) {
            guard !purchasing else { return }
            runPurchase()
        }
        .disabled(purchasing)
    }

    /// Required price + auto-renew + terms disclosure (Guideline 3.1.2): this
    /// modal is itself a subscribing surface.
    private var disclosure: some View {
        VStack(spacing: 6) {
            Text("\(tier.offering.displayPrice)/year, shown in USD. You're billed in your local currency. Auto-renews until cancelled, cancel anytime.")
                .font(AppFont.text(10, weight: .medium))
                .foregroundColor(Theme.Palette.inkMute)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button { openExternal(Config.termsOfUseURL) } label: {
                    Text("Terms of Use")
                        .font(AppFont.text(10, weight: .semibold))
                        .underline()
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                .buttonStyle(.plainTappable)
                Text("·")
                    .font(AppFont.text(10, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkMute)
                Button { openExternal(Config.privacyPolicyURL) } label: {
                    Text("Privacy Policy")
                        .font(AppFont.text(10, weight: .semibold))
                        .underline()
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                .buttonStyle(.plainTappable)
            }
        }
        .padding(.top, 2)
    }

    private func openExternal(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    private func runPurchase() {
        purchasing = true
        container.track("checkout_started",
                        ["plan": tier.offering.id, "price_usd": tier.priceUSD, "surface": tier.surface])
        Task {
            let result = (try? await container.subscriptions.purchase(tier.offering)) ?? .cancelled
            await MainActor.run {
                purchasing = false
                if result == .success {
                    onPurchase()
                } else {
                    container.track("checkout_abandoned",
                                    ["plan": tier.offering.id, "surface": tier.surface, "reason": "cancelled"])
                }
            }
        }
    }
}
