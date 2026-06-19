# Main app

Four tabs + a floating "+" button that opens Quick Log:

- `TodayTab`, safe-to-spend hero, weekly category breakdown, goals in flight.
- `SpendTab`, month/week toggle, spark chart, transaction list grouped by day.
- `GoalsTab`, overview + tile per goal; tap opens `GoalDetailSheet`.
- `YouTab`, profile, streak, stat grid, settings list.

`MainTabsView.swift` owns the tab state + the floating action button.
The "+" launches `QuickLogSheet`. Long-tap or shake also opens it (dev).

## Adding a new tab

Add a case to `MainTab`, render it in the switch, and add a tab item in
`TabBar`. Try not to add a 5th tab, the floating "+" assumes 4-up layout.
