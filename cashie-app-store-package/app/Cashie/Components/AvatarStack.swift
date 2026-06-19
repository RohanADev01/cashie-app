import SwiftUI

/// Cluster of overlapping avatar circles - used as social-proof next to the
/// per-archetype population count on the reveal/archetype screens. Each
/// circle is a soft gradient (cream/peach/mint/blush) with a stylised
/// letter inside, so it reads as a real cohort without us needing photo
/// assets.
struct AvatarStack: View {
    var size: CGFloat = 28
    var overlap: CGFloat = 10

    private let avatars: [(letter: String, top: Color, bottom: Color, ink: Color)] = [
        ("A", Color(hex: 0xFFE3C2), Color(hex: 0xFFB57A), Color(hex: 0x8A4A14)),
        ("M", Color(hex: 0xC5E9D6), Color(hex: 0x6FCFA2), Color(hex: 0x0E5A3A)),
        ("J", Color(hex: 0xF8D6DC), Color(hex: 0xE89AAA), Color(hex: 0x8A2A40)),
        ("R", Color(hex: 0xD9E5F4), Color(hex: 0x8AAAD9), Color(hex: 0x2A4A8A)),
    ]

    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(avatars.enumerated()), id: \.offset) { _, a in
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [a.top, a.bottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(a.letter)
                        .font(AppFont.text(size * 0.40, weight: .bold))
                        .foregroundColor(a.ink)
                }
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
        }
    }
}
