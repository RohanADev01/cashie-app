import SwiftUI

struct BackTapTeaserScreen: View {
    @EnvironmentObject var container: AppContainer

    private let methods: [(icon: String, title: String, blurb: String, target: OnboardingStep)] = [
        ("hand.tap.fill", "Back Tap", "Triple-tap the back of your phone.", .backTapSetup),
        ("bolt.fill", "Action Button", "One press on iPhone 15 Pro and newer.", .actionButtonSetup),
        ("creditcard.fill", "Apple Pay", "Logs right after you pay with Apple Pay.", .applePaySetup)
    ]

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            VStack(spacing: 14) {
                BackBar(onBack: { container.advanceOnboarding(to: .backTapIntro) },
                        pageLabel: "Setup · 03 / 03")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("The 2-second log")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                EmphasizedHeadline(
                    raw: "Three ways to <em>log a spend.</em>",
                    font: AppFont.display(38, weight: .bold)
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Tap one to set it up. Each logs in seconds.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    ForEach(Array(methods.enumerated()), id: \.offset) { _, m in
                        methodRow(m)
                    }
                }
                .padding(.top, 6)

                Spacer()

                Button("Maybe later") {
                    container.advanceOnboarding(to: .currency)
                }
                .font(AppFont.text(12, weight: .medium))
                .foregroundColor(Theme.Palette.gold)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
    }

    private func methodRow(_ m: (icon: String, title: String, blurb: String, target: OnboardingStep)) -> some View {
        Button { container.advanceOnboarding(to: m.target) } label: {
            HStack(spacing: 14) {
                Image(systemName: m.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Palette.gold)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.goldLight))
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.title)
                        .font(AppFont.text(16, weight: .semibold))
                        .foregroundColor(Theme.Palette.ink)
                    Text(m.blurb)
                        .font(AppFont.text(13))
                        .foregroundColor(Theme.Palette.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plainTappable)
    }
}
