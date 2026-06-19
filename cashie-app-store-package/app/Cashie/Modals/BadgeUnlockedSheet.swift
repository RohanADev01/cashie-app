import SwiftUI

/// Fired automatically the moment a badge is earned, the same payoff treatment
/// as the rank level-up: a dark stage lit in the badge's colour, the medallion
/// bursting in with rays, then the title, what it was for, and the XP it banks.
struct BadgeUnlockedSheet: View {
    let badge: Badge
    @Environment(\.dismiss) var dismiss

    @State private var burstScale: CGFloat = 0.5
    @State private var burstOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.7
    @State private var copyOpacity: Double = 0
    @State private var copyOffset: CGFloat = 14

    var body: some View {
        ZStack {
            background
            VStack(spacing: 18) {
                stage
                copy
                    .opacity(copyOpacity)
                    .offset(y: copyOffset)
                action
                    .opacity(copyOpacity)
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
                colors: [badge.tint.opacity(0.35), .clear],
                center: .center, startRadius: 10, endRadius: 360
            )
        }
        .ignoresSafeArea()
    }

    private var stage: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                Capsule()
                    .fill(badge.tint.opacity(0.8))
                    .frame(width: 5, height: 92)
                    .offset(y: -96)
                    .rotationEffect(.degrees(Double(i) * 36))
                    .scaleEffect(burstScale)
                    .opacity(burstOpacity)
            }
            TimelineView(.animation) { timeline in
                BadgeView(badge: badge, unlocked: true, size: 130,
                          t: timeline.date.timeIntervalSinceReferenceDate)
            }
            .scaleEffect(ringScale)
        }
        .frame(height: 220)
    }

    private var copy: some View {
        VStack(spacing: 8) {
            Text("Badge unlocked")
                .font(AppFont.text(12, weight: .bold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.white.opacity(0.6))
            Text(badge.title)
                .font(AppFont.display(48, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, badge.tint],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Text(badge.currentDetail)
                .font(AppFont.text(14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("+\(badge.xp) XP toward your rank")
                    .font(AppFont.text(13, weight: .bold))
            }
            .foregroundColor(badge.tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(badge.tint.opacity(0.16)))
            .padding(.top, 4)
        }
    }

    private var action: some View {
        // Brand green, consistent across every badge colour.
        PrimaryButton(
            title: "Nice",
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
            copyOpacity = 1
            copyOffset = 0
        }
    }
}
