import SwiftUI

/// Surfaces the current Cashie Pro state, lets the user restore a purchase,
/// and links out to the App Store-managed subscription page.
struct SubscriptionSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    @State private var isSubscribed: Bool = false
    @State private var restoring = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                statusCard
                actions
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .task {
            isSubscribed = container.subscriptions.isSubscribed
            // Best-effort refresh so the card doesn't stay stale.
            if let live = try? await container.subscriptions.refreshSubscriptionStatus() {
                isSubscribed = live
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Subscription").font(AppFont.title2)
                Text("Cashie Pro")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6).textCase(.uppercase)
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

    private var statusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: isSubscribed ? "checkmark.seal.fill" : "lock.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(isSubscribed ? Theme.Palette.green : Theme.Palette.gold)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSubscribed ? Theme.Palette.green.opacity(0.12) : Theme.Palette.goldPastel)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(isSubscribed ? "Cashie Pro active" : "On the free tier")
                    .font(AppFont.text(17, weight: .semibold))
                Text(isSubscribed
                     ? "Everything's unlocked. Thanks for backing Cashie."
                     : "Unlock unlimited budgets, Wrappeds and Cashie notes.")
                    .font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if isSubscribed {
                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    actionLabel(title: "Manage in App Store", icon: "arrow.up.forward.app")
                }
                .buttonStyle(.plainTappable)
            } else {
                Button { showPaywall() } label: {
                    actionLabel(title: "See Cashie Pro plans", icon: "sparkles", filled: true)
                }
                .buttonStyle(.plainTappable)
            }

            Button(action: restore) {
                actionLabel(title: restoring ? "Restoring..." : "Restore purchase",
                            icon: "arrow.clockwise")
            }
            .buttonStyle(.plainTappable)
            .disabled(restoring)
        }
    }

    private func actionLabel(title: String, icon: String, filled: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(AppFont.text(14, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .foregroundColor(filled ? .white : Theme.Palette.ink)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(filled ? Theme.Palette.ink : Theme.Palette.bgCream)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(filled ? Color.clear : Theme.Palette.line, lineWidth: 1)
        )
    }

    private func showPaywall() {
        // Belt-and-braces: if the live subscription state says they're
        // already a Pro user (e.g. local @State hadn't refreshed yet),
        // drop them on Today instead of the paywall.
        if container.subscriptions.isSubscribed {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                container.mainTab = .today
            }
            return
        }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            UserDefaults.standard.set(false, forKey: "isSubscribed")
            container.advanceOnboarding(to: .paywall)
        }
    }

    private func restore() {
        restoring = true
        Task {
            let ok = (try? await container.subscriptions.restore()) ?? false
            await MainActor.run {
                restoring = false
                isSubscribed = ok
            }
        }
    }
}
