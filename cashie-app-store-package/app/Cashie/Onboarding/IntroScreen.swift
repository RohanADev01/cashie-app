import SwiftUI

struct IntroScreen: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 320, intensity: 0.10).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("Quick check-in")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(
                    raw: "So… <em>what's your money story?</em>",
                    font: AppFont.display(40, weight: .bold)
                )

                Text("Five honest questions. No bank login, no credit pull.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.top, 4)

                HStack(spacing: 6) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(i == 0 ? Theme.Palette.ink : Theme.Palette.line)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 16) {
                    bullet("✦", "Find your hidden patterns")
                    bullet("✓", "Meet your money type")
                    bullet("→", "See what it's quietly costing")
                }
                .padding(.top, 18)

                Spacer()

                PrimaryButton(title: "Let's find out") {
                    container.advanceOnboarding(to: .quiz(1))
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 90)
            .padding(.bottom, 28)
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Text(icon)
                .font(AppFont.text(18, weight: .bold))
                .foregroundColor(Theme.Palette.gold)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.Palette.goldPastel))
            Text(text)
                .font(AppFont.callout)
                .foregroundColor(Theme.Palette.ink)
            Spacer()
        }
    }
}
