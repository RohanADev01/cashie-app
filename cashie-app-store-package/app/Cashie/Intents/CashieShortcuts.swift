import AppIntents

/// Publishes Cashie's intents to the Shortcuts app and Siri automatically at
/// install, with natural-language phrases. No user setup needed to see these in
/// Shortcuts or to assign them to Back Tap / the Action Button. Every phrase
/// must include `\(.applicationName)`.
@available(iOS 16.0, *)
struct CashieShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log a spend in \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "Add a spend to \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: OpenQuickLogIntent(),
            phrases: [
                "Open Quick Log in \(.applicationName)",
                "Quick log in \(.applicationName)"
            ],
            shortTitle: "Quick Log",
            systemImageName: "bolt.fill"
        )
    }
}
