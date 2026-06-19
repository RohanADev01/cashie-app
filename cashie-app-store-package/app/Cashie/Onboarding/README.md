# Onboarding flow

20 screens in scripted order:

```
Welcome → Relatability → Intro → Quiz x5 → Loading → Reveal →
  Traits → Pain → Solution → ValueDemo → Effort → SocialProof →
  Paywall → (purchase) → WelcomeIn (handled in Setup/)
```

The flow is driven by `OnboardingStep` cases on `AppContainer.session`.
Each screen calls `container.advanceOnboarding(to: .next)` to move forward.

`OnboardingHost.swift` is the dispatcher, it wires the right screen to the
current `step` and supplies a shared `OnboardingState` for in-flight quiz
answers + computed archetype.

## Skipping the flow during dev

Launch the app with `-startAt <step>` (see top-level `README.md`).
`OnboardingState` seeds default traits so reveal/traits/pain still render
even if the quiz wasn't completed.
