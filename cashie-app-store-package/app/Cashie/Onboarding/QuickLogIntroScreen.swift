import SwiftUI

/// Pre-paywall mechanism reveal. Sits between Pain and the Future/SocialProof
/// screen so users see *how* Cashie fixes the leak before they're asked to pay.
/// Three quick steps stagger in to convey "this takes seconds."
struct QuickLogIntroScreen: View {
    @EnvironmentObject var container: AppContainer
    @State private var revealStep: Int = 0

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                BackBar(onBack: { container.advanceOnboarding(to: .pain) })

                Text("Quick Log")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(
                    raw: "The fix takes about <em>2 seconds.</em>",
                    font: AppFont.display(34, weight: .bold)
                )

                Text("Most budgeting fails because logging is annoying. Cashie removes the friction.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)

                VStack(spacing: 12) {
                    stepRow(number: 1, icon: "☕",
                            title: "Buy something",
                            subtitle: "Coffee, food, anything")
                    stepRow(number: 2, icon: "📱",
                            title: "Triple-tap your phone",
                            subtitle: "From anywhere, screen on or off")
                    stepRow(number: 3, icon: "💵",
                            title: "Tap the amount",
                            subtitle: "Logged. About 2 seconds.")
                }
                .padding(.top, 18)

                Spacer(minLength: 0)

                PrimaryButton(title: "Show me the difference") {
                    container.advanceOnboarding(to: .socialProof)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
        .onAppear {
            for i in 1...3 {
                withAnimation(.easeOut(duration: 0.45).delay(Double(i) * 0.18)) {
                    revealStep = i
                }
            }
        }
    }

    private func stepRow(number: Int, icon: String, title: String, subtitle: String) -> some View {
        let visible = number <= revealStep
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.green)
                    .frame(width: 30, height: 30)
                Text("\(number)")
                    .font(AppFont.text(13, weight: .heavy))
                    .foregroundColor(.white)
            }
            Text(icon).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.text(15, weight: .semibold))
                    .foregroundColor(Theme.Palette.ink)
                Text(subtitle)
                    .font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
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
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -12)
    }
}
