import SwiftUI

struct WelcomeScreen: View {
    @EnvironmentObject var container: AppContainer
    @State private var coinFloat: CGFloat = 0

    var body: some View {
        baseBody.tapAnywhereToContinue { container.advanceOnboarding(to: .relatability) }
    }

    private var baseBody: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 380)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("CASHIE")
                    .font(AppFont.text(15, weight: .bold))
                    .tracking(5)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.top, 14)

                Spacer()

                CoinMark(size: 160)
                    .offset(y: coinFloat)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                            coinFloat = -10
                        }
                    }
                    .padding(.bottom, 28)

                EmphasizedHeadline(
                    raw: "Money that's <em>actually</em> on your side.",
                    font: AppFont.display(44, weight: .bold)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

                Text("60 seconds. We'll show you where it's leaking.")
                    .font(AppFont.text(17, weight: .regular, italic: true))
                    .foregroundColor(Theme.Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.horizontal, 28)

                Spacer()

                PrimaryButton(title: "Find my money type") {
                    container.advanceOnboarding(to: .relatability)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
    }
}
