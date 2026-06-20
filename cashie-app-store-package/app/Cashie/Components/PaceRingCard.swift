import SwiftUI

/// Consolidated home hero. A clean white floating card (the app's `softCard`)
/// carrying a circular "month budget used" ring beside the safe-to-spend
/// figure, so the top of the Today tab reads as one family with the rank card
/// and every other surface.
///
/// The ring runs brand green while you're on pace, honey-amber once you cross
/// 85% of the monthly cap, and red once you go over. Tapping it opens Manage
/// Budgets, same as the old balance hero.
struct PaceRingCard: View {
    let safeToSpendWhole: String
    let safeToSpendCents: String
    /// True when the user is over the monthly cap; the figure renders red with
    /// an "over" tag instead of ink.
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
                .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 6) {
                Text("SAFE TO SPEND")
                    .font(AppFont.text(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Theme.Palette.inkMute)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Money.symbol)
                        .font(AppFont.text(20, weight: .semibold))
                        .foregroundColor(Theme.Palette.inkMute)
                    Text(safeToSpendWhole)
                        .font(AppFont.display(40, weight: .heavy))
                        // Match the ring: green on pace, amber from 85% of the
                        // cap, red once over budget.
                        .foregroundColor(negative ? Theme.Palette.red : tint)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if showCents {
                        Text(safeToSpendCents)
                            .font(AppFont.text(16, weight: .semibold))
                            .foregroundColor(Theme.Palette.inkMute)
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
                        .foregroundColor(Theme.Palette.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
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
}

/// Circular budget gauge with an animated fill on appear. Shows the percent
/// used in the center, or a neutral target glyph when no cap is set yet. Tuned
/// for a light surface: a faint ink track and a solid tinted arc.
private struct PaceRing: View {
    let fraction: Double
    let tint: Color
    var showsLabel: Bool = true

    var body: some View {
        ZStack {
            Circle().stroke(Theme.Palette.ink.opacity(0.07), lineWidth: 10)
            Circle()
                // Driven straight off `fraction` (not a separate @State that
                // syncs in onAppear). The store loads asynchronously, so the
                // card first renders with fraction 0; binding the trim to the
                // live value means the arc fills the moment data arrives.
                // `.animation(value:)` tweens that 0 -> ratio change.
                .trim(from: 0, to: min(1, CGFloat(fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // Soft tinted glow around the arc, so the ring carries the same
                // life it had on the old dark hero, tuned down for the white card.
                .shadow(color: tint.opacity(0.45), radius: 6)
                .animation(.spring(response: 0.8, dampingFraction: 0.85), value: fraction)

            if showsLabel {
                VStack(spacing: 0) {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(AppFont.display(22, weight: .heavy))
                        .foregroundColor(Theme.Palette.ink)
                        .monospacedDigit()
                    Text("used")
                        .font(AppFont.text(9, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(Theme.Palette.inkMute)
                }
            } else {
                Image(systemName: "target")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkFaint)
            }
        }
    }
}
