import Foundation

struct AppNotification: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var emoji: String
    var title: String
    var body: String
    var date: Date
    var isUnread: Bool = true
    var kind: Kind

    enum Kind: String, Codable, Hashable, Sendable {
        case goal
        case streak
        case budget
        case wrapped
        case insight
        case milestone
    }
}
