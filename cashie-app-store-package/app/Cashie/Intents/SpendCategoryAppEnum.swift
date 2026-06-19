import AppIntents

/// Shortcuts-pickable mirror of `SpendCategory`. Kept separate so the data model
/// (`Transaction.swift`) stays free of the AppIntents framework. Maps 1:1 by
/// raw value, so the two never drift.
@available(iOS 16.0, *)
enum SpendCategoryAppEnum: String, AppEnum {
    case food, transport, shopping, fun, home, health, bills, income, other

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    static var caseDisplayRepresentations: [SpendCategoryAppEnum: DisplayRepresentation] = [
        .food: "Food & Drinks",
        .transport: "Transport",
        .shopping: "Shopping",
        .fun: "Fun",
        .home: "Home",
        .health: "Health",
        .bills: "Bills",
        .income: "Income",
        .other: "Other"
    ]

    /// The data-model category this maps to.
    var model: SpendCategory { SpendCategory(rawValue: rawValue) ?? .other }

    init(_ category: SpendCategory) {
        self = SpendCategoryAppEnum(rawValue: category.rawValue) ?? .other
    }
}
