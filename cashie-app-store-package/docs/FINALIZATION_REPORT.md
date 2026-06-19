# Cashie - Finalization Audit (2026-06-09, updated 2026-06-10)

Read-only finalization pass run inside the sandboxed VM. Purpose: verify the app
builds, runs, and is internally consistent, and give an honest go/no-go for the
App Store.

> **Update 2026-06-10 - RevenueCat removed, now native StoreKit 2.** All in-app
> purchase logic (hard paywall, launch/foreground entitlement check, purchase,
> restore, expiry re-gate) was migrated off the RevenueCat SDK to native
> StoreKit 2 (`StoreKitService`). The `purchases-ios` SPM dependency and
> `Package.resolved` were removed; Debug + Release both build clean and the
> binary links no RevenueCat framework. The subscription protocol is now
> `SubscriptionService` (`AppContainer.subscriptions`). This changed the blocker
> list below: the old RevenueCat dashboard blocker is gone, replaced by "create
> the StoreKit products in App Store Connect," and a new backend open item
> appeared (the Quick Log mint endpoint's server-side entitlement check). A
> timestamped backup of the pre-migration app is in `backups/`.

> **Verdict: the binary is in good shape (clean builds, no crashes, compliant
> paywall), but it is NOT one-click App-Store-ready.** Going live requires the
> off-VM steps in "Blockers" below, which by design cannot happen in this
> sandbox (no Apple ID, no signing, no App Store Connect, no live keys).

---

## 1. What was verified in-VM (passed)

| Check | Result |
|---|---|
| Debug build (`Cashie`, iOS 16 target, Xcode 15.4, SDK 17.5, simulator) | **Pass** |
| Release build (same) | **Pass** |
| Crash smoke test: onboarding welcome, paywall, Today, Badges, Ranks | **No crashes**, no diagnostic crash reports |
| Paywall (App Store Guideline 3.1.2) | Real prices ($9.99/mo, $79.99/yr, "SAVE 33%"), "Auto-renews until cancelled. Cancel anytime." disclosure, **Terms of Use + Privacy Policy** buttons wired to `Config` URLs, Restore present, **no free trial** |
| StoreKit config (`Cashie.storekit`) | Canonical `cashie_pro_monthly` $9.99 / `cashie_pro_yearly` $79.99 / `cashie_pro_yearly_mid` $35.88 / `cashie_pro_yearly_special` $23.88, `introductoryOffer: null` (last two are exit-intent rescues) |
| `PrivacyInfo.xcprivacy` | Present in bundle |
| Committed secrets | **None** (`supabaseAnonKey`, `postHogAPIKey`, `appStoreID` correctly empty in source; no purchase key exists - StoreKit needs none) |
| Subscriptions backend | **Native StoreKit 2** (`StoreKitService`). No third-party SDK; binary links no RevenueCat framework. Paywall renders, gate-open routes to home, fresh launch routes to onboarding, foreground expiry re-gate wired (verified). |
| Rank/badge rework | Consistent and renders: Gold trophy, Emerald rank, eased targets (seeded demo profile now 17/49 badges, 906 XP, Gold). XP + thresholds unchanged. |
| Submission kit | `app_store_submission/APP_STORE_CONNECT_FIELDS.md` + screenshots (iPhone 6.9", iPad 13") present |

**Testing caveat:** there is no app-level XCTest target, and the project now has
no SPM dependencies. In-VM testing was therefore build (Debug + Release) + manual
simulator smoke (paywall render, gate-open -> home, fresh -> onboarding,
crash-free). The live StoreKit *purchase sheet* (Apple's Face ID confirmation +
a real transaction) cannot be driven headlessly via `simctl`; verify it by
running from Xcode with the bundled `Cashie.storekit` config, or on a sandbox
device. An optional `CashieTests` target (rank/badge math) was proposed but NOT
added (awaiting approval).

---

## 2. Blockers to launch (off-VM, owner = you on the Mac/dashboards)

None of these can be done or fixed from this VM.

| # | Blocker | Where | Detail |
|---|---|---|---|
| 1 | Submission is off-VM | Real Mac + Xcode + paid Apple Developer account | Sign, archive, upload. No path to the App Store from this sandbox. |
| 2 | **StoreKit products not created** | App Store Connect | The #1 purchase blocker. Create all four products `cashie_pro_monthly` $9.99 / `cashie_pro_yearly` $79.99 / `cashie_pro_yearly_mid` $35.88 / `cashie_pro_yearly_special` $23.88 with IDs matching `StoreKitService.productIDs`, NO trial (the last two power the exit-intent rescue funnel). Until they exist + are approved, a real purchase fails and the hard paywall locks everyone out. Runbook section 2. (Native StoreKit needs no dashboard/SDK/key beyond this.) |
| 3 | Live keys empty | `Cashie/App/Config.swift` (local, gitignored build) | Set `supabaseAnonKey`, optional `postHogAPIKey`, `appStoreID`. No purchase key needed (StoreKit). |
| 4 | Quick Log mint entitlement check | `supabase/functions/mint-quick-log-key/` | Done - re-implemented on Apple's App Store Server API (native StoreKit 2; RevenueCat removed). To enable minting in production, set the App Store Connect API key secrets (runbook section 6c). Fail-closes until then. Affects Quick Log only (optional); the in-app subscription is unaffected. |
| 5 | Quick Log import link is a placeholder | `Config.quickLogShortcutImportURL` | Still `https://www.google.com`. Publish the iCloud Shortcut and swap the link. Runbook section 7. |
| 6 | Privacy Policy page not hosted | `cashie.space/privacy` | The in-app link + listing both need it to resolve. |
| 7 | Supabase go-live config | Supabase dashboard | Enable Anonymous provider + CAPTCHA. (For Quick Log minting, set the App Store Connect API key edge secrets - see blocker 4. The old `REVENUECAT_*` secrets are gone.) |
| 8 | App Store Connect setup | App Store Connect | Create app record + subscription products (NO trial), upload screenshots, fill App Privacy questionnaire per `app_store_submission/`. |

---

## 3. In-VM follow-ups

**Done this pass (authorized):**
- `GO_LIVE_RUNBOOK.md` + `.html`: added a changelog entry for the gamification
  retune and appendix rows for `BADGES_AND_RANKS.md` and this report.
- This `FINALIZATION_REPORT.md`.

**Proposed but NOT done (awaiting approval):**
- Re-capture the stale rank screenshots in `app_store_submission/screenshots/`
  (`*rank*.png` still show the old Platinum/rosette art, not Emerald/trophy).
- Add a `CashieTests` XCTest target (rank thresholds, catalog XP total = 8,276,
  49 badges, unique badge IDs, `Rank.progress` boundaries).

---

## 4. Go / No-Go checklist (source: `GO_LIVE_RUNBOOK.md` section 12)

- [ ] StoreKit products created in App Store Connect, IDs matching `StoreKitService.productIDs`, NO trial, submitted with build (blocker 2)
- [ ] Sandbox purchase reaches the main app; Apple's purchase sheet appears
- [ ] Hard paywall verified: lapse/cancel bounces to paywall on foreground; restore works
- [ ] Quick Log mint entitlement check replaced (Apple-native or trusted client) - blocker 4
- [ ] `Config.supabaseAnonKey` set; writes appear in Supabase; realtime + offline queue verified
- [ ] Supabase Anonymous provider + CAPTCHA on
- [ ] Quick Log: Pro mints a key (non-Pro 403); shared Shortcut imports + runs; reset invalidates old key
- [ ] `Config.quickLogShortcutImportURL` swapped off the placeholder
- [ ] Terms + Privacy pages hosted at the `Config` URLs
- [ ] App Privacy questionnaire filled per `app_store_submission/`
- [ ] Rank screenshots re-captured to match the Emerald/trophy build
- [ ] Crash-free pass over every screen on a real device
- [ ] TestFlight build validated on a clean device before submitting
