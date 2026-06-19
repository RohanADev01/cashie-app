# Pricing & Paywall Optimization — Strategy + Implementation Plan

_Senior-growth-engineer response to `pricing-and-paywall-optimization-audit.md`, grounded in the actual Cashie code (StoreKit 2, native, no SDK). Primary metric throughout: **Revenue Per Paywall Viewer (RPPV)** — not conversion._

---

## 0. The finding that dominates everything else

**The current paywall does the exact anti-pattern the brief warns against.**

In `PaywallScreen.startDiscountIfFirstVisit()`, the *first* time any user reaches the paywall we start a 5-minute timer and **auto-open the 80%-off `DiscountModal` ($23.88/yr, "$1.99/mo") 0.3s later** — before the user has engaged with the real price at all.

Consequences, in RPPV terms:
- Every high-willingness-to-pay user who would have paid **$79.99** is handed **$23.88**. That is a ~70% revenue haircut on your best buyers.
- The app's *perceived* value is anchored at **$24**, permanently. Renewals at $79.99 will feel like a price hike → cancellations/disputes.
- The "5-minute" timer silently **restarts** (`discountStartKey` is only set once, but the modal logic re-pops via the banner), so the urgency is fake. Users learn fake urgency fast.

**This single change — stop showing the deep discount to everyone, show full price first — is worth more than every other optimization combined.** The rest of this document is about doing the rescue *correctly*.

---

## 1. Audit of current pricing

| Item | Verdict | Notes |
|---|---|---|
| **Monthly $9.99** | Keep | Slightly low for a finance app, but its real job is to be the *decoy* that makes annual look smart, not to sell. Don't raise it yet. |
| **Annual $79.99** | Keep as the anchor | = 8× monthly = **33% off** the monthly run-rate ($119.88). Believable, preserves pricing power, not "fake-cheap." Correct standing annual price. |
| **33% standing annual discount** | Appropriate | The literature sweet spot for the *headline* discount is 40–70%; 33% as the *everyday* annual is healthy and non-suspicious. |
| **$23.88 special product exists** | Fine as a product, wrong as a default | The problem is **who sees it and when**, not that it exists. |

**Risks of the current setup:** value-anchoring at $24; high-WTP users systematically underpay; renewal shock; training users that the discount is the "real" price; bargain-hunter cohort with worse retention.

**Bottom line: the prices are sound. The _funnel_ — which price is shown, to whom, when — is broken.**

---

## 2. Highest-EV funnel (high churn, first-year-cash focus)

Given the stated assumptions (most users won't renew at 12 months; optimize first-year cash per install), the optimal structure is **full price first, a single well-placed rescue, a true one-time deep offer held in reserve.**

```
[Onboarding paywall]  Annual $79.99 (preselected) · Monthly $9.99 · NO auto-discount
        │  user subscribes ───────────────────────────────► done (full price captured)
        │
        │  user dismisses / exit-intent (taps X, swipes away)
        ▼
[Rescue #1]  Annual $35.88 (~$2.99/mo) · "one-time welcome offer" · soft countdown
        │  subscribes ────────────────────────────────────► done ($35.88 captured)
        │
        │  dismisses
        ▼
   Don't show again this session.
   Schedule LOCAL notification ~1h later (no server needed) → deep-link back to paywall.
        │
        ▼
[Next open / push tap]  Full price again, rescue reachable ONCE more, then locked.
        │  still declines
        ▼
[Final offer — reserved]  Annual $23.88 (~$1.99/mo) · genuinely once · then price reverts FOR REAL.
```

**Why single-rescue at $35.88 (not $23.88) as the default:** the analyst math in your notes is correct — a cheaper offer usually wins *conversion* but loses *RPPV*. Illustrative: 100 decliners → 10 buy at $35.88 = **$359** vs 13 buy at $23.88 = **$310**. $35.88 is the revenue-maximizing rescue; $23.88 is the *growth/last-ditch* lever. So: **$35.88 is Rescue #1; $23.88 is the final exit only.**

**Why not the 70%→80% multi-timer maze from the early notes:** it adds analytics ambiguity (which discount layer caused the purchase?) and trains users to wait for the next discount. The brief's own final recommendation (simple: full price → dismiss → one rescue → never again) is right.

**One-time offer: yes — but make it _true_.** Today's timer restarts, which is the fastest way to kill urgency credibility. After the second exposure, the price must actually revert and stay reverted (persist a `rescueState` enum per user).

**Push:** use a **local** notification (`UNUserNotificationCenter`, no APNs/server) scheduled ~1h after first dismissal. Honest copy, fires once. (We already request notification permission in onboarding.)

---

## 3. Experiments — PostHog feature flag `paywall_funnel`

| Variant | Funnel | Hypothesis | Primary | Guardrails |
|---|---|---|---|---|
| **A** (control) | Full price, no rescue | Baseline RPPV; cleanest pricing power | RPPV | refund rate, D30 retention |
| **B** (rec.) | Full price → $35.88 rescue | Lifts RPPV without gutting price | RPPV | monthly:annual mix, refund rate, renewal intent |
| **C** | Full price → $23.88 rescue | Max conversion; may *lose* RPPV vs B | RPPV (watch conversion↑ revenue↓) | refund rate, dispute rate |
| **D** | Full price → $35.88 → $23.88 final | Captures multiple WTP tiers | RPPV | complexity, refund rate, "discount-trainer" cohort |

**Expected:** B or D win RPPV; **C is the trap** — higher conversion, lower revenue. That C-trap is the precise thing this experiment exists to detect. Roll the flag server-side in PostHog so no app update is needed to change the mix; default flag → **B**.

---

## 4. Event taxonomy

Constraint: `Analytics.capture(_ event, [String:String])` is **string-props only** (Codable buffer). All property values below are strings. `container.track(name, props)` is the call site.

| Event | Properties | Example payload |
|---|---|---|
| `paywall_viewed` | `placement` (onboarding\|settings\|feature_gate), `variant`, `default_plan`, `view_index` | `{placement:"onboarding", variant:"B", default_plan:"cashie_pro_yearly", view_index:"1"}` |
| `plan_selected` | `plan`, `price_usd` | `{plan:"cashie_pro_monthly", price_usd:"9.99"}` |
| `checkout_started` | `plan`, `price_usd`, `surface` (paywall\|rescue_mid\|rescue_deep) | `{plan:"cashie_pro_yearly", price_usd:"79.99", surface:"paywall"}` |
| `checkout_abandoned` | `plan`, `surface`, `reason` (cancelled\|pending\|error) | `{plan:"cashie_pro_yearly", surface:"paywall", reason:"cancelled"}` |
| `purchase_completed` | `plan`, `price_usd`, `surface`, `billing_period` | `{plan:"cashie_pro_yearly_special", price_usd:"35.88", surface:"rescue_mid", billing_period:"year"}` |
| `paywall_dismissed` | `placement`, `variant`, `saw_rescue` (true\|false) | `{placement:"onboarding", variant:"B", saw_rescue:"false"}` |
| `rescue_offer_viewed` | `tier` (mid\|deep), `price_usd`, `trigger` (dismiss\|relaunch\|push) | `{tier:"mid", price_usd:"35.88", trigger:"dismiss"}` |
| `rescue_offer_dismissed` | `tier`, `price_usd`, `time_on_screen_s` | `{tier:"mid", price_usd:"35.88", time_on_screen_s:"7"}` |
| `rescue_offer_expired` | `tier`, `price_usd` | `{tier:"mid", price_usd:"35.88"}` |
| `push_scheduled` | `campaign` (rescue_1h), `delay_s` | `{campaign:"rescue_1h", delay_s:"3600"}` |
| `push_opened` | `campaign` | `{campaign:"rescue_1h"}` |
| `restore_tapped` / `restore_succeeded` | `surface` | `{surface:"paywall"}` |
| `subscription_status_resolved` | `is_subscribed` | `{is_subscribed:"false"}` |

**Recommended additions:** `feature_gate_hit {feature}` (which locked feature drove a return-to-paywall), and a person property `max_paywall_views` so you can target multi-view non-buyers.

**Fixes to current tracking:** today we emit only `purchase_started`/`purchase_completed` with `{plan}`. Rename to `checkout_started` (or keep both during migration) and add `price_usd` + `surface` so RPPV is computable by displayed price.

---

## 5. Dashboards (PostHog)

**Executive** (4 tiles): RPPV (rev ÷ `paywall_viewed` uniques) · Revenue per install · Subscription conversion (% of paywall viewers who purchase) · Annual:Monthly revenue mix.

**Growth:** Funnel `paywall_viewed → checkout_started → purchase_completed`, broken by `variant` · Rescue performance (`rescue_offer_viewed → purchase_completed[surface=rescue_*]`) · Push performance (`push_scheduled → push_opened → purchase`) · Revenue by `variant`.

**Pricing:** Revenue by `price_usd` · Conversion by `price_usd` · **Revenue lift from rescue** = `(RPPV with rescue − RPPV control)` · Refund/dispute rate by `price_usd` (the bargain-hunter detector).

---

## 6. Statistics

- **Effect size to power for:** RPPV is revenue-weighted, high-variance → don't trust eyeballing. Target a detectable lift of ~15–20% in RPPV.
- **Sample size:** for a baseline conversion ~3–5% and a meaningful absolute lift, plan **~3,000–5,000 paywall viewers per variant** before reading. RPPV's variance (a few annual buyers swing it) means you often need *more* than a conversion test, not less.
- **Significance / duration:** 95% (α=0.05), 80% power; run **≥ 2 full weeks** regardless of significance (weekday/weekend + payday cycles), and don't stop on the first day it crosses. Use PostHog's sequential/Bayesian readout rather than peeking at fixed-horizon p-values.
- **Stopping rule:** stop when (a) sample target hit AND (b) the credible interval for RPPV excludes "no difference," OR (c) a guardrail (refund rate, dispute rate) breaches. Never stop early just because conversion looks good — that's the C-trap.

---

## 7. Blind spots

**Pricing mistakes:** deep discount as the default (current bug); discount so large the full price looks fake; never testing a *higher* annual; ignoring refund/dispute rate as a true-cost signal.

**Paywall mistakes:** fake/restarting timers (current); too many offer layers; burying the auto-renew/price disclosure (Apple 3.1.2 — ours is present, keep it); no exit-intent capture; showing the rescue *before* the dismissal intent.

**Experimentation mistakes:** optimizing conversion instead of RPPV; peeking and stopping early; underpowered RPPV reads; not segmenting by storefront/locale (prices shown in USD but charged locally — a weak FX week can move revenue, not your funnel).

**How this strategy could raise conversion while cutting revenue (the core risk):** any time the cheaper offer (C / $23.88) is shown earlier or more widely than necessary. More people buy, each pays far less, and your high-WTP users — who'd have paid $79.99 — get trained to wait for the discount. **Guard:** always read RPPV, never conversion alone; keep $23.88 strictly as the final exit, gated behind two declines.

---

## Final deliverable

**1. What I'd launch today (default = variant B):**
- Onboarding paywall shows **full price** ($79.99 annual preselected, $9.99 monthly). **No auto-discount.**
- On dismissal/exit-intent → **one** rescue at **$35.88/yr**, framed as a one-time welcome offer.
- Decline → schedule a **local** notification ~1h later; on next open the paywall returns, rescue reachable **once** more, then **truly** locked.
- `$23.88` reserved as the final exit only (variant D / win-back), never first.
- Wire the event taxonomy above; put the funnel behind PostHog flag `paywall_funnel` (default B).

**2. What I'd test next:** B vs C vs D on **RPPV**; then a *higher* annual ($89.99/$99.99) as control-vs-control; then push timing (1h vs next-session-only).

**3. What I'd never do:** show $23.88 (or any 80%-off) to a first-time viewer; run a timer that restarts; optimize on conversion rate; let the rescue price drift below $23.88.

**4. The single metric above all others:** **Revenue Per Paywall Viewer (RPPV)** = total subscription revenue ÷ unique `paywall_viewed`.

---

## Implementation map (code)

**Decision (locked in):** two-tier funnel ($35.88 mid → $23.88 deep), triggered by exit-intent + next-launch. No push this pass.

| Change | File(s) | Status |
|---|---|---|
| Remove auto-pop of 80%-off on first visit; show full price first, yearly preselected | `PaywallScreen.swift` | ✅ done |
| Two-tier exit-intent rescue: $35.88 mid → $23.88 deep | `PaywallScreen.swift` (`RescueTier`, `RescueModal`) | ✅ done |
| Triggers: "Maybe later" tap + app-background→return + cold-launch deep continuation | `PaywallScreen.swift` (`scenePhase`, `hasBackgrounded`) | ✅ done |
| `rescueStage` persistence (`none` → `mid_declined` → `deep_declined`), truly locks | `PaywallScreen.swift` (UserDefaults `paywallRescueStage`) | ✅ done |
| True one-time semantics — no restarting timer; price reverts on decline | `PaywallScreen.swift` | ✅ done (replaced 5-min timer) |
| Event taxonomy (`paywall_viewed`, `plan_selected`, `checkout_started/abandoned`, `purchase_completed`, `paywall_dismissed`, `rescue_offer_viewed/dismissed`, `restore_*`) + `price_usd`/`surface` | `PaywallScreen.swift`, `RescueModal` | ✅ done |
| Required disclosure (price + auto-renew + Terms/Privacy) on the rescue modal too | `PaywallScreen.swift` (`RescueModal`) | ✅ done |
| Add `cashie_pro_yearly_mid` ($35.88) to the local StoreKit config + product IDs | `Cashie.storekit`, `StoreKitService.swift` | ✅ done |
| Dev affordance `-rescue reset\|mid\|deep` | `PaywallScreen.swift` | ✅ done |
| **Create `cashie_pro_yearly_mid` ($35.88) + `cashie_pro_yearly_special` ($23.88) in App Store Connect** | App Store Connect | ⛔ TODO (external) |
| Local notification ~1h after dismissal → deep-link to paywall | new (`UNUserNotificationCenter`) | ⏸ deferred (not chosen this pass) |
| PostHog feature flag `paywall_funnel` to A/B test A/B/C/D live | `AppContainer` flag fetch | ⏸ next (events are already variant-tagged `two_tier`) |

**App Store Connect dependency (blocker for device/release):** the two rescue products must exist as auto-renewing subscriptions in the existing "Cashie Pro" group before they resolve on a real device — `cashie_pro_yearly_mid` ($35.88/yr) and `cashie_pro_yearly_special` ($23.88/yr). The `.storekit` file only powers the simulator/Xcode runs. Until they're created in ASC, the rescue "Claim" buttons will no-op on device (DEBUG simctl fakes success).
</content>
</invoke>
