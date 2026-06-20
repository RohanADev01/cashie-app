import SwiftUI

enum Theme {
    enum Palette {
        static let bg = Color(hex: 0xFAFAFA)
        static let bgWarm = Color(hex: 0xF2F3F5)
        static let bgCream = Color(hex: 0xF4F5F7)
        static let phoneBg = Color(hex: 0xEAECEE)

        /// Light, airy page backdrop. Every main screen sits on the
        /// `Theme.pageBackground` gradient (top -> bottom); kept very close to
        /// white with only the faintest warm settle at the bottom so the
        /// floating `softCard` surfaces lift on their shadow without the page
        /// ever reading as grey/dull.
        static let pageTop = Color(hex: 0xFFFFFF)
        static let pageBottom = Color(hex: 0xFBFAF8)

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

        /// Streak / energy orange (the flame accent). A warm orange that pairs
        /// with the brand mint and the honey win-gold without clashing.
        static let streak = Color(hex: 0xFF7A3C)
        static let streakPastel = Color(hex: 0xFFF1E8)

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

/// Flat "paper" background for emoji tiles (Where-it-Went rows, GoalTile,
/// transaction rows). A solid cream swatch with a hairline border, no blur or
/// gloss, so tiles read as clean flat paper and stay consistent on every light
/// surface across the app. (Name kept for the many existing call sites.)
struct GlassTile: View {
    var cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(Theme.Palette.bgCream)
            .overlay(shape.stroke(Theme.Palette.line.opacity(0.7), lineWidth: 1))
    }
}

extension Theme {
    /// The app's standard page backdrop: a soft warm near-white vertical
    /// gradient. Every main screen sits on this so the floating `softCard`
    /// surfaces read as paper lifting off the page.
    static var pageBackground: LinearGradient {
        LinearGradient(
            colors: [Palette.pageTop, Palette.pageBottom],
            startPoint: .top, endPoint: .bottom
        )
    }
}

extension View {
    /// The app's standard card: a white floating surface with a soft layered
    /// shadow and no hairline border. Apply to content that already carries its
    /// own internal padding. This is the single card treatment shared by every
    /// screen so the whole app reads as one family.
    func softCard(_ cornerRadius: CGFloat = 18) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 9)
            .shadow(color: Color.black.opacity(0.025), radius: 2, x: 0, y: 1)
    }
}

/// Small brand-green action chip used for the secondary "jump" links on cards
/// (Set budgets, This month, …). A soft mint capsule with green label and a
/// trailing arrow, so the affordance reads as a real button that belongs to the
/// theme rather than a bare run of uppercase text. Purely visual: the parent
/// row/card owns the tap.
struct PillLink: View {
    let title: String
    var icon: String = "arrow.right"

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(AppFont.text(11, weight: .semibold))
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(Theme.Palette.gold)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.Palette.goldPastel))
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
