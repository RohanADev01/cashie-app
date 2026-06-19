import Foundation

struct QuizQuestion: Identifiable, Hashable {
    var id: Int
    var kicker: String
    var prompt: String
    var helper: String
    var options: [QuizOption]
}

struct QuizOption: Identifiable, Hashable {
    var id: String
    var main: String
    /// Score deltas applied to traits when chosen.
    var deltas: [TraitID: Int]
}

enum QuizBank {
    static let questions: [QuizQuestion] = [
        QuizQuestion(
            id: 1,
            kicker: "Question 01 / 05",
            prompt: "You get paid. <em>What happens first?</em>",
            helper: "Pick what's closest.",
            options: [
                .init(id: "1d", main: "I have no real routine",
                      deltas: [.awareness: 10]),
                .init(id: "1c", main: "I spend now, sort it later",
                      deltas: [.impulse: 25, .planning: -10]),
                .init(id: "1b", main: "I treat myself first",
                      deltas: [.enjoyment: 20, .impulse: 10]),
                .init(id: "1a", main: "I cover bills and savings",
                      deltas: [.planning: 20, .security: 20]),
            ]
        ),
        QuizQuestion(
            id: 2,
            kicker: "Question 02 / 05",
            prompt: "You spot something you <em>didn't plan to buy.</em>",
            helper: "Pick what's closest.",
            options: [
                .init(id: "2a", main: "I buy it right away",
                      deltas: [.impulse: 25]),
                .init(id: "2b", main: "I wait a day and decide",
                      deltas: [.awareness: 10]),
                .init(id: "2c", main: "I check if it fits my budget",
                      deltas: [.planning: 20]),
                .init(id: "2d", main: "I walk away; I rarely splurge",
                      deltas: [.impulse: -10]),
            ]
        ),
        QuizQuestion(
            id: 3,
            kicker: "Question 03 / 05",
            prompt: "How often do you <em>check your balance?</em>",
            helper: "Pick what's closest.",
            options: [
                .init(id: "3d", main: "Almost never",
                      deltas: [.awareness: -20]),
                .init(id: "3c", main: "Only when it feels low",
                      deltas: [.awareness: 5]),
                .init(id: "3b", main: "About once a week",
                      deltas: [.awareness: 15]),
                .init(id: "3a", main: "Every day",
                      deltas: [.awareness: 25]),
            ]
        ),
        QuizQuestion(
            id: 4,
            kicker: "Question 04 / 05",
            prompt: "Do you have <em>a savings goal?</em>",
            helper: "Pick what's closest.",
            options: [
                .init(id: "4d", main: "Not yet",
                      deltas: [.planning: -15]),
                .init(id: "4c", main: "I save whatever is left",
                      deltas: [:]),
                .init(id: "4b", main: "Sort of, but no deadline",
                      deltas: [.planning: 10]),
                .init(id: "4a", main: "Yes, with a target date",
                      deltas: [.planning: 25, .security: 20]),
            ]
        ),
        QuizQuestion(
            id: 5,
            kicker: "Question 05 / 05",
            prompt: "End of the month, <em>how do you feel?</em>",
            helper: "Pick what's closest.",
            options: [
                .init(id: "5a", main: "I'm unsure where it went",
                      deltas: [.impulse: 20, .awareness: -10]),
                .init(id: "5d", main: "Glad I made it through",
                      deltas: [.awareness: 10]),
                .init(id: "5b", main: "Good, no regrets",
                      deltas: [.enjoyment: 20]),
                .init(id: "5c", main: "In control, mostly",
                      deltas: [.planning: 20, .awareness: 10]),
            ]
        ),
    ]
}

enum QuizScorer {
    /// Returns the user's archetype + traits given selected option IDs.
    static func score(answers: [String]) -> (Archetype, [Trait]) {
        var totals: [TraitID: Int] = [:]
        for id in TraitID.allCases { totals[id] = 50 }    // start neutral
        for opt in answers.compactMap(option(for:)) {
            for (k, v) in opt.deltas {
                totals[k, default: 50] += v
            }
        }
        // Clamp to 0...100
        let traits = TraitID.allCases.map { id -> Trait in
            let v = max(0, min(100, totals[id] ?? 50))
            return Trait(trait: id, score: v, blurb: blurb(id, score: v))
        }
        let archetype = pickArchetype(traits)
        return (archetype, traits)
    }

    private static func option(for id: String) -> QuizOption? {
        for q in QuizBank.questions {
            if let o = q.options.first(where: { $0.id == id }) { return o }
        }
        return nil
    }

    private static func pickArchetype(_ traits: [Trait]) -> Archetype {
        let dict = Dictionary(uniqueKeysWithValues: traits.map { ($0.trait, $0.score) })
        let impulse = dict[.impulse] ?? 50
        let planning = dict[.planning] ?? 50
        let awareness = dict[.awareness] ?? 50
        let security = dict[.security] ?? 50
        let enjoyment = dict[.enjoyment] ?? 50

        if impulse >= 70 && planning <= 50 { return Archetype.by(id: .yolo) }
        if awareness <= 35 { return Archetype.by(id: .avoider) }
        if planning >= 70 && security >= 60 { return Archetype.by(id: .planner) }
        if security >= 70 && enjoyment <= 45 { return Archetype.by(id: .cautious) }
        if planning >= 60 && awareness >= 60 { return Archetype.by(id: .optimiser) }
        return Archetype.by(id: .balanced)
    }

    private static func blurb(_ id: TraitID, score: Int) -> String {
        switch id {
        case .impulse:
            if score >= 70 { return "Decisions land in under 8 seconds. We'll add a pause." }
            if score <= 30 { return "Cool head, you rarely get caught out." }
            return "Comfortable speed. We'll surface the risky moments."
        case .planning:
            if score >= 70 { return "You like a system. We'll make it lighter." }
            if score <= 30 { return "Money slips when there's no plan. We'll script it." }
            return "Plans exist, mostly. Cashie fills the gaps."
        case .awareness:
            if score >= 70 { return "You watch closely. Cashie stops the watching." }
            if score <= 30 { return "You're flying blind. Naming it is half the fix." }
            return "You glance, but the whole picture is missing."
        case .security:
            if score >= 70 { return "You want a buffer. We'll keep one live." }
            if score <= 30 { return "Surprises hit hard. Let's pre-load a cushion." }
            return "A buffer would feel good. We'll suggest one."
        case .enjoyment:
            if score >= 70 { return "Money is for living. We'll show you the safe yes." }
            if score <= 30 { return "You're cautious, too cautious. Permission, granted." }
            return "Healthy mix of treat and discipline."
        }
    }
}
