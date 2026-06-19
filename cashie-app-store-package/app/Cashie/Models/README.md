# Models

Pure data, no SwiftUI imports.

- `User` (`CashieUser`), local copy of the user profile.
- `Archetype`, 6 fixed money types + canonical pain numbers.
- `Trait`, five-axis personality scoring (Impulse, Planning, Awareness,
  Security, Enjoyment), 0–100.
- `Quiz`, 5 questions with score deltas; `QuizScorer.score(answers:)`
  returns `(Archetype, [Trait])`.
- `Transaction`, single spend or income event.
- `Goal` + `Deposit`, savings goal model.
- `AppNotification`, in-app nudge feed.

## Archetype + scoring

`QuizScorer` is intentionally simple. Each option contributes deltas to one
or more traits; final scores are clamped to 0–100; the archetype is picked
by threshold rules in `pickArchetype`. To re-tune: edit `QuizBank.questions`
or the threshold rules, no other file needs to change.

## Adding fields

When the schema in `Cashie/Services/Integration.md` adds a column, add the
matching property here, then update `MockSupabaseService` + the live
implementation. Keep models `Codable` + `Hashable`.
