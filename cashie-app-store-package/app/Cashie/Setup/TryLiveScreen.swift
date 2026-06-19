import SwiftUI

/// "Try it live", embeds a Quick Log demo so users build muscle memory.
struct TryLiveScreen: View {
    @EnvironmentObject var container: AppContainer
    @State private var amountText: String = "18"
    @State private var category: SpendCategory = .food

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                BackBar(onBack: { container.advanceOnboarding(to: .backTapTeaser) },
                        pageLabel: "Try it live · 03 / 03")

                Text("One last thing")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(
                    raw: "Log a fake <em>\(Money.symbol)18 ramen.</em>",
                    font: AppFont.display(30, weight: .bold)
                )
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)

                Text("Builds the muscle memory. Real spend after.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)

                QuickLogBody(amountText: $amountText,
                             category: $category,
                             leftInBudget: 132,
                             onLog: handleLog)

                Spacer()
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
    }

    private func handleLog() {
        guard let amt = Double(amountText) else { return }
        let tx = Transaction(merchant: "Ramen - first log!", amount: amt, category: category, date: Date(), source: .quicklog)
        container.addTransaction(tx)
        container.user.quickLogSetup = true
        container.advanceOnboarding(to: .ready)
    }
}
