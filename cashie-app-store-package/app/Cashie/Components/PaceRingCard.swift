import SwiftUI

/// Consolidated home hero. Replaces the old stacked Safe-to-spend /
/// This-month / This-week trio with a single premium dark card that matches
/// `RankHeroCard`, so the top of the Today tab reads as one family: a
/// circular "month budget used" ring beside the safe-to-spend figure.
///
/// The ring (and the card's glow) run brand green while you're on pace,
/// honey-amber once you cross 85% of the monthly cap, and red once you go
/// over. Tapping it opens Manage Budgets, same as the old balance hero.
struct PaceRingCard: View {
    let safeToSpendWhole: String
    let safeToSpendCents: String
    /// True when the user is over the monthly cap; the figure renders as a
    /// red "-$…" instead of a white "$…".
    var negative: Bool = false
    /// 0...1+ of the monthly cap consumed (expenses + goal deposits).
    let monthRatio: Double
    let hasCap: Bool
    let dailyAllowance: Double
    let daysLeft: Int

    private var tint: Color {
        guard hasCap else { return Theme.Palette.gold }
        if monthRatio > 1 { return Theme.Palette.red }
        if monthRatio >= 0.85 { return Theme.Palette.winGold }
        return Theme.Palette.gold
    }

    var body: some View {
        HStack(spacing: 18) {
            PaceRing(fraction: monthRatio, tint: tint, showsLabel: hasCap)
                .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 7) {
                Text("SAFE TO SPEND")
                    .font(AppFont.text(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.55))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Money.symbol)
                        .font(AppFont.text(20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Text(safeToSpendWhole)
                        .font(AppFont.display(40, weight: .heavy))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if showCents {
                        Text(safeToSpendCents)
                            .font(AppFont.text(16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    if negative {
                        Text("over")
                            .font(AppFont.text(13, weight: .bold))
                            .foregroundColor(Theme.Palette.red)
                            .padding(.leading, 5)
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(caption)
                        .font(AppFont.text(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.26), radius: 14, x: 0, y: 6)
    }

    /// Cents are dropped once the figure reaches 5 digits (>= 10,000) so a big
    /// number like "13,000" stays whole instead of truncating to "13,2…" while
    /// the cents/over labels keep their size. Cents only matter at small amounts.
    private var showCents: Bool {
        safeToSpendWhole.filter(\.isNumber).count < 5
    }

    private var caption: String {
        guard hasCap, dailyAllowance > 0 else {
            return "Set a monthly cap to see your daily pace."
        }
        return "\(Money.symbol)\(Int(dailyAllowance.rounded()))/day · \(daysLeft) \(daysLeft == 1 ? "day" : "days") left"
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x191D24), Color(hex: 0x0D0F13)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Glow sits behind the amount on the right, not under the ring, so
            // the ring's colored arc reads against the dark base instead of
            // disappearing into a same-colored wash.
            RadialGradient(
                colors: [tint.opacity(0.28), .clear],
                center: .init(x: 0.72, y: 0.4), startRadius: 8, endRadius: 240
            )
        }
    }
}

/// Circular budget gauge with an animated fill on appear. Shows the percent
/// used in the center, or a neutral target glyph when no cap is set yet.
private struct PaceRing: View {
    let fraction: Double
    let tint: Color
    var showsLabel: Bool = true

    var body: some View {
        ZStack {
            // Brighter track so the ring always reads as a full circle, even
            // when the filled arc is small.
            Circle().stroke(Color.white.opacity(0.20), lineWidth: 11)
            Circle()
                // Driven straight off `fraction` (not a separate @State that
                // syncs in onAppear). The store loads asynchronously, so the
                // card first renders with fraction 0; binding the trim to the
                // live value means the arc fills the moment data arrives,
                // whether the screen appeared automatically or via a tab
                // switch. `.animation(value:)` tweens that 0 -> ratio change.
                .trim(from: 0, to: min(1, CGFloat(fraction)))
                .stroke(
                    LinearGradient(
                        colors: [tint, Color.white.opacity(0.85)],
                        startPoint: .bottom, endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.9), radius: 7)
                .animation(.spring(response: 0.8, dampingFraction: 0.85), value: fraction)

            if showsLabel {
                VStack(spacing: 1) {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(AppFont.display(24, weight: .heavy))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text("used")
                        .font(AppFont.text(9, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                Image(systemName: "target")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }
}
