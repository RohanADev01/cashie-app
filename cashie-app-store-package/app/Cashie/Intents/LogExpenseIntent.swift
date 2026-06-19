import AppIntents
import Foundation

/// Logs a spend to Cashie WITHOUT opening the app (`openAppWhenRun = false`).
/// This is the TapSheet-style "tap and it's logged" path: assign it to Back Tap,
/// the Action Button, an NFC automation, or run it by voice with Siri. It writes
/// through `QuickLogWriter` (durable local + sync outbox), never `AppContainer`.
@available(iOS 16.0, *)
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Log a spend to Cashie without opening the app.")
    static var openAppWhenRun = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Category", default: .other)
    var category: SpendCategoryAppEnum

    @Parameter(title: "Name")
    var merchant: String?

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) for \(\.$category)") {
            \.$merchant
            \.$note
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let cat = category.model
        let trimmedMerchant = merchant?.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = (trimmedMerchant?.isEmpty == false ? trimmedMerchant : nil)
            ?? QuickLogWriter.defaultMerchant(for: cat)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        let tx = Transaction(
            merchant: label,
            amount: amount,
            category: cat,
            date: Date(),
            note: (trimmedNote?.isEmpty == false ? trimmedNote : nil),
            source: .quicklog
        )
        await QuickLogWriter.shared.write(tx)

        let cents = amount.truncatingRemainder(dividingBy: 1) != 0
        return .result(dialog: "Logged \(Money.format(amount, cents: cents)) to \(cat.label).")
    }
}
