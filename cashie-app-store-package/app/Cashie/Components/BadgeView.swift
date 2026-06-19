import SwiftUI

/// The circular emblem for a single badge. Unlocked badges are vivid in the
/// badge's own colour with a glow and shine; locked (not-yet-earned) badges are
/// fully grey with a small lock, so earned ones clearly stand apart. The
/// colour for locked badges lives on the progress bar in the card, not here.
///
/// Animation is driven by an externally supplied `t` (seconds) so a whole grid
/// can share one `TimelineView` instead of spinning up dozens.
struct BadgeView: View {
    let badge: Badge
    let unlocked: Bool
    var size: CGFloat = 64
    var t: TimeInterval = 0

    private var animated: Bool { unlocked && t != 0 }

    var body: some View {
        ZStack {
            if unlocked {
                let pulse = animated ? (sin(t * 1.7) * 0.5 + 0.5) : 0.5
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [badge.tint.opacity(0.5), .clear],
                            center: .center,
                            startRadius: size * 0.1,
                            endRadius: size * (0.62 + 0.08 * pulse)
                        )
                    )
                    .scaleEffect(1 + 0.06 * pulse)
            }

            Circle()
                .fill(faceGradient)
                .overlay(
                    Circle().fill(
                        RadialGradient(
                            colors: [Color.white.opacity(unlocked ? 0.5 : 0.25), .clear],
                            center: .init(x: 0.32, y: 0.28),
                            startRadius: 0, endRadius: size * 0.5
                        )
                    )
                    .blendMode(.screen)
                )
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: unlocked
                                ? [Color.white.opacity(0.6), badge.tint.opacity(0.5)]
                                : [Color.white.opacity(0.4), Color.black.opacity(0.08)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: size * 0.03
                    )
                )

            Image(systemName: badge.icon)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(
                    unlocked
                        ? LinearGradient(colors: [.white, .white.opacity(0.85)],
                                         startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Theme.Palette.inkMute, Theme.Palette.inkFaint],
                                         startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .black.opacity(unlocked ? 0.25 : 0), radius: size * 0.01, y: size * 0.01)

            if animated {
                shineSweep
            }

            if !unlocked {
                lockChip
            }
        }
        .frame(width: size, height: size)
        .shadow(color: unlocked ? badge.tint.opacity(0.35) : .clear,
                radius: size * 0.1, y: size * 0.05)
        .accessibilityElement()
        .accessibilityLabel("\(badge.title), \(unlocked ? "unlocked" : "locked")")
    }

    private var faceGradient: LinearGradient {
        if unlocked {
            return LinearGradient(
                colors: [badge.tint.opacity(0.95), badge.tint, badge.tint.opacity(0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        // Locked: fully grey.
        return LinearGradient(
            colors: [Color(hex: 0xE4E6EA), Color(hex: 0xCDD2D8)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var shineSweep: some View {
        let p = fract(t / 3.2)
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.0), Color.white.opacity(0.6),
                             Color.white.opacity(0.0), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: size * 0.5, height: size * 1.7)
            .rotationEffect(.degrees(22))
            .offset(x: (p * 2.2 - 1.1) * size)
            .blendMode(.screen)
            .mask(Circle().frame(width: size, height: size))
            .allowsHitTesting(false)
    }

    private var lockChip: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: size * 0.18, weight: .black))
            .foregroundColor(.white)
            .padding(size * 0.07)
            .background(Circle().fill(Theme.Palette.inkMute))
            .overlay(Circle().stroke(Color.white, lineWidth: size * 0.02))
            .offset(x: size * 0.33, y: size * 0.33)
    }
}

/// Local fract so the file is self-contained (the rank badge has its own).
private func fract(_ x: Double) -> Double { x - floor(x) }
