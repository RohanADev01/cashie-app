import SwiftUI

/// Fired once when the user crosses into a new tier. The payoff moment that
/// makes the climb feel worth it. Dark, tier-lit stage so the medallion and
/// its particles take the spotlight.
struct RankUpCelebrationSheet: View {
    let rank: Rank
    @Environment(\.dismiss) var dismiss

    @State private var burstScale: CGFloat = 0.5
    @State private var burstOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.7
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 14

    var body: some View {
        ZStack {
            background

            VStack(spacing: 20) {
                stage
                copy
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
                action
                    .opacity(titleOpacity)
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 28)
        }
        .onAppear { runIntro() }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x14171C), Color(hex: 0x070809)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [rank.glow.opacity(0.35), .clear],
                center: .center, startRadius: 10, endRadius: 360
            )
        }
        .ignoresSafeArea()
    }

    private var stage: some View {
        ZStack {
            // Radiating rays behind the badge.
            ForEach(0..<10, id: \.self) { i in
                Capsule()
                    .fill(rayColor(i))
                    .frame(width: 5, height: 96)
                    .offset(y: -100)
                    .rotationEffect(.degrees(Double(i) * 36))
                    .scaleEffect(burstScale)
                    .opacity(burstOpacity)
            }
            RankBadgeView(rank: rank, size: 150)
                .scaleEffect(ringScale)
        }
        .frame(height: 240)
    }

    private func rayColor(_ i: Int) -> Color {
        let palette = rank.particleColors
        return palette[i % palette.count].opacity(0.8)
    }

    private var copy: some View {
        VStack(spacing: 8) {
            Text("Rank up")
                .font(AppFont.text(12, weight: .bold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.white.opacity(0.6))
            Text(rank.title)
                .font(AppFont.display(52, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [rank.highlight, rank.midtone],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Text(rank.tagline)
                .font(AppFont.text(14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var action: some View {
        // Always the brand green so the CTA stays legible and consistent
        // across every tier (some tier midtones, e.g. Silver, washed out).
        PrimaryButton(
            title: rank.isMax ? "You did it" : "Keep climbing",
            trailingArrow: false,
            background: Theme.Palette.gold,
            foreground: .white
        ) {
            dismiss()
        }
        .padding(.top, 8)
    }

    private func runIntro() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
            ringScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.05)) {
            burstScale = 1.25
            burstOpacity = 1
        }
        withAnimation(.easeIn(duration: 0.8).delay(0.6)) {
            burstOpacity = 0
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.25)) {
            titleOpacity = 1
            titleOffset = 0
        }
    }
}
