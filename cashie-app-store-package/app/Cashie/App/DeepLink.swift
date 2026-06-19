import SwiftUI

/// Values a Quick Log entry can be opened with, whether the trigger is a
/// `cashie://` deep link, an App Intent, or the in-app FAB. All optional so an
/// empty prefill just opens a blank Quick Log sheet.
struct QuickLogPrefill: Equatable {
    var amount: Double? = nil
    var category: SpendCategory? = nil
    var merchant: String? = nil
    var note: String? = nil
    /// When true the sheet logs the entry immediately on appear instead of
    /// waiting for the user to confirm. Only set by an explicit `autosave=1`.
    var autosave: Bool = false
}

/// Parses `cashie://` URLs that iOS Shortcuts (Back Tap, Action Button, NFC,
/// Siri) or any deep link can send the app. Returns nil for anything we don't
/// recognise so unrelated URLs are ignored.
enum DeepLink {
    static func parse(_ url: URL) -> QuickLogPrefill? {
        guard url.scheme?.lowercased() == "cashie" else { return nil }
        switch url.host {
        case "quick-log":
            return QuickLogPrefill()
        case "add-expense":
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
            return QuickLogPrefill(
                amount: value("amount").flatMap(Money.parseAmount),
                category: value("category").flatMap { SpendCategory(rawValue: $0.lowercased()) },
                merchant: value("merchant"),
                note: value("note"),
                autosave: value("autosave") == "1"
            )
        default:
            return nil
        }
    }
}

/// Bridges an App Intent that opens the app (`OpenQuickLogIntent`) to the live
/// SwiftUI hierarchy. The intent runs in-process, sets `pending`, and `RootView`
/// observes it to present the Quick Log sheet.
@MainActor
final class QuickLogLaunch: ObservableObject {
    static let shared = QuickLogLaunch()
    @Published var pending: QuickLogPrefill?
    private init() {}
}
