import SwiftUI

/// The gamified rank card that headlines the Today tab. A premium dark
/// surface tinted to the current tier, with the live animated medallion on
/// the left and a clear "how far to the next rank" progress read on the
/// right. Tapping it opens the full ladder.
struct RankHeroCard: View {
    let progress: RankProgress
    var onTap: () -> Void

    private var rank: Rank { progress.current }
    private let cornerRadius: CGFloat = 16

    // Animate the progress bar filling on appear.
    @State private var animatedFraction: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            ZStack {
                background
                content
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(rank.glow.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: rank.glow.opacity(0.30), radius: 14, x: 0, y: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15)) {
                animatedFraction = CGFloat(progress.fraction)
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x191D24), Color(hex: 0x0D0F13)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [rank.glow.opacity(0.32), .clear],
                center: .init(x: 0.16, y: 0.5),
                startRadius: 8, endRadius: 230
            )
            RadialGradient(
                colors: [rank.midtone.opacity(0.14), .clear],
                center: .bottomTrailing, startRadius: 8, endRadius: 220
            )
        }
    }

    // MARK: - Content

    private var content: some View {
        HStack(spacing: 14) {
            RankBadgeView(rank: rank, size: 60)
                .frame(width: 96, height: 104)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your rank")
                    .font(AppFont.text(10, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.55))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(rank.title)
                        .font(AppFont.display(34, weight: .heavy))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [rank.highlight, rank.midtone],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }

                progressBar
                caption
            }
            .padding(.vertical, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [rank.highlight, rank.midtone],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, proxy.size.width * animatedFraction))
                    .shadow(color: rank.glow.opacity(0.7), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: 6)
    }

    private var caption: some View {
        HStack(spacing: 0) {
            if progress.isMaxed {
                Text("Top rank reached · ")
                    .font(AppFont.text(11, weight: .semibold))
                    .foregroundColor(rank.highlight)
                Text("\(formattedXP) XP")
                    .font(AppFont.text(11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else if let next = progress.next {
                Text("\(formatted(progress.xpToNext)) XP")
                    .font(AppFont.text(11, weight: .bold))
                    .foregroundColor(.white)
                Text(" to \(next.title)")
                    .font(AppFont.text(11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var formattedXP: String { formatted(progress.xp) }

    private func formatted(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
