# Design system

Three files, intentionally small:

- `Theme.swift`, color palette + corner radii + spring animations.
- `Typography.swift`, `AppFont.display(...)` and `AppFont.text(...)` with
  Barlow Condensed / Inter fallbacks. Token aliases (`displayXL`, `largeTitle`,
  `headline`, …) match the CSS tokens in the prototype 1-to-1.
- `Tokens.swift`, `PrimaryButton`, `GhostButton`, `Pill`, `BackBar`,
  `CashCard`, `EmphasizedHeadline` (parses `<em>...</em>` → italic gold span),
  `GoldBlob` decorative gradient, `Money` formatter.

## Adding new visual primitives

Put reusable controls here. Anything used on more than one screen should
move out of the screen file and into `Tokens.swift`.

## Italic-em pattern

Every screen with a "split" headline (italic gold phrase mid-sentence) uses:

```swift
EmphasizedHeadline(
    raw: "You're losing about <em>$4,860</em> a year.",
    font: AppFont.display(34, weight: .bold)
)
```

The `<em>...</em>` markers are extracted at runtime and rendered with the
gold accent color. Use sparingly, once per screen.
