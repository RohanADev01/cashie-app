import SwiftUI

/// The gamified rank card that headlines the Today tab. A clean white floating
/// card (the app's `softCard`) with the live animated medallion on the left and
/// a clear "how far to the next rank" progress read on the right, so it sits in
/// the same family as the pace card and every other surface. Tapping it opens
/// the full ladder.
struct RankHeroCard: View {
    let progress: RankProgress
    var onTap: () -> Void

    private var rank: Rank { progress.current }

    // Animate the progress bar filling on appear.
    @State private var animatedFraction: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Aura back on: its pulsing radial glow draws with no blend mode,
                // so it reads as a soft tier-coloured halo even on the white card.
                // richEffects off: this medallion lives inside the Today tab's
                // scroll view, so the Canvas particles / blend-mode shine /
                // godrays are dropped to keep scrolling smooth. The aura pulse +
                // bob + tilt still give it life.
                RankBadgeView(rank: rank, size: 52, animated: true,
                              showsAura: true, richEffects: false)
                    .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR RANK")
                        .font(AppFont.text(10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(Theme.Palette.inkMute)

                    Text(rank.title)
                        .font(AppFont.display(30, weight: .heavy))
                        // On a white card the pale `highlight` stop washes out,
                        // so the title is drawn from the saturated midtone down
                        // to the shadow: still metallic, but high-contrast and
                        // clearly legible for every tier.
                        .foregroundStyle(
                            LinearGradient(
                                colors: [rank.midtone, rank.shadow],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                    progressBar
                    caption
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            // A light, tier-tinted gradient (the rank's own glow colour, kept
            // pale) so the card feels alive without going dark. Same soft shadow
            // as `softCard` so it still floats like every other surface.
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .overlay {
                        LinearGradient(
                            colors: [rank.glow.opacity(0.07), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    }
                    .overlay {
                        RadialGradient(
                            colors: [rank.glow.opacity(0.06), .clear],
                            center: .topLeading, startRadius: 8, endRadius: 220
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 9)
            .shadow(color: Color.black.opacity(0.025), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15)) {
                animatedFraction = CGFloat(progress.fraction)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.ink.opacity(0.07))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [rank.glow, rank.midtone],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, proxy.size.width * animatedFraction))
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder private var caption: some View {
        if progress.isMaxed {
            Text("Top rank reached")
                .font(AppFont.text(11, weight: .semibold))
                .foregroundColor(rank.midtone)
        } else if let next = progress.next {
            HStack(spacing: 5) {
                Text("\(formatted(progress.xpToNext)) XP to")
                    .font(AppFont.text(11, weight: .medium))
                    .foregroundColor(Theme.Palette.inkSoft)
                // A small medallion of the next tier, so the goal you're
                // climbing toward is visible right in the caption.
                RankBadgeView(rank: next, size: 15, animated: false, showsAura: false)
                    .frame(width: 17, height: 17)
                Text(next.title)
                    .font(AppFont.text(11, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private func formatted(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
