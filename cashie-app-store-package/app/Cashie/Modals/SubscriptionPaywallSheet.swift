import SwiftUI

/// A dismissible duplicate of the onboarding `PaywallScreen`, presented from the
/// You tab's "Subscription · Cashie Pro" row. It's the same single, honest
/// paywall (monthly + yearly cards, 75%-off yearly, the same purchase / restore
/// / Terms / Privacy), so an existing subscriber can switch between monthly and
/// yearly exactly the way they'd pick a plan in onboarding.
///
/// Two differences from the onboarding screen:
///   1. a close (X) button, top-right, since this is a modal the user opened;
///   2. completing a purchase (or a successful restore) marks the user Pro,
///      refreshes the live entitlement and dismisses — it does NOT advance the
///      onboarding flow (the user is already in the app).
///
/// Kept as a standalone copy on purpose: the onboarding paywall is launch
/// critical, so this avoids refactoring it. The `PlanCard` component is shared.
/// If you change pricing or copy on `PaywallScreen`, mirror it here.
struct SubscriptionPaywallSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var offerings: [Offering] = []
    @State private var selectedID: String = "cashie_pro_yearly_v2"
    @State private var purchasing = false

    @State private var bob: CGFloat = 0
    @State private var tilt: Double = -3

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 360, intensity: 0.08)

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
        .overlay(alignment: .topTrailing) { closeButton }
        .task { await loadOfferings() }
        .onAppear {
            container.track("paywall_viewed",
                            ["placement": "settings", "variant": "single_offer",
                             "default_plan": selectedID])
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.Palette.bgCream))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plainTappable)
        .padding(.top, 14)
        .padding(.trailing, 18)
    }

    // MARK: Loading

    private func loadOfferings() async {
        offerings = (try? await container.subscriptions.loadOfferings()) ?? []
        // Always anchor on yearly (the recommended plan), matching onboarding.
        if offerings.contains(where: { $0.id == "cashie_pro_yearly_v2" }) {
            selectedID = "cashie_pro_yearly_v2"
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

    // MARK: Plans (shared PlanCard with the onboarding paywall)

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
                bigPrice: "$29.99",
                cadence: "per year",
                footnote: "≈ $2.49/mo · vs $9.99 monthly",
                badge: "SAVE 75%",
                oldPrice: "$119.88",
                isSelected: selectedID == "cashie_pro_yearly_v2"
            ) { selectPlan("cashie_pro_yearly_v2") }
        }
    }

    private func selectPlan(_ id: String) {
        selectedID = id
        container.track("plan_selected",
                        ["plan": id, "price_usd": id == "cashie_pro_monthly" ? "9.99" : "29.99",
                         "surface": "settings"])
    }

    // MARK: CTA

    private var ctaBlock: some View {
        VStack(spacing: 10) {
            PrimaryButton(
                title: purchasing ? "Subscribing…" : "Let's do this",
                background: Theme.Palette.green
            ) { handleStart() }
            .disabled(purchasing)

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
        let (price, period) = selectedID == "cashie_pro_monthly" ? ("$9.99", "month") : ("$29.99", "year")
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
        let price = plan == "cashie_pro_monthly" ? "9.99" : "29.99"
        container.track("checkout_started", ["plan": plan, "price_usd": price, "surface": "settings"])
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
                    completePurchase(plan: plan, priceUSD: price)
                } else {
                    container.track("checkout_abandoned",
                                    ["plan": plan, "surface": "settings", "reason": "cancelled"])
                }
            }
        }
    }

    private func completePurchase(plan: String, priceUSD: String) {
        container.track("purchase_completed",
                        ["plan": plan, "price_usd": priceUSD, "surface": "settings",
                         "billing_period": plan.contains("monthly") ? "month" : "year"])
        markSubscribed()
        // Revalidate against StoreKit so the cached entitlement matches, then close.
        Task { _ = try? await container.subscriptions.refreshSubscriptionStatus() }
        dismiss()
    }

    private func markSubscribed() {
        UserDefaults.standard.set(true, forKey: "isSubscribed")
        UserDefaults.standard.removeObject(forKey: "hasReachedPaywall")
    }

    private func handleRestore() {
        container.track("restore_tapped", ["surface": "settings"])
        Task {
            if let ok = try? await container.subscriptions.restore(), ok {
                await MainActor.run {
                    container.track("restore_succeeded", ["surface": "settings"])
                    markSubscribed()
                    dismiss()
                }
            }
        }
    }
}
