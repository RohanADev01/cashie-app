# Cashie — Feature & Edge Case Test Checklist

Generated end to end test pass over every feature and the edge cases that could
break the app. Where an edge case could crash or visually break, the logic was
fixed (see "Fixes applied"). Build status: **BUILD SUCCEEDED**. No crash logs
were produced across any test below.

**Legend**
- `[x]` verified working, or broken and now fixed + re-verified
- `[ ]` not exercised in this pass (needs a real device / sandbox account / live tap)

**How it was tested**
- Static read of every screen, modal and service (full feature + risk map).
- iPhone 15 Pro simulator runs with crafted on-disk store states (empty, zero
  budget, max-allowed values) and `-startAt` launches, screenshots checked, and
  `~/Library/Logs/DiagnosticReports` watched for crashes after every run.
- Tap-driven flows (opening sheets, typing, swipe-delete, purchase) were verified
  by reading the logic + the build. This environment has no tap-injection, so
  those are marked `[x]` on logic where the path is provably safe, and `[ ]`
  where a real device or account is required.

---

## 1. Launch, splash, session routing
- [x] Cold launch boots to splash, then routes correctly
- [x] First ever launch (no store) seeds sample data and goes to onboarding
- [x] Subscribed user routes straight to main
- [x] Previously reached paywall but not subscribed routes back to paywall
- [x] StoreKit entitlement check failure falls back to "not subscribed" (no crash)
- [x] Foreground re-checks entitlement; expired sub bounces main user to paywall
- [x] Dev launch args: `-resetStore`, `-resetPaywall`, `-resetSubscription`, `-startAt`, `-tab`, `-archetype`
- [x] `-tab spend|goals|you` jumps to the right tab (verified live)

## 2. Onboarding flow
- [x] Welcome screen renders; "Find my money type" and "I already have an account"
- [ ] Sign in with Apple (needs a real device / Apple ID; canceled error handled in code)
- [x] Continue without account routes to name input
- [x] Relatability multi-select chips; can continue with zero or many selected
- [x] Intro screen and 5 dot progress
- [x] Quiz renders Q1..Q5; back button; auto-advance Q1..Q4; explicit submit on Q5
- [x] Quiz with all same answers / minimal answers still scores an archetype (scores clamped 0..100)
- [x] Loading screen sequence, then reveal
- [x] Reveal screen progressive beats render (match %, yearly leak, population)
- [x] Traits screen: 5 trait bars (scores clamped 0..100 so bars never overflow)
- [x] Pain, Solution, Effort, Social proof, Reviews, Contrast screens render
- [x] Reviews triggers native review prompt once
- [x] Paywall renders monthly + yearly at full price (yearly preselected), NO auto-discount; exit-intent rescue offers ($35.88 then $23.88) surface only on "Maybe later"/backgrounding, then lock
- [x] Paywall with empty offerings falls back to a synthetic option (no crash)
- [x] Name input: empty / whitespace-only keeps Save disabled
- [x] **Name input: very long pasted name is now capped at 40 chars (was a layout risk)**

## 3. Setup flow
- [x] Welcome-in confetti screen
- [x] Permissions screen toggles persist to user
- [x] Back-tap teaser + setup, action-button setup (Open Settings links guarded)
- [x] Try-it-live demo log via Quick Log body
- [x] Ready screen, "Open Cashie" finalizes and enters main

## 4. Main: Today tab
- [x] Greeting falls back to "Hey there." when no name
- [x] Rank hero card renders progress (fraction clamped 0..1)
- [x] Safe to spend hero + daily pace
- [x] Month flow strip (in / out / net) hides on empty month
- [x] This week tracker bar + streak pill (progress clamped, cap=0 guarded)
- [x] "Where it went" top categories + empty state ("Nothing logged yet")
- [x] Month over month footer note (guarded against divide by zero baseline)
- [x] Rank-up and badge-unlock celebration overlays queue correctly
- [x] Long-press mascot opens Home Design Lab variant carousel (renders, no crash)
- [x] **Empty state (no data, zero budget): renders cleanly, no NaN crash** (UI verified)

## 5. Main: Spend tab
- [x] "Spent this month" total + cents
- [x] Month pager (prev/next, next disabled at current month)
- [x] Cumulative spend chart (empty = flat baseline; large value scales; no NaN)
- [x] Transactions grouped by day with running totals
- [x] Over / under budget label
- [x] **Empty state renders (flat chart, $0)** (UI verified)
- [x] **Large finite transaction ($999,999) renders, chart + list OK** (UI verified)

## 6. Main: Goals tab
- [x] Hero tracker (% funded, count, saved vs target, next deadline)
- [x] Active goals list with progress bars + weekly pace
- [x] Empty state ("Nothing here yet", "Start a new goal")
- [x] Past wins entry
- [x] Goal funded celebration triggers on crossing 100%
- [x] **Goal at max allowed target ($999,999,999): renders, pace math no overflow** (UI verified)
- [x] Tracker progress guarded (target=0 returns 0, no NaN width)

## 7. Main: You tab
- [x] Archetype card (tap to re-show reveal)
- [x] Weekly wrapped card; streak card
- [x] 2x2 stat grid (total saved, months active, wrappeds seen, goals active)
- [x] Settings rows: Badges, Wrapped, Quick Log, Notifications, Privacy, Subscription, Help
- [x] Subscription row routes to paywall (free) or Today (paid)
- [x] **Empty state: "No streak yet", $0 saved, 0 goals (no crash)** (UI verified)

## 8. Logging (Quick Log + Add Transaction)
- [x] Quick Log keypad: digits + single decimal, 8 char cap (finite by construction)
- [x] Quick Log requires amount > 0; merchant defaults when blank
- [x] Income mode (different chips, income category)
- [x] **Add Transaction: amount parsing now rejects 0, negative, non-finite (`inf`/`nan`/`1e400`), and > $1B**
- [x] **Add Transaction: merchant + note trimmed; whitespace-only merchant rejected**
- [ ] Live tap-through of Quick Log / Add Transaction sheets (no tap-injection here; logic verified)

## 9. Goals (Add / Edit / Detail / Deposits)
- [x] **Add Goal: target parsing rejects 0, negative, non-finite, and > $1B (was a crash via `Int(weekly)` / `Money.format`)**
- [x] Add Goal: name + emoji trimmed and required; target date must be in the future
- [x] Add Goal pace card no longer crashes on bad target (parses safely to 0)
- [x] Emoji input sanitized to a single emoji, reverts to last valid
- [x] **Edit Goal: target parsing hardened; cannot drop below already-deposited amount**
- [x] Edit Goal: editing a past win below 100% un-archives it
- [x] Goal Detail: progress ring (target=0 -> 0, no bad trim)
- [x] **Deposit: amount parsing hardened; 0 / non-finite disables Add**
- [x] Deposit capped at remaining headroom (never overshoots target)
- [x] Remove deposit drops current amount and clears stale celebration
- [x] Archive / unarchive (move to Past wins, restore)
- [x] Delete goal (confirmation dialog)
- [ ] Live tap-through of goal sheets (logic verified; no tap-injection here)

## 10. Budgets
- [x] Budgets sheet: per-category sliders (0..1500), total cap + daily rate
- [x] **All caps = 0: Today/Spend/streak all stay safe (guarded), UI verified via empty state**
- [x] Category detail sheet: edit cap (50..1500), progress bar (cap=0 guarded)
- [x] Set budget creates or updates the category cap

## 11. Other modals / sheets
- [x] Transaction detail: budget impact %, insights, delete (all denominators guarded)
- [x] Month breakdown: category grid + savings rows (monthTotal=0 guarded)
- [x] Wrapped sheet: weekly summary, share image render (guarded; nil image hides share)
- [x] Wrapped category movement (`(now-prev)/prev`) guarded by `prev >= 20` baseline
- [x] Badges sheet + badge detail (Badge.all is a fixed non-empty catalog)
- [x] Badge unlocked celebration
- [x] Ranks ladder carousel + rank-up celebration (particle palettes always non-empty)
- [x] Past wins sheet (empty state, restore, totals)
- [x] Archetype sheet (trait bars)
- [x] Notifications sheet (Today / Earlier groups, mark read, empty handled)
- [x] Privacy sheet (lock toggle, CSV export share)
- [x] Reminder sheet (daily reminder toggle + time picker; hour/minute always valid via picker)
- [x] Subscription sheet (status, manage, restore)

## 12. Services
- [x] Local store: JSON per collection, atomic writes, first-run seed, wipe
- [x] CSV export: RFC 4180 escaping for commas / quotes / newlines; empty list = header only
- [x] Reminder scheduler: idempotent sync, no-op when permission denied
- [x] Privacy lock: locks on background, unlock on foreground, simulator passthrough
- [ ] Privacy lock with real Face ID success/failure (needs a real device; passcode fallback in code)
- [x] Money formatter: **now returns "$0" for NaN/Inf instead of crashing on `Int(value)`**
- [ ] Real StoreKit purchase / restore (needs sandbox account or Xcode run with `Cashie.storekit`; DEBUG simulates success when products absent)
- [x] Native StoreKit 2 is the only purchase backend (no RevenueCat SDK; binary links no third-party framework)

## 13. Cross cutting edge cases (the "does it break" set)
- [x] **Non-finite numeric input (`inf`, `nan`, `1e400`) cannot enter the data model** (root cause of the crash class; blocked at every amount/target/deposit field)
- [x] **`Money.format` is non-finite safe** (app-wide last line of defense)
- [x] Values bounded to <= $1B so every `Int(...)` conversion stays within Int64
- [x] Empty transactions / goals / notifications / budgets: all four tabs render (UI verified)
- [x] Zero budgets everywhere: no divide-by-zero / NaN reaches a layout modifier (UI verified)
- [x] Maximum allowed values render without overflow (UI verified)
- [x] Deleting the last item leaves a valid empty state
- [x] Goal progress / category bars clamp to 0..1 (no negative or > 1 widths)
- [x] Force-unwraps audited: all are on constants or guarded (safe)

---

## Fixes applied (logic changes)
1. **`DesignSystem/Tokens.swift`** — `Money.format` now short-circuits non-finite
   values to `"$0"` (the old `?? "$\(Int(value))"` fallback was a fatal crash for
   NaN/Inf). Added `Money.parseAmount(_:)`, a single safe parser that accepts only
   finite, positive amounts up to $1,000,000,000.
2. **`Modals/AddTransactionSheet.swift`** — amount goes through `parseAmount`
   (rejects 0, negative, non-finite, oversized); merchant and note are trimmed,
   whitespace-only merchant rejected.
3. **`Modals/AddGoalSheet.swift`** — target goes through `parseAmount` in
   `canSave`, `save`, and the pace card (which used to `Int(weekly)` an infinite
   value); name and emoji trimmed on save.
4. **`Modals/EditGoalSheet.swift`** — target parsing hardened in `canSave`,
   `belowDepositedFloor`, and `save`.
5. **`Modals/GoalDetailSheet.swift`** — deposit amount parsing hardened (Add
   button disabled for invalid / non-finite input).
6. **`Onboarding/NameInputScreen.swift`** — stored first name capped at 40 chars
   so a pasted wall of text cannot break the greeting layout.

These are centralized and simple: one parser (`Money.parseAmount`) reused at every
numeric boundary, plus one defensive formatter. Together they close the entire
reachable crash class (non-finite / oversized numbers flowing into `Int(...)` and
`.frame`/`.trim`).

## Not done / needs a real device or account
- Sign in with Apple end to end
- Real Face ID / passcode unlock behavior
- Real StoreKit purchase and restore (Apple's purchase sheet; sandbox/device or Xcode run with the bundled `.storekit`)
- Live device back-tap / action-button Quick Log automation
- Live tap-through of sheets that require typing (verified by logic + build instead)
