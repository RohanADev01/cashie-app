# Paywall compliance notes — Guideline 5.6 / 2.3.2

Reference doc for the Cashie paywall + pricing presentation, written so a future
submission can respond fast if App Review pushes back again. Last updated
2026-06-18.

---

## 1. The original rejection (what triggered all of this)

- **Submission ID:** `17683a00-f7de-43c0-aa87-5882e1795253`
- **Review date:** June 18, 2026 · Version 1.0 (1) · Reviewed on iPad Air 11" (M3)
- **Guideline 5.6 — Developer Code of Conduct:** "The app attempts to manipulate
  customers into making unwanted in-app purchases. Specifically, your app has a
  **secondary offer wall after the user declines the first.**"
- **Guideline 2.3.2 — Accurate Metadata:** the description referenced paid
  features without clearly stating a purchase is required.

The app is now under 5.6 scrutiny specifically on **offer walls**, so any future
re-review will look hard at the paywall. Bias every decision toward "obviously
one honest offer."

---

## 2. What we changed (the fix that shipped)

### 5.6 — removed the secondary offer wall
- Deleted the entire exit-intent "rescue" funnel from `Cashie/Onboarding/PaywallScreen.swift`:
  `RescueStage`, `RescueTier`, `RescueModal`, the `scenePhase` background/return
  detection, and the `-rescue` dev flag.
- The paywall is now **one screen**: a friendly **"We'd like to offer you 80% off!"**
  line introduces **two side-by-side plan cards** (Monthly $9.99, Yearly $23.88
  with SAVE 80% + the struck-through $119.88). Not a pop-up, not decline-triggered.
  (An earlier iteration used a single large green "hero card"; replaced with the
  two-card layout + offer line to keep the discount section modest.)
- Confetti celebrates the **first visit only** (gated on `paywallCelebrationShown`
  in UserDefaults). DEBUG: launch with `-offer reset` to replay it.
- **No** second surface, **no** "you won't see this again", **no** countdown.

### Pricing collapsed to two products
- Single yearly product `cashie_pro_yearly` priced **$23.88** (was $79.99); monthly
  `cashie_pro_monthly` stays **$9.99**.
- Removed the old `cashie_pro_yearly_mid` ($35.88) and `cashie_pro_yearly_special`
  ($23.88) rescue products from: `StoreKitService.swift`, `Cashie.storekit`,
  `mint-quick-log-key/index.ts` (Pro allowlist), and all the submission/runbook docs.

### 2.3.2 — metadata
- `APP_STORE_CONNECT_FIELDS.md` §2 description now has an explicit
  **"SUBSCRIPTION REQUIRED"** block (states a paid subscription is required +
  lists $9.99/mo and $23.88/yr). §5 rewritten to two products.

### Backup
- The original two-tier rescue modals are preserved (not compiled) at
  `archive/PaywallScreen_with_rescue_modals.swift.bak` so the design/copy isn't lost.

---

## 3. Why the current paywall is defensible

The current screen is a single, honest offer:

1. **One purchase surface.** No modal stacked on the paywall, no decline-triggered
   second offer. This is the direct fix for the 5.6 quote.
2. **The actual charge is the prominent number.** The yearly card shows **"$23.88 /year"**
   large; the "$1.99/mo" equivalent is small and secondary. Apple requires the
   annual total to be the prominent figure for an annually-billed plan (leading
   with the monthly-equivalent is a common rejection).
3. **The discount comparison is genuine.** The struck-through **$119.88 is the real
   12 × $9.99 monthly cost**, and monthly is actually sold, so "SAVE 80% vs paying
   monthly" is a true statement — not a fictitious former yearly price.
4. **Required disclosure present** (3.1.2): price + auto-renew + Terms + Privacy on
   the subscribing screen.

A large/prominent "SAVE 80%" section is **allowed** — Apple does not regulate the
size of a savings callout, only its accuracy and clear disclosure.

### Known soft spot
A big "~~$119.88~~ SAVE 80%" could be misread as implying $119.88 was the yearly
list price. Mitigated by the "vs paying monthly" label. To make it bulletproof,
spell out the basis on the strikethrough, e.g. **"$9.99/mo billed monthly"** or
**"~~$119.88/yr if billed monthly~~"**.

---

## 4. Countdown timers — DO NOT add one (as currently priced)

A countdown timer on the discount is allowed **only if it's truthful**: the price
must genuinely revert when it hits zero. Apple rejects fake urgency under 5.6
(timers that reset on relaunch, "limited time" prices that never change, struck
prices never actually charged).

$23.88 is the **permanent, only** price, so any timer would be claiming a fake
expiry → 5.6 violation, and high-risk given the existing rejection. To use a real
timer you'd need a genuinely time-limited **introductory/promotional offer** in
App Store Connect where the price actually rises afterward (and that reintroduces
the trial/intro model that was deliberately removed).

---

## 5. If they reject again — escalating fallback ladder

Work down this list; each step is strictly safer than the one above.

1. **Tighten the strikethrough label** (§3 soft spot): change `$119.88` to read
   "$9.99/mo billed monthly" so the reference price can't be misread. Cheapest fix.
2. **Drop the strikethrough entirely.** Keep "SAVE 80%" + the plan prices, remove
   the `$119.88` reference number. Removes any fictitious-price argument.
3. **Soften the savings claim.** Replace "SAVE 80%" / "80% off" with a neutral
   value label like "Best value" or "Most popular" on the yearly card. No percentage,
   no comparison, nothing to dispute.
4. **Plain two-plan paywall.** Two equal cards ($9.99/mo, $23.88/yr), no badge, no
   confetti, no comparison. This is the maximally-conservative version and is
   essentially un-rejectable on 5.6 grounds.

Also always:
- Confirm only **two** products exist in App Store Connect ($9.99, $23.88), no
  leftover rescue products.
- In the App Review notes, state plainly: "Single paywall, both plans shown
  together. No secondary or exit-intent offer." (Already in `APP_STORE_CONNECT_FIELDS.md` §5.)
- Reply to the reviewer describing exactly what changed since the rejected build.

If the rescue funnel is ever wanted back for non-App-Store reasons, it lives in
`archive/PaywallScreen_with_rescue_modals.swift.bak` — but it must NOT ship to the
App Store as-is (it is the rejected pattern).

---

## 6. Sources
- App Store Review Guidelines — 3.1.2 (subscriptions) & 5.6 (Code of Conduct):
  https://developer.apple.com/app-store/review/guidelines/
- App Store Connect — Manage pricing for auto-renewable subscriptions:
  https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions/
- Apple Developer Program License Agreement, Schedule 2 (binding subscription
  disclosure requirements referenced by 3.1.2).
