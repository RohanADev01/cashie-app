import Foundation

enum TraitID: String, CaseIterable, Codable, Sendable {
    case impulse
    case planning
    case awareness
    case security
    case enjoyment

    var label: String {
        switch self {
        case .impulse: return "Impulse"
        case .planning: return "Planning"
        case .awareness: return "Awareness"
        case .security: return "Security"
        case .enjoyment: return "Enjoyment"
        }
    }
}

struct Trait: Identifiable, Codable, Hashable {
    var id: TraitID { trait }
    var trait: TraitID
    /// 0...100
    var score: Int
    var blurb: String

    /// Fallback trait scores, shown when a user hasn't completed the quiz yet
    /// (e.g. before onboarding finishes), so the archetype stats card always has
    /// something to render instead of being hidden.
    static let defaults: [Trait] = [
        Trait(trait: .impulse, score: 78, blurb: "Decisions land fast. We'll add a small pause."),
        Trait(trait: .planning, score: 42, blurb: "Plans exist, mostly. Cashie fills the gaps."),
        Trait(trait: .awareness, score: 56, blurb: "You glance, but the whole picture is missing."),
        Trait(trait: .security, score: 48, blurb: "A buffer would feel good. We'll suggest one."),
        Trait(trait: .enjoyment, score: 71, blurb: "Money is for living. We'll show you the safe yes."),
    ]
}
