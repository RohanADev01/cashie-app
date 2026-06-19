import SwiftUI

/// Game-style progression ranks, ordered low to high. A user's rank is
/// derived from cumulative XP (see `AppContainer.rankXP`), so it only ever
/// climbs as they keep logging and saving. We never demote, which keeps the
/// reward loop from punishing a quiet week. The point is to give people a
/// reason to come back and log whenever they spend, not to chase a daily
/// streak.
enum Rank: Int, CaseIterable, Identifiable, Comparable {
    case bronze
    case silver
    case gold
    case emerald
    case diamond
    case master
    case legendary

    var id: Int { rawValue }

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    // MARK: - XP economy
    //
    // All rank XP comes from unlocking badges (see `Badge.all` and
    // `AppContainer.rankXP`). The badge catalog totals well above the
    // Legendary threshold and is finely tiered, so XP only ever accumulates
    // and there's always a next badge to chase. Pace is tuned via badge
    // *targets* (how much you must do), calibrated to ~3-4 logs/week, not by
    // changing XP or these thresholds.

    /// Total XP required to *hold* this rank. The gaps widen on purpose so
    /// the early climb feels fast and the top tiers feel earned.
    var threshold: Int {
        switch self {
        case .bronze:    return 0
        case .silver:    return 250
        case .gold:      return 700
        case .emerald:   return 1500
        case .diamond:   return 2800
        case .master:    return 4600
        case .legendary: return 7000
        }
    }

    var title: String {
        switch self {
        case .bronze:    return "Bronze"
        case .silver:    return "Silver"
        case .gold:      return "Gold"
        case .emerald:   return "Emerald"
        case .diamond:   return "Diamond"
        case .master:    return "Master"
        case .legendary: return "Legendary"
        }
    }

    /// One-line flavour shown under the rank title.
    var tagline: String {
        switch self {
        case .bronze:    return "You've started. Every log counts."
        case .silver:    return "Building the habit, one log at a time."
        case .gold:      return "Consistent. Your money has a rhythm now."
        case .emerald:   return "Rare form. You're in the green and staying there."
        case .diamond:   return "Elite. Saving is second nature."
        case .master:    return "Mastery. You run the budget, not the other way."
        case .legendary: return "Legend. The top of the mountain."
        }
    }

    /// Asset catalog name for the optional Gemini-generated badge art. If the
    /// image is missing (or an empty placeholder), `RankBadgeView` falls back
    /// to a procedurally drawn medallion, so the app always looks finished.
    var assetName: String {
        switch self {
        case .bronze:    return "RankBronze"
        case .silver:    return "RankSilver"
        case .gold:      return "RankGold"
        case .emerald:   return "RankEmerald"
        case .diamond:   return "RankDiamond"
        case .master:    return "RankMaster"
        case .legendary: return "RankLegendary"
        }
    }

    /// SF Symbol used inside the procedural medallion fallback.
    var symbol: String {
        switch self {
        case .bronze:    return "shield.fill"
        case .silver:    return "shield.lefthalf.filled"
        case .gold:      return "trophy.fill"
        case .emerald:   return "hexagon.fill"
        case .diamond:   return "diamond.fill"
        case .master:    return "crown.fill"
        case .legendary: return "flame.fill"
        }
    }

    // MARK: - Palette
    //
    // Each rank carries a 3-stop metallic gradient (highlight, midtone,
    // shadow) plus a glow used by the aura and particles. Tuned to read as
    // polished metal / gemstone rather than flat colour.

    var highlight: Color { Color(hex: style.0) }
    var midtone: Color { Color(hex: style.1) }
    var shadow: Color { Color(hex: style.2) }
    var glow: Color { Color(hex: style.3) }

    private var style: (UInt32, UInt32, UInt32, UInt32) {
        switch self {
        // highlight,  midtone,   shadow,    glow
        case .bronze:    return (0xF3C49A, 0xB87333, 0x5E3416, 0xC97B36)
        case .silver:    return (0xFFFFFF, 0xC2C9D4, 0x767E8C, 0xAFC0D6)
        case .gold:      return (0xFFF1C0, 0xF2BE3C, 0xB07A12, 0xF6CB48)
        case .emerald:   return (0xC9FFE3, 0x18C07A, 0x0B5E3C, 0x3BE89B)
        case .diamond:   return (0xEAFCFF, 0x6FE0F2, 0x1F8FB8, 0x49D6F0)
        case .master:    return (0xF0D6FF, 0x9B5BE0, 0x4E2294, 0xA86BF0)
        case .legendary: return (0xFFE7A8, 0xFF8A3D, 0xD21F2A, 0xFF6A33)
        }
    }

    var gradientStops: [Color] { [highlight, midtone, shadow] }

    /// Colours the floating particles cycle through behind the badge.
    var particleColors: [Color] {
        switch self {
        case .legendary: return [Color(hex: 0xFFE7A8), Color(hex: 0xFF8A3D), Color(hex: 0xFF4D4D), Color(hex: 0xFFD36B)]
        case .diamond:   return [Color(hex: 0xEAFCFF), Color(hex: 0x9CEEFF), Color(hex: 0x49D6F0)]
        case .master:    return [Color(hex: 0xF0D6FF), Color(hex: 0xC79BFF), Color(hex: 0xA86BF0)]
        case .emerald:   return [Color(hex: 0xC9FFE3), Color(hex: 0x3BE89B), Color(hex: 0x18C07A)]
        default:         return [highlight, glow]
        }
    }

    /// Animation richness, 0...1, scaling particle count and shine speed.
    /// Higher tiers feel more alive.
    var intensity: Double {
        Double(rawValue) / Double(Rank.legendary.rawValue)
    }

    var next: Rank? { Rank(rawValue: rawValue + 1) }
    var isMax: Bool { next == nil }
}

/// A snapshot of where a user sits on the ladder. Built from raw XP via
/// `Rank.progress(forXP:)` so the home card, the ladder sheet and the
/// celebration all agree.
struct RankProgress {
    let xp: Int
    let current: Rank
    let next: Rank?
    /// 0...1 progress through the current tier toward the next one.
    let fraction: Double
    /// XP still needed to reach `next` (0 when maxed).
    let xpToNext: Int

    var isMaxed: Bool { next == nil }
}

extension Rank {
    static func progress(forXP xp: Int) -> RankProgress {
        let current = Rank.allCases.last { xp >= $0.threshold } ?? .bronze
        guard let next = current.next else {
            return RankProgress(xp: xp, current: current, next: nil, fraction: 1, xpToNext: 0)
        }
        let span = next.threshold - current.threshold
        let into = xp - current.threshold
        let fraction = span > 0 ? min(1, max(0, Double(into) / Double(span))) : 1
        return RankProgress(
            xp: xp,
            current: current,
            next: next,
            fraction: fraction,
            xpToNext: max(0, next.threshold - xp)
        )
    }
}
