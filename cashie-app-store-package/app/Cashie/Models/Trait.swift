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
}
