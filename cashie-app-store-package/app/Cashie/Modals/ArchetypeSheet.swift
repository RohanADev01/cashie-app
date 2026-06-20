import SwiftUI

/// Sheet-presented "Meet your archetype" detail. Mirrors the onboarding
/// reveal screen so the user can re-read their type any time from the
/// You tab, without the onboarding chrome (no back-bar, sheet style).
struct ArchetypeSheet: View {
    let archetype: Archetype
    let traits: [Trait]
    @Environment(\.dismiss) var dismiss

    /// Gentle breathing float for the archetype coin, plus a one-shot fill for
    /// the trait bars, so the sheet feels alive on open.
    @State private var coinFloat: CGFloat = 0
    @State private var barsFilled = false

    var body: some View {
        ZStack(alignment: .top) {
            Theme.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text("Your money type")
                        .font(AppFont.text(12, weight: .bold))
                        .tracking(2.4)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.ink)
                        .padding(.top, 18)

                    EmphasizedHeadline(
                        raw: "Meet\n<em>\(archetype.name)</em>",
                        font: AppFont.display(38, weight: .bold)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                    ArchetypeBadge(emoji: archetype.emoji, size: 130)
                        .padding(.vertical, 5)
                        .offset(y: coinFloat)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                                coinFloat = -7
                            }
                            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.15)) {
                                barsFilled = true
                            }
                        }

                    Text(archetype.tagline)
                        .font(AppFont.text(14, weight: .regular, italic: true))
                        .foregroundColor(Theme.Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 26)
                        .padding(.top, 6)

                    insights
                        .padding(.top, 18)
                        .padding(.horizontal, 24)

                    if !traits.isEmpty {
                        traitsCard
                            .padding(.top, 12)
                            .padding(.horizontal, 24)
                    }

                    PrimaryButton(title: "Got it", trailingArrow: false) {
                        dismiss()
                    }
                    .padding(.top, 22)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private var insights: some View {
        ArchetypeQuickStats(archetype: archetype)
    }

    private var traitsCard: some View {
        VStack(spacing: 14) {
            Text("Your traits")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(traits, id: \.trait) { trait in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(trait.trait.label)
                            .font(AppFont.text(13, weight: .semibold))
                            .foregroundColor(Theme.Palette.ink)
                        Spacer()
                        Text("\(trait.score)")
                            .font(AppFont.text(15, weight: .bold))
                            .foregroundColor(Theme.Palette.ink)
                            .monospacedDigit()
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.Palette.lineSoft)
                            Capsule()
                                .fill(Theme.Palette.gold)
                                .frame(width: proxy.size.width * (barsFilled ? CGFloat(trait.score) / 100 : 0))
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(20)
        .softCard()
    }
}
