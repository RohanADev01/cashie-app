import SwiftUI

/// The "2-second log" intro: one punchy teaser that sells how fast logging is,
/// shown right before the "Three ways to log" chooser. A black phone with gold
/// rings radiating out of it. Continue leads into the chooser (`backTapTeaser`).
struct BackTapIntroScreen: View {
    @EnvironmentObject var container: AppContainer
    @State private var ringScale: CGFloat = 0.6

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            VStack(spacing: 14) {
                BackBar(onBack: { container.advanceOnboarding(to: .permissions) },
                        pageLabel: "Quick Log")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("The 2-second log")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(
                    raw: "Log any spend in <em>2 seconds.</em>",
                    font: AppFont.display(40, weight: .bold)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

                Text("Tap the back of your phone twice. That's it.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .multilineTextAlignment(.center)

                phoneIllustration
                    .frame(height: 220)
                    .padding(.vertical, 20)

                HStack(spacing: 18) {
                    miniStat("2s", "avg log")
                    miniStat("94%", "same-day")
                    miniStat("0", "app unlocks")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))

                Spacer()

                PrimaryButton(title: "Show me how") {
                    container.advanceOnboarding(to: .backTapTeaser)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
    }

    private var phoneIllustration: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Theme.Palette.gold.opacity(0.5 - Double(i) * 0.15), lineWidth: 1)
                    .frame(width: 140 + CGFloat(i) * 50, height: 140 + CGFloat(i) * 50)
                    .scaleEffect(ringScale)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Theme.Palette.ink)
                    .frame(width: 80, height: 130)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Theme.Palette.gold)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                ringScale = 1.0
            }
        }
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.display(22, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
            Text(label)
                .font(AppFont.text(10, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}
