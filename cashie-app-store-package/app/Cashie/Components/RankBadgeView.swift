import SwiftUI

/// The animated rank medallion. This is the visual heart of the gamified
/// home screen.
///
/// It renders in two modes, transparently:
///   1. If Gemini-generated art exists in the asset catalog under
///      `rank.assetName`, that PNG is used as the badge.
///   2. Otherwise a procedural metallic medallion is drawn in code, so the
///      feature looks complete before any art is dropped in.
///
/// Around the badge sits the "background animation" the brief asked for: a
/// pulsing aura, a field of floating particles tinted to the tier, a polished
/// shine sweep, and (for Legendary) rotating godrays. Higher tiers animate
/// more richly via `rank.intensity`.
struct RankBadgeView: View {
    let rank: Rank
    var size: CGFloat = 120
    /// When false, renders a single static frame (used for the small badges
    /// in the ladder list and for Reduce Motion).
    var animated: Bool = true
    /// The aura + particles + godrays. Turn off for tight rows.
    var showsAura: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motionOn: Bool { animated && !reduceMotion }

    /// Fixed epoch for the throttled animation schedule (stable across renders).
    private static let animClock = Date(timeIntervalSinceReferenceDate: 0)

    var body: some View {
        // One TimelineView drives both layers (half the per-frame work of two),
        // and renders a single static frame when motion is off.
        Group {
            if motionOn {
                // Throttled to ~30fps instead of the display refresh (up to
                // 120fps on ProMotion). The float/pulse/shine are all slow, so
                // 30fps looks the same but cuts per-frame Canvas + mask work to
                // a quarter, which is what made the rank carousel feel laggy.
                TimelineView(.periodic(from: Self.animClock, by: 1.0 / 30.0)) { timeline in
                    layers(t: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                // Static badge: rasterize once so the carousel can scale/drag a
                // bitmap instead of re-compositing the procedural medallion.
                layers(t: 0).drawingGroup()
            }
        }
        .frame(width: size * 1.7, height: size * 1.7)
        .accessibilityElement()
        .accessibilityLabel("\(rank.title) rank")
    }

    @ViewBuilder
    private func layers(t: TimeInterval) -> some View {
        ZStack {
            if showsAura { atmosphere(t: t) }
            medallion(t: t)
        }
    }

    // MARK: - Atmosphere (aura, particles, godrays)

    @ViewBuilder
    private func atmosphere(t: TimeInterval) -> some View {
        let pulse = motionOn ? (sin(t * 1.6) * 0.5 + 0.5) : 0.5   // 0...1

        ZStack {
            // Soft pulsing aura behind the badge.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [rank.glow.opacity(0.55), rank.glow.opacity(0.0)],
                        center: .center,
                        startRadius: size * 0.12,
                        endRadius: size * (0.78 + 0.10 * pulse)
                    )
                )
                .scaleEffect(1.0 + 0.05 * pulse)
                .opacity(0.55 + 0.35 * pulse)

            // Legendary gets slow rotating godrays for a top-of-mountain feel.
            if rank == .legendary {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: rank.glow.opacity(0.0), location: 0.00),
                                .init(color: rank.glow.opacity(0.30), location: 0.08),
                                .init(color: rank.glow.opacity(0.0), location: 0.16),
                                .init(color: rank.glow.opacity(0.0), location: 0.50),
                                .init(color: Color(hex: 0xFFE7A8).opacity(0.28), location: 0.58),
                                .init(color: rank.glow.opacity(0.0), location: 0.66),
                                .init(color: rank.glow.opacity(0.0), location: 1.00),
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: size * 1.6, height: size * 1.6)
                    .rotationEffect(.degrees(t * 16))
                    .blur(radius: size * 0.03)
                    .blendMode(.plusLighter)
            }

            if motionOn {
                particleField(t: t)
            }
        }
    }

    private func particleField(t: TimeInterval) -> some View {
        // More particles and a touch more energy as the tier climbs. Kept
        // lean (was 8 + 14·intensity) so the Canvas redraw stays cheap.
        let count = 5 + Int(rank.intensity * 7)
        let colors = rank.particleColors
        let field = size * 1.5

        return Canvas { ctx, canvas in
            for i in 0..<count {
                let seed = Double(i)
                let rx = fract(sin(seed * 12.9898) * 43758.5453)
                let phase = fract(cos(seed * 78.233) * 12543.987)
                let speed = 0.06 + fract(sin(seed * 3.17) * 9871.23) * 0.10
                let radius = field * (0.006 + fract(cos(seed * 5.51) * 7321.9) * 0.012)
                let drift = field * (0.02 + fract(sin(seed * 1.91) * 4413.7) * 0.05)

                let loop = fract(t * speed + phase)            // 0...1, rising
                let y = canvas.height * (1.02 - loop * 1.04)   // bottom -> top
                let x = canvas.width * (0.1 + rx * 0.8)
                    + CGFloat(sin((loop + phase) * .pi * 2)) * drift
                let fade = sin(loop * .pi)                      // soft in/out
                guard fade > 0.02 else { continue }

                let color = colors[i % colors.count].opacity(0.9 * fade)
                let rect = CGRect(x: x - radius, y: y - radius,
                                  width: radius * 2, height: radius * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .frame(width: field, height: field)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    // MARK: - Medallion + shine

    @ViewBuilder
    private func medallion(t: TimeInterval) -> some View {
        // A gentle bob + tilt so the badge feels alive, mirroring the mascot.
        let bob = motionOn ? CGFloat(sin(t * 1.1)) * (size * 0.012) : 0
        let tilt = motionOn ? sin(t * 0.7) * 2.2 : 0

        ZStack {
            badgeArtwork
            if motionOn { shineSweep(t: t) }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(tilt))
        .offset(y: bob)
        .shadow(color: rank.shadow.opacity(0.35), radius: size * 0.08, x: 0, y: size * 0.05)
    }

    @ViewBuilder
    private var badgeArtwork: some View {
        if let art = Self.loadedArt(rank.assetName) {
            art
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            RankMedallion(rank: rank, size: size)
        }
    }

    /// A bright diagonal band that periodically glints across the badge,
    /// masked to its silhouette so the highlight only lands on the artwork.
    private func shineSweep(t: TimeInterval) -> some View {
        let cycle = max(0.9, 3.6 - rank.intensity * 1.4)   // higher tiers glint sooner
        let p = fract(t / cycle)                            // 0...1
        let offset = (p * 2.2 - 1.1) * size                 // sweeps past both edges

        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.55),
                        Color.white.opacity(0.0),
                        .clear,
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: size * 0.55, height: size * 1.7)
            .rotationEffect(.degrees(22))
            .offset(x: offset)
            .blendMode(.screen)
            .mask(sweepMask)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var sweepMask: some View {
        if let art = Self.loadedArt(rank.assetName) {
            art.resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Circle().frame(width: size, height: size)
        }
    }
}

// MARK: - Procedural medallion fallback

/// A code-drawn metallic coin used when no badge art is present. Layers a
/// milled rim, an angular metallic sheen, a beveled inner disc and an
/// embossed tier symbol so it reads as a real game emblem.
private struct RankMedallion: View {
    let rank: Rank
    let size: CGFloat

    var body: some View {
        ZStack {
            // Outer rim
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            rank.shadow, rank.highlight, rank.midtone,
                            rank.shadow, rank.highlight, rank.shadow,
                        ]),
                        center: .center
                    )
                )
            // Milled edge ticks for a coin-like finish
            ForEach(0..<36, id: \.self) { i in
                Capsule()
                    .fill(rank.shadow.opacity(0.35))
                    .frame(width: size * 0.012, height: size * 0.05)
                    .offset(y: -size * 0.455)
                    .rotationEffect(.degrees(Double(i) * 10))
            }
            // Inner field
            Circle()
                .fill(
                    LinearGradient(
                        colors: [rank.highlight, rank.midtone, rank.shadow],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .padding(size * 0.14)
            // Top-left specular highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.55), .clear],
                        center: .init(x: 0.32, y: 0.28),
                        startRadius: 0, endRadius: size * 0.38
                    )
                )
                .padding(size * 0.14)
                .blendMode(.screen)
            // Inner bevel ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.65), rank.shadow.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: size * 0.02
                )
                .padding(size * 0.14)
            // Tier symbol, embossed
            Image(systemName: rank.symbol)
                .font(.system(size: size * 0.36, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), rank.highlight],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: rank.shadow.opacity(0.7), radius: size * 0.01, x: 0, y: size * 0.012)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().strokeBorder(rank.shadow.opacity(0.45), lineWidth: size * 0.01)
        )
    }
}

// MARK: - Helpers

extension RankBadgeView {
    /// Returns the badge art only if a real image is present. An empty
    /// placeholder imageset (no art dropped in yet) returns a zero-size image,
    /// which we treat as missing so the procedural medallion shows instead.
    static func loadedArt(_ name: String) -> Image? {
        if let ui = UIImage(named: name), ui.size.width > 2, ui.size.height > 2 {
            return Image(uiImage: ui)
        }
        return nil
    }
}

/// Fractional part, used for cheap deterministic particle seeding without
/// `Math.random` (keeps SwiftUI previews stable too).
private func fract(_ x: Double) -> Double {
    x - floor(x)
}
