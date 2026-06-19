import Foundation

struct CashieUser: Codable, Hashable {
    var id: UUID = UUID()
    /// Empty until the user optionally types a name in NameInputScreen.
    /// All UI that greets the user must check `hasName` before rendering.
    var firstName: String = ""
    var email: String?
    var archetype: Archetype = .default
    var traits: [Trait] = []
    var hasFaceID: Bool = true
    var hasNotifications: Bool = true
    var quickLogSetup: Bool = false

    /// Marketing snapshot captured once at quiz completion: the option id chosen
    /// for each quiz question (keyed by question number as a string) and the
    /// relatability chips the user selected. Synced to `profiles` for analysis;
    /// not used for app logic.
    var quizAnswers: [String: String] = [:]
    var relatabilityChips: [String] = []

    /// True when we have a real first name. Greeting UIs that interpolate the
    /// name should fall back to a non-personalised line when this is false.
    var hasName: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
