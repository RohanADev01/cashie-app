import SwiftUI

struct TraitsScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState
    @State private var fillProgress: CGFloat = 0

    var body: some View {
        baseBody.tapAnywhereToContinue { container.advanceOnboarding(to: .pain) }
    }

    private var baseBody: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                BackBar(onBack: { container.advanceOnboarding(to: .reveal) },
                        pageLabel: "Profile · 02 / 05")

                Text("Your traits")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(
                    raw: "Where you <em>actually</em> stand.",
                    font: AppFont.display(34, weight: .bold)
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        ForEach(state.traits, id: \.trait) { trait in
                            TraitRow(trait: trait, fillProgress: fillProgress)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }

                PrimaryButton(title: "Show me what it's costing me") {
                    container.advanceOnboarding(to: .pain)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { fillProgress = 1 }
        }
    }
}

private struct TraitRow: View {
    let trait: Trait
    let fillProgress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trait.trait.label)
                    .font(AppFont.headline)
                    .foregroundColor(Theme.Palette.ink)
                Spacer()
                Text("\(trait.score)")
                    .font(AppFont.display(28, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.lineSoft)
                    Capsule()
                        .fill(Theme.Palette.gold)
                        .frame(width: proxy.size.width * (CGFloat(trait.score) / 100) * fillProgress)
                }
            }
            .frame(height: 6)
            Text(trait.blurb)
                .font(AppFont.text(13, weight: .regular))
                .foregroundColor(Theme.Palette.inkSoft)
                .multilineTextAlignment(.leading)
        }
    }
}
