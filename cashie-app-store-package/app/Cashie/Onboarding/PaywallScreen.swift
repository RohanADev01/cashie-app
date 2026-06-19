import SwiftUI

/// Used by `ContrastScreen` to toggle a before/after pill. Kept here for source
/// compatibility.
enum PaywallStage: Hashable { case without, with }

private let paywallViewCountKey = "paywallViewCount"
private let paywallCelebrationShownKey = "paywallCelebrationShown"

/// A single, honest paywall: one screen, one offer. A friendly "We'd like to
/// offer you 80% off!" line introduces the two plan cards (monthly + yearly).
/// The yearly card carries the genuine struck-through reference + "SAVE 80%".
/// There is NO second / exit-intent / pop-up offer surface — everything lives on
/// this one screen, which keeps it within App Store Guideline 5.6. Confetti
/// celebrates the first visit only.
struct PaywallScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState

    @State private var offerings: [Offering] = []
    @State private var selectedID: String = "cashie_pro_yearly"
    @State private var purchasing = false

    @State private var bob: CGFloat = 0
    @State private var tilt: Double = -3

    /// True only on the first visit to the paywall, so the confetti celebrates
    /// once and the screen is calm on every later visit.
    @State private var showCelebration = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 360, intensity: 0.08)
            // First-visit celebration. Non-interactive so it never blocks the
            // plan cards / CTA.
            if showCelebration {
                ConfettiBackground(style: .celebration)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
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
            #if DEBUG
            // Dev/QA: launch with `-offer reset` to replay the first-visit confetti.
            let devArgs = ProcessInfo.processInfo.arguments
            if let i = devArgs.firstIndex(of: "-offer"), devArgs.indices.contains(i + 1),
               devArgs[i + 1] == "reset" {
                UserDefaults.standard.removeObject(forKey: paywallCelebrationShownKey)
            }
            #endif
            // Confetti only the first time the user reaches the paywall.
            if !UserDefaults.standard.bool(forKey: paywallCelebrationShownKey) {
                showCelebration = true
                UserDefaults.standard.set(true, forKey: paywallCelebrationShownKey)
            }
            trackPaywallViewed()
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
        VStack(spacing: 10) {
            EmphasizedHeadline(
                raw: "Less stress. <em>More life.</em>",
                font: AppFont.display(36, weight: .heavy)
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            // Small, clear offer label under the headline: green pill, white text,
            // gift icon at the start.
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("We'd like to offer you 80% off!")
                    .font(AppFont.text(13, weight: .heavy))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.Palette.green))
            .shadow(color: Theme.Palette.green.opacity(0.25), radius: 10, x: 0, y: 4)
        }
    }

    // MARK: Trust hero

    private var trustBadges: some View {
        VStack(spacing: 14) {
            starFan
            laurelHeadline
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
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

    // MARK: Plans (two cards side by side — the 80% off is on the yearly card)

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

            // Yearly carries the discount inline: the struck-through $119.88 is the
            // genuine 12 x $9.99 monthly cost, so "SAVE 80%" is truthful.
            PlanCard(
                title: "Yearly",
                bigPrice: "$23.88",
                cadence: "per year",
                footnote: "≈ $1.99/mo · vs $9.99 monthly",
                badge: "SAVE 80%",
                oldPrice: "$119.88",
                isSelected: selectedID == "cashie_pro_yearly"
            ) { selectPlan("cashie_pro_yearly") }
        }
    }

    private func selectPlan(_ id: String) {
        selectedID = id
        container.track("plan_selected",
                        ["plan": id, "price_usd": id == "cashie_pro_monthly" ? "9.99" : "23.88"])
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
        let (price, period) = selectedID == "cashie_pro_monthly" ? ("$9.99", "month") : ("$23.88", "year")
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
        let price = plan == "cashie_pro_monthly" ? "9.99" : "23.88"
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

    // MARK: Analytics

    private func trackPaywallViewed() {
        let n = UserDefaults.standard.integer(forKey: paywallViewCountKey) + 1
        UserDefaults.standard.set(n, forKey: paywallViewCountKey)
        container.track("paywall_viewed",
                        ["placement": "onboarding", "variant": "single_offer",
                         "default_plan": selectedID, "view_index": String(n)])
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
