import SwiftUI

/// Sheet-presented "Meet your archetype" detail. Mirrors the onboarding
/// reveal screen so the user can re-read their type any time from the
/// You tab, without the onboarding chrome (no back-bar, sheet style).
struct ArchetypeSheet: View {
    let archetype: Archetype
    let traits: [Trait]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text("Your money type")
                        .font(AppFont.text(12, weight: .bold))
                        .tracking(2.4)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.ink)
                        .padding(.top, 18)

                    EmphasizedHeadline(
                        raw: "Meet\n<em>\(archetype.name).</em>",
                        font: AppFont.display(38, weight: .bold)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                    ArchetypeBadge(emoji: archetype.emoji, size: 130)
                        .padding(.vertical, 5)

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
        VStack(spacing: 0) {
            Text("Quick stats")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            stat("Confidence in match", "\(archetype.matchPercent)%")
            divider
            stat("Estimated $/year leak", Money.format(archetype.painYearly))
            divider
            statWithAvatars("Others like you we've seen", archetype.populationLabel)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
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
                                .frame(width: proxy.size.width * (CGFloat(trait.score) / 100))
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(Theme.Palette.lineSoft).frame(height: 1)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(AppFont.callout).foregroundColor(Theme.Palette.ink)
            Spacer()
            Text(value)
                .font(AppFont.text(16, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
        }
        .padding(.vertical, 10)
    }

    private func statWithAvatars(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(AppFont.callout).foregroundColor(Theme.Palette.ink)
            Spacer()
            HStack(spacing: 8) {
                AvatarStack(size: 26, overlap: 9)
                Text(value)
                    .font(AppFont.text(16, weight: .semibold))
                    .foregroundColor(Theme.Palette.ink)
            }
        }
        .padding(.vertical, 10)
    }
}
