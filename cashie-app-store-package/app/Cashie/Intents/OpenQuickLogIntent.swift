import AppIntents

/// Opens Cashie to the Quick Log sheet (`openAppWhenRun = true`), optionally
/// prefilled. For users who want to see and adjust the entry before saving
/// (e.g. after an Apple Pay tap they confirm the amount). Routes through
/// `QuickLogLaunch`, which `RootView` observes to present the sheet.
@available(iOS 16.0, *)
struct OpenQuickLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Quick Log"
    static var description = IntentDescription("Open Cashie's Quick Log sheet, optionally prefilled.")
    static var openAppWhenRun = true

    @Parameter(title: "Amount")
    var amount: Double?

    @Parameter(title: "Category")
    var category: SpendCategoryAppEnum?

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickLogLaunch.shared.pending = QuickLogPrefill(
            amount: amount,
            category: category?.model
        )
        return .result()
    }
}
