import SwiftUI

struct PainScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState

    var body: some View {
        baseBody.tapAnywhereToContinue { container.advanceOnboarding(to: .quickLogIntro) }
    }

    private var baseBody: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                BackBar(onBack: { container.advanceOnboarding(to: .traits) },
                        pageLabel: "Profile · 03 / 04")

                Text("The leak")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(
                    raw: "People with your habits often overspend about <em>\(formatted)</em> a year",
                    font: AppFont.display(34, weight: .bold),
                    emColor: Theme.Palette.red
                )

                Text("Over five years that's \(Money.format(state.selectedArchetype.painYearly * 5)), usually from small habits that never feel like much")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)

                Text("The usual suspects")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.top, 6)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        painCard("🥡", "Food delivery", "A few orders a week.", state.selectedArchetype.painYearly * 0.32)
                        painCard("🛍️", "Impulse buys", "Things you didn't really need.", state.selectedArchetype.painYearly * 0.30)
                        painCard("🧋", "Coffee and drink runs", "A few dollars, most days.", state.selectedArchetype.painYearly * 0.20)
                        painCard("💳", "Forgotten subscriptions", "A few you don't use anymore.", state.selectedArchetype.painYearly * 0.18)
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                }

                PrimaryButton(title: "Show me how to stop it") {
                    container.advanceOnboarding(to: .quickLogIntro)
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
