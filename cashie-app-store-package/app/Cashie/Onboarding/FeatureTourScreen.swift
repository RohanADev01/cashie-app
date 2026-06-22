import SwiftUI

/// A minimal, tap-through feature tour shown right after Welcome, in place of
/// the old chat screen (`RelatabilityScreen`, kept in the repo but no longer in
/// the flow). Each page centers a single animated visual of a core feature with
/// a short headline; tapping anywhere on the page or the bottom button advances.
/// The last page hands off to the quiz intro.
struct FeatureTourScreen: View {
    @EnvironmentObject var container: AppContainer
    @State private var index = 0

    private struct Feature {
        let kicker: String
        /// `EmphasizedHeadline` raw string; the `<em>...</em>` span is the green accent.
        let headline: String
        let sub: String
    }

    private let features: [Feature] = [
        Feature(kicker: "Effortless",
                headline: "Log a spend in <em>two seconds</em>",
                sub: "Quicker than opening your bank app"),
        Feature(kicker: "Stay in control",
                headline: "Always know what's <em>safe to spend</em>",
                sub: "Updates the moment you log"),
        Feature(kicker: "See it all",
                headline: "Watch exactly <em>where it goes</em>",
                sub: "Find out what you spend on the most"),
        Feature(kicker: "Level up",
                headline: "Every log earns <em>real progress</em>",
                sub: "Climb from Bronze to Legendary"),
    ]

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 360, intensity: 0.10).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                // The whole middle is one big tap target: tapping anywhere here
                // advances, mirroring the Next button.
                ZStack {
                    page(features[index], index: index)
                        .id(index)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { advance() }

                PrimaryButton(title: index == features.count - 1 ? "Continue" : "Next") {
                    advance()
                }
                .padding(.horizontal, 28)
                .padding(.top, 6)

                Text("Tap to continue")
                    .font(AppFont.text(11, weight: .medium))
                    .foregroundColor(Theme.Palette.inkMute)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
            }
            .padding(.top, 8)
        }
        #if DEBUG
        // Dev affordance: `-tourPage N` jumps straight to a page for screenshots.
        .onAppear {
            let a = ProcessInfo.processInfo.arguments
            if let i = a.firstIndex(of: "-tourPage"), i + 1 < a.count, let n = Int(a[i + 1]) {
                index = min(max(n, 0), features.count - 1)
            }
        }
        #endif
    }

    private func advance() {
        if index < features.count - 1 {
            withAnimation(Theme.Motion.smooth) { index += 1 }
        } else {
            container.advanceOnboarding(to: .intro)
        }
    }

    // MARK: - Top bar (progress dots + skip)

    private var topBar: some View {
        HStack {
            HStack(spacing: 7) {
                ForEach(0..<features.count, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Theme.Palette.gold : Theme.Palette.line)
                        .frame(width: i == index ? 22 : 8, height: 8)
                        .animation(Theme.Motion.snap, value: index)
                }
            }
            Spacer()
            Button { container.advanceOnboarding(to: .intro) } label: {
                Text("Skip")
                    .font(AppFont.text(14, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .buttonStyle(.plainTappable)
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
    }

    // MARK: - Page

    private func page(_ f: Feature, index: Int) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            visual(for: index)
                .frame(height: 280)
            Spacer(minLength: 16)
            VStack(spacing: 12) {
                Text(f.kicker.uppercased())
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(Theme.Palette.gold)
                EmphasizedHeadline(raw: f.headline, font: AppFont.display(38, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(f.sub)
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 8)
        }
    }

    @ViewBuilder
    private func visual(for index: Int) -> some View {
        switch index {
        case 0: QuickLogVisual()
        case 1: SafeToSpendVisual()
        case 2: InsightsVisual()
        default: RankRingVisual()
        }
    }
}

// MARK: - Feature visuals

/// Tap-to-log: a green tap target with expanding ripples radiating out, the way
/// a Back Tap feels.
private struct QuickLogVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Theme.Palette.gold.opacity(0.45), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(animate ? 2.0 : 0.55)
                    .opacity(animate ? 0 : 0.7)
                    .animation(
                        reduceMotion ? nil :
                            .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 0.8),
                        value: animate
                    )
            }

            Circle()
                .fill(Theme.Palette.gold)
                .frame(width: 116, height: 116)
                .shadow(color: Theme.Palette.gold.opacity(0.4), radius: 16, x: 0, y: 8)

            Image(systemName: "hand.tap.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(height: 280)
        .onAppear { animate = true }
    }
}

/// Safe-to-spend: a ring that fills to a clean number, with a soft glow.
private struct SafeToSpendVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var glow = false
    private let target: CGFloat = 0.72

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.Palette.gold.opacity(0.22), .clear],
                    center: .center, startRadius: 10, endRadius: 130))
                .frame(width: 260, height: 260)
                .opacity(glow ? 1 : 0.6)

            Circle()
                .stroke(Theme.Palette.goldLight, lineWidth: 18)
                .frame(width: 176, height: 176)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.Palette.gold, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 176, height: 176)
                .shadow(color: Theme.Palette.gold.opacity(0.45), radius: 10, x: 0, y: 0)

            VStack(spacing: 2) {
                Text("Safe to spend")
                    .font(AppFont.text(12, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkSoft)
                Text("$248")
                    .font(AppFont.display(46, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
            }
        }
        .frame(height: 280)
        .onAppear {
            if reduceMotion {
                progress = target
            } else {
                withAnimation(.easeOut(duration: 1.1)) { progress = target }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
            }
        }
    }
}

/// Insights: a small bar chart that grows in, one bar highlighted, like the
/// week-wrapped breakdown.
private struct InsightsVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grow = false
    private let heights: [CGFloat] = [0.45, 0.70, 0.32, 0.92, 0.55, 0.80, 0.48]

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.Palette.gold.opacity(0.16), .clear],
                    center: .center, startRadius: 10, endRadius: 150))
                .frame(width: 280, height: 280)

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(heights.enumerated()), id: \.offset) { i, h in
                    Capsule()
                        .fill(i == 3 ? Theme.Palette.gold : Theme.Palette.goldLight)
                        .frame(width: 20, height: (grow ? h : 0.06) * 180)
                        .animation(
                            reduceMotion ? nil :
                                .spring(response: 0.6, dampingFraction: 0.72).delay(Double(i) * 0.07),
                            value: grow
                        )
                }
            }
            .frame(height: 180, alignment: .bottom)
        }
        .frame(height: 280)
        .onAppear { grow = true }
    }
}

/// Ranks: five large rank emblems on a slow 3D-style carousel. They ride a
/// flattened ellipse, growing and rising to the front (overlapping the smaller
/// ones behind) as they come round, each glowing in its tier colour over a
/// pulsing core. The marquee visual of the tour.
private struct RankRingVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The five highest tiers, so the showcase leads with the top ranks
    // (up to Master and Legendary).
    private let ranks: [Rank] = [.gold, .emerald, .diamond, .master, .legendary]
    private let radiusX: CGFloat = 92
    private let radiusY: CGFloat = 44
    private let baseSize: CGFloat = 80

    /// Fixed epoch so the carousel schedule is stable across renders.
    private static let clock = Date(timeIntervalSinceReferenceDate: 0)

    var body: some View {
        Group {
            if reduceMotion {
                ring(t: 0)
            } else {
                // 30fps is plenty for a slow 20s orbit and keeps five live
                // (vector) badges cheap to re-lay-out each tick.
                TimelineView(.periodic(from: Self.clock, by: 1.0 / 30.0)) { tl in
                    ring(t: tl.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(height: 280)
    }

    private func ring(t: TimeInterval) -> some View {
        let rev = t / 20.0
        let ringAngle = (rev - floor(rev)) * 360.0      // 0...360, never grows unbounded
        let pulse = sin(t * 1.4) * 0.5 + 0.5            // 0...1

        return ZStack {
            // Pulsing central glow.
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.Palette.gold.opacity(0.30), .clear],
                    center: .center, startRadius: 8, endRadius: 130))
                .frame(width: 260, height: 260)
                .scaleEffect(0.94 + 0.06 * pulse)

            ForEach(Array(ranks.enumerated()), id: \.offset) { i, rank in
                emblemView(rank, i, ringAngle: ringAngle)
            }
        }
    }

    /// Positions one emblem on the elliptical orbit, deriving its scale, opacity
    /// and z-order from how close to the front (bottom) it currently sits, so the
    /// front emblems are large and overlap the smaller ones behind.
    private func emblemView(_ rank: Rank, _ i: Int, ringAngle: Double) -> some View {
        let angle = (Double(i) / Double(ranks.count) * 360 + ringAngle) * .pi / 180
        let front = (1 - cos(angle)) / 2                // 0 (back/top) ... 1 (front/bottom)
        let x = CGFloat(sin(angle)) * radiusX
        let y = CGFloat(-cos(angle)) * radiusY
        let scale = 0.72 + 0.56 * CGFloat(front)
        return emblemBadge(rank, front: front)
            .scaleEffect(scale)
            .offset(x: x, y: y)
            .opacity(0.7 + 0.3 * front)
            .zIndex(front)
    }

    private func emblemBadge(_ rank: Rank, front: Double) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [rank.glow.opacity(0.45 + 0.40 * front), .clear],
                    center: .center, startRadius: 2, endRadius: baseSize * 0.7))
                .frame(width: baseSize * 1.35, height: baseSize * 1.35)
            // Live (vector) badge like the home-screen rank card: no
            // drawingGroup, so no square blend-mode halo. Aura off — the soft
            // glow above stands in and keeps five badges cheap.
            RankBadgeView(rank: rank, size: baseSize, animated: true, showsAura: false)
        }
    }
}
