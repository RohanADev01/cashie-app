# Cashie — Remaining to Connect & Integrate

> **Superseded note (2026-06-10):** subscriptions are now **native StoreKit 2**.
> The RevenueCat SDK / `purchases-ios` SPM dependency / `Package.resolved` were
> removed, and `CashieApp` no longer has a `makeRevenueCatService`. Section 2
> below (RevenueCat) is obsolete: there is no key to paste and no
> `LiveRevenueCatService` to implement - `StoreKitService` is the live backend.
> The only remaining purchase task is creating the `cashie_pro_*` products in App
> Store Connect, plus re-implementing the Quick Log mint entitlement check
> Apple-natively. See `GO_LIVE_RUNBOOK.md` sections 2 and 6c.

Status of every external integration and what is still needed to take the app
from "runs on mocks" to "production wired." The app currently builds and runs
fully on local mocks, so none of this blocks development or simulator testing.

Bundle id: `com.cashie.app`. Composition root that picks real vs mock services:
`Cashie/App/AppContainer.swift` (`init`) and `Cashie/App/CashieApp.swift`
(`makeRevenueCatService`). Detailed backend notes also live in
`Cashie/Services/Integration.md`.

Legend: `[x]` done / present, `[ ]` still to do.

---

## 1. Supabase (auth + cloud sync)
Currently: `MockSupabaseService` (local JSON on disk via `LocalStore`). The live
wrapper `LiveSupabaseService` exists but every method is stubbed to return empty.

- [x] Schema + RLS policies defined (see `Cashie/Services/Integration.md`); dev project `fsmdklrrcnnwyzenuaed`
- [x] `SupabaseService` protocol + mock implementation
- [ ] Add SPM dependency `supabase-community/supabase-swift` (pin exact version; needs dependency approval)
- [ ] Create `Cashie/App/Config.swift` entries `supabaseURL` + `supabaseAnonKey` (gitignore this file; never commit the `service_role` key)
- [ ] Implement the stubbed methods in `LiveSupabaseService` (`Cashie/Services/SupabaseService.swift`, behind `#if canImport(Supabase)`)
- [ ] Wire silent Supabase **anonymous** auth so `auth.uid()` scopes rows (no login); persist the refresh token in the iCloud Keychain for delete/reinstall restore
- [ ] Swap `MockSupabaseService()` for `LiveSupabaseService()` in `AppContainer.init`
- [ ] (Later) Edge Functions: `weekly-wrapped`, `archetype-recompute`, `goal-autopilot`

## 2. Subscriptions (native StoreKit 2 - RevenueCat removed)
RevenueCat is fully removed (SDK, `purchases-ios` SPM dep, `Package.resolved`).
The live backend is `StoreKitService`, which resolves the `pro` entitlement from
Apple's `Transaction.currentEntitlements`. There is **no key to paste and no
dashboard to configure** - the only purchase task is creating the products in
App Store Connect (section 3 below).

- [x] `SubscriptionService` protocol + `MockSubscriptionService` + live `StoreKitService`
- [x] `pro` resolved from `Transaction.currentEntitlements` (no third-party SDK)
- [x] Quick Log mint Edge Function now verifies Pro via Apple's App Store Server API (RevenueCat removed). To enable minting, set the App Store Connect API key secrets - `GO_LIVE_RUNBOOK.md` §6c

## 3. StoreKit products (App Store Connect)
Product ids referenced in code (`StoreKitService.productIDs`) - one screen, one
offer (no rescue products):
`cashie_pro_monthly` ($9.99/mo) and `cashie_pro_yearly_v2` ($29.99/yr).

- [x] Local `Cashie/Resources/Cashie.storekit` config (referenced by the scheme) for simulator testing
- [x] DEBUG fallback simulates a successful purchase when products can't load
- [ ] Create the four products in App Store Connect (host Mac, human only)
- [ ] Confirm the live product ids match the ones above
- [ ] Verify sandbox purchase + restore on a real device / sandbox account

## 4. Identity (anonymous, no login)
Decision (2026-06-07): no Sign in with Apple. `SignInScreen.swift` was deleted and
onboarding goes straight to name entry. Identity is a silent Supabase anonymous
user; restore-after-deletion rides on the iCloud Keychain.

- [x] Sign in with Apple removed from onboarding (no login, less friction)
- [ ] Silent Supabase **anonymous** sign-in in `SupabaseAuth.swift` (no UI); see `GO_LIVE_RUNBOOK.md` section 4 / the 2026-06-07 update
- [ ] Add the **iCloud (Keychain Sharing)** capability / `.entitlements` in Xcode
- [ ] Persist the anonymous refresh token in the iCloud Keychain (`kSecAttrSynchronizable`) so delete/reinstall resumes the same user
- [ ] Do NOT use the RevenueCat anonymous ID for identity (regenerated on reinstall)

## 5. Custom fonts (Barlow Condensed + Inter)
Currently: `Info.plist` registers the TTFs under `UIAppFonts`, but
`Cashie/Resources/Fonts/` is EMPTY, so the app falls back to system fonts.

- [x] Font names wired in `Info.plist` and `DesignSystem/Typography.swift`
- [ ] Drop the Barlow Condensed + Inter `.ttf` files into `Cashie/Resources/Fonts/`
- [ ] Re-run `python3 scripts/gen_pbxproj.py` so they are bundled, then rebuild

## 6. Rank badge art (optional)
Currently: `Assets.xcassets/Ranks/Rank*.imageset` are EMPTY placeholders, so the
app draws a procedural medallion (looks finished without art).

- [x] Procedural medallion fallback in `RankBadgeView`
- [ ] (Optional) Add the generated PNGs (prompts in `RANKS_ART_PROMPTS.md`) into the 7 `Rank*.imageset` folders

## 7. Notifications
Currently: local daily reminder via `UNUserNotificationCenter` (`ReminderScheduler`).

- [x] Local reminder scheduling + permission request, no-op when denied
- [ ] (Optional) Remote push / APNs, if server-driven notifications are wanted (pairs with the `weekly-wrapped` Edge Function)

## 8. Privacy lock (Face ID / passcode)
Currently: `PrivacyLockService` uses `LocalAuthentication`; the simulator passes
through (no biometrics).

- [x] Lock on background, unlock on foreground, eligibility check, passcode fallback in code
- [ ] Verify Face ID success/failure/lockout on a real device

## 9. Build / distribution (host Mac only, per workspace policy)
- [x] App icon (`Assets.xcassets/AppIcon.appiconset`), launch routing, dev launch args
- [ ] Signing, archive, TestFlight / App Store submission (done by a human on the host machine, never in this workspace)

## 10. Quick Log automation (Back Tap / Siri / NFC)
Currently: native path shipped and building. Logs via App Intents + `cashie://`
deep links with no key and no login, fully offline.

- [x] App Intents: `LogExpenseIntent` (silent, app-closed), `OpenQuickLogIntent`, `SpendCategoryAppEnum`, `CashieShortcuts` (`AppShortcutsProvider`) in `Cashie/Intents/`
- [x] `cashie://` URL scheme + `DeepLink.swift` parsing + `AppContainer.presentQuickLog`; the sheet is driven by the container
- [x] `QuickLogWriter` writes to `LocalStore.transactions` + the sync outbox (no `AppContainer`), so background logs persist and sync later
- [x] `QuickLogSetupSheet` rebuilt into a Back Tap / Action Button / Siri / NFC trigger chooser
- [x] Quick Log backend deployed + tested on dev: `quick_log_keys`, `issue_quick_log_key`, `quick_log`
- [ ] (Phase 2) Mint a key via `issue_quick_log_key` for the anonymous user; store the raw key in Keychain (depends on sections 1 + 4)
- [ ] (Phase 2) Wrap `quick_log` in a Supabase Edge Function (per-key + per-IP rate limit, HMAC) so the shared shortcut carries only the function URL + user key
- [ ] (Phase 2) "Add Quick Log Shortcut" import button + the iCloud shortcut; key revoke / rotate UI

---

## Quick "go live" order
1. Fonts (visual; fastest win)
2. App Store Connect products + verify StoreKit purchase on device
3. RevenueCat key + `LiveRevenueCatService` (or stay StoreKit-only)
4. Supabase package + `Config.swift` + `LiveSupabaseService`
5. iCloud (Keychain Sharing) capability, then silent anonymous Supabase auth + restore
6. (Optional) rank art, remote push, Edge Functions
7. (Optional) Quick Log API-key path: anonymous key minting + Edge Function (the native Back Tap / Siri / NFC path already ships)
