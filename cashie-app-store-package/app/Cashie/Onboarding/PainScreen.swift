import SwiftUI

struct PainScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                BackBar(onBack: { container.advanceOnboarding(to: .traits) },
                        pageLabel: "Profile · 03 / 05")

                Text("The leak")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(
                    raw: "You're losing about <em>\(formatted)</em> a year.",
                    font: AppFont.display(34, weight: .bold)
                )

                Text("Compounded over 5 years that's \(Money.format(state.selectedArchetype.painYearly * 5)), about a year of rent.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        painCard("🍜", "Late-night food", "Most weeks, after 9pm.", state.selectedArchetype.painYearly * 0.32)
                        painCard("📺", "Forgotten subscriptions", "3 you stopped using.", state.selectedArchetype.painYearly * 0.18)
                        painCard("🛍", "Impulse hauls", "Sub-8s decisions add up.", state.selectedArchetype.painYearly * 0.30)
                        painCard("🍻", "Round-buying nights", "Generosity tax.", state.selectedArchetype.painYearly * 0.20)
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                }

                PrimaryButton(title: "Show me how to stop it") {
                    container.advanceOnboarding(to: .solution)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
    }

    private var formatted: String {
        Money.format(state.selectedArchetype.painYearly)
    }

    private func painCard(_ emoji: String, _ name: String, _ desc: String, _ amount: Double) -> some View {
        HStack(spacing: 14) {
            Text(emoji).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(AppFont.text(15, weight: .semibold))
                    .foregroundColor(Theme.Palette.ink)
                Text(desc).font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
            Text("−\(Money.format(amount))")
                .font(AppFont.text(15, weight: .semibold))
                .foregroundColor(Theme.Palette.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Palette.bgCream)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Palette.line, lineWidth: 1)
        )
    }
}
