import SwiftUI

/// Brand mark for the user's archetype. Used on the onboarding reveal screen
/// AND the "You" tab, same component so the look stays consistent.
///
/// Subtle brand-green coin: bright mint center fades to deep emerald edge.
/// The lighter center keeps emojis legible against the green surface.
struct ArchetypeBadge: View {
    let emoji: String
    var size: CGFloat = 130

    private var emojiSize: CGFloat { size * 0.46 }
    private var haloSize: CGFloat { size * 1.30 }
    private var ringWidth: CGFloat { max(1, size * 0.012) }

    // Soft on-brand green palette.
    private static let centerLight = Color(hex: 0xCFEBDC)
    private static let mid         = Color(hex: 0x6FCFA2)
    private static let deep        = Color(hex: 0x04BA74)
    private static let edge        = Color(hex: 0x047448)
    private static let halo        = Color(hex: 0x04BA74)

    var body: some View {
        ZStack {
            // Soft outer halo, sits behind everything.
            Circle()
                .fill(Self.halo.opacity(0.18))
                .frame(width: haloSize, height: haloSize)
                .blur(radius: size * 0.22)

            // Faint secondary mint halo
            Circle()
                .fill(Self.centerLight.opacity(0.40))
                .frame(width: size * 1.10, height: size * 1.10)
                .blur(radius: size * 0.12)

            // Main coin, radial gradient, bright mint top-left, deep edge.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Self.centerLight,
                            Self.mid,
                            Self.deep,
                            Self.edge,
                        ],
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: size * 0.05,
                        endRadius: size * 0.85
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    // Subtle inner highlight at the top, coin sheen
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.50), Color.white.opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: ringWidth * 1.5
                        )
                        .padding(ringWidth * 0.5)
                )
                .overlay(
                    // Crisp outer ring
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: ringWidth)
                )
                .shadow(
                    color: Self.deep.opacity(0.32),
                    radius: size * 0.20,
                    x: 0,
                    y: size * 0.10
                )

            // Emoji on top, gently shadowed for depth.
            Text(emoji)
                .font(.system(size: emojiSize))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        }
        .frame(width: haloSize, height: haloSize)
    }
}

/// The "Quick stats" block shown on the archetype reveal (onboarding) and the
/// archetype sheet (You tab). Built from the same white soft-card stat tiles the
/// main screens use, so both archetype pages read as part of the new UI family
/// instead of a separate list style.
struct ArchetypeQuickStats: View {
    let archetype: Archetype

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick stats")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: columns, spacing: 12) {
                tile(value: "\(archetype.matchPercent)%", label: "Match confidence")
                tile(value: Money.format(archetype.painYearly), label: "Est. yearly leak")
            }

            peopleTile
        }
    }

    private func tile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppFont.text(22, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .softCard()
    }

    /// Social-proof tile spans the full width so the avatar stack has room.
    private var peopleTile: some View {
        HStack(spacing: 14) {
            AvatarStack(size: 30, overlap: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(archetype.populationLabel)
                    .font(AppFont.text(22, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                    .monospacedDigit()
                Text("Others like you we've seen")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .softCard()
    }
}
