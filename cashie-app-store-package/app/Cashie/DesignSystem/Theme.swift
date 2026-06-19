import SwiftUI

enum Theme {
    enum Palette {
        static let bg = Color(hex: 0xFAFAFA)
        static let bgWarm = Color(hex: 0xF2F3F5)
        static let bgCream = Color(hex: 0xF4F5F7)
        static let phoneBg = Color(hex: 0xEAECEE)

        static let ink = Color(hex: 0x111111)
        static let inkSoft = Color(hex: 0x111111).opacity(0.68)
        static let inkMute = Color(hex: 0x111111).opacity(0.48)
        static let inkFaint = Color(hex: 0x111111).opacity(0.30)

        static let line = Color(hex: 0x111111).opacity(0.14)
        static let lineSoft = Color(hex: 0x111111).opacity(0.08)

        static let gold = Color(hex: 0x04BA74)
        static let goldPastel = Color(hex: 0xEAF7F1)
        static let goldLight = Color(hex: 0xD5F2E8)

        /// Warm true-gold tones used for "you finished" treatments so funded
        /// goals read as celebratory rather than the brand mint everything
        /// else uses. Tuned to sit at the same saturation/brightness as the
        /// brand mint and the streak orange. These shade into amber/honey
        /// rather than yellow so the surfaces read as metal, not lemon.
        static let winGold = Color(hex: 0xF1BD3A)        // bright honey amber
        static let winGoldDeep = Color(hex: 0xC9881A)    // bronze, for shading
        static let winGoldLight = Color(hex: 0xFCE9A8)   // bright champagne
        static let winGoldPastel = Color(hex: 0xFEF5D6)  // cream gold
        static let winGoldMetallic = Color(hex: 0xD4A436) // flat metallic gold, mid-tone

        /// Diagonal champagne→amber→bronze gradient. Use this on filled
        /// surfaces (emoji tile, progress bar, ribbon backgrounds) so funded
        /// goals get a metallic sheen instead of looking like flat yellow.
        /// Highlights are pushed brighter to read as polished, not dull.
        static var winGoldGradient: LinearGradient {
            LinearGradient(
                colors: [
                    Color(hex: 0xFFF1C0),  // pearly champagne highlight
                    Color(hex: 0xF6CB48),  // saturated amber midtone
                    Color(hex: 0xC9881A),  // warm bronze shadow
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }

        /// Same gradient on a horizontal axis, for progress bars.
        static var winGoldGradientHorizontal: LinearGradient {
            LinearGradient(
                colors: [
                    Color(hex: 0xFFEAA8),
                    Color(hex: 0xF6CB48),
                    Color(hex: 0xDDA12A),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        }

        static let green = Color(hex: 0x04BA74)
        static let red = Color(hex: 0xE83F3F)
        static let redSoft = Color(hex: 0xE83F3F).opacity(0.06)

        static let cardShadow = Color.black.opacity(0.08)
    }

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let pill: CGFloat = 999
        static let phone: CGFloat = 50
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 22
        static let xxl: CGFloat = 28
    }

    enum Motion {
        static let snap = Animation.spring(response: 0.32, dampingFraction: 0.78)
        static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.82)
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.65)
        static let quick = Animation.easeOut(duration: 0.18)
    }
}

/// Frosted-glass background for emoji tiles (Where-it-Went rows, GoalTile).
/// Uses ultraThinMaterial plus a faint white wash and hairline highlight so
/// the underlying card shows through and the emoji reads as the focal point.
struct GlassTile: View {
    var cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.white.opacity(0.22))
            shape.stroke(Color.white.opacity(0.55), lineWidth: 0.6)
            shape.strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
