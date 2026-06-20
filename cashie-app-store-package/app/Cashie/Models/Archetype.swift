import Foundation

enum ArchetypeID: String, CaseIterable, Codable, Sendable {
    case planner
    case yolo
    case avoider
    case cautious
    case balanced
    case optimiser
}

struct Archetype: Identifiable, Codable, Hashable {
    var id: ArchetypeID
    var name: String
    var emoji: String
    var tagline: String
    var description: String
    var painYearly: Double
    var matchPercent: Int
    /// People we've seen with this archetype, used as the social-proof
    /// number across reveal, archetype sheet and 12-month-later screen.
    /// Skewed by real-world likelihood and pre-allocated so the figures
    /// stay consistent everywhere they show up. Sums to 50,000 across all
    /// six archetypes; one (optimiser) sits below the 5,000 floor because
    /// real-life optimisers are genuinely rarer than the rest.
    var population: Int

    /// "13.4k" / "5.3k" — keeps the number compact in tight UI without
    /// rounding away the per-archetype variation.
    var populationLabel: String {
        let value = Double(population) / 1000.0
        if value >= 10 {
            return String(format: "%.1fk", value)
        }
        return String(format: "%.1fk", value)
    }

    static let all: [Archetype] = [
        Archetype(
            id: .planner,
            name: "Steady Planner",
            emoji: "🛡",
            tagline: "Money is a tool. You like a system.",
            description: "You don't gamble with your future. You build it line by line.",
            painYearly: 1100,
            matchPercent: 97,
            population: 5300
        ),
        Archetype(
            id: .yolo,
            name: "YOLO Spender",
            emoji: "🪽",
            tagline: "Lives now, pays later, memories over money.",
            description: "You don't want to budget, you want to know when to actually stop.",
            painYearly: 4860,
            matchPercent: 96,
            population: 11200
        ),
        Archetype(
            id: .avoider,
            name: "Money Avoider",
            emoji: "🙈",
            tagline: "If I don't look, it's not real.",
            description: "Closing the app won't make the leak stop. Naming it will.",
            painYearly: 3200,
            matchPercent: 96,
            population: 9300
        ),
        Archetype(
            id: .cautious,
            name: "Cautious Saver",
            emoji: "🧘",
            tagline: "Better safe than spent.",
            description: "You hold tight, you just need a system that gives you permission to enjoy.",
            painYearly: 600,
            matchPercent: 96,
            population: 7600
        ),
        Archetype(
            id: .balanced,
            name: "Balanced Spender",
            emoji: "🤝",
            tagline: "Knows enough, acts most of the time.",
            description: "You're close. Cashie hands you the last 20%.",
            painYearly: 1700,
            matchPercent: 96,
            population: 13400
        ),
        Archetype(
            id: .optimiser,
            name: "Numbers Optimiser",
            emoji: "🧠",
            tagline: "Numbers are a sport.",
            description: "You'll love what the data shows you.",
            painYearly: 900,
            matchPercent: 98,
            population: 3200
        ),
    ]

    /// Social-proof figure shown on the loading screen ("Cross-referencing Xk
    /// profiles"). Set independently of the per-archetype `population`
    /// allocation (which sums to 50k for the per-type "others like you" lines)
    /// so the headline number can read bigger without reshuffling those.
    static var totalPopulationLabel: String { "100k" }

    static let `default` = all.first(where: { $0.id == .yolo })!

    static func by(id: ArchetypeID) -> Archetype {
        all.first(where: { $0.id == id }) ?? .default
    }
}
