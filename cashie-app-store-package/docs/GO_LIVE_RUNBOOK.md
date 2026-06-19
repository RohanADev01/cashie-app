# Cashie - Go-Live Runbook (VM to TestFlight to App Store)

Everything left to take this VM-built bundle onto a real device, through
TestFlight, and onto the App Store, with native StoreKit 2 subscriptions,
Supabase sync, and the Quick Log Shortcuts automation all working and verified.

This VM is intentionally sandboxed: no Apple ID, no signing, no purchases, no App
Store submission happen here. **You must move the project onto a real Mac with
Xcode 15.4+ and a paid Apple Developer account to test and ship.** Everything
below is the sequence to do that.

Project facts:
- Bundle id `com.cashie.app`  ·  Display name `Cashie`  ·  Scheme `Cashie`
- Min iOS 16  ·  SwiftUI  ·  **no third-party SPM dependencies** - subscriptions
  run on native StoreKit 2 (`StoreKitService`)
- Supabase project: `fsmdklrrcnnwyzenuaed` (URL already in `Config.swift`)
- Subscriptions: native StoreKit 2, entitlement resolved from
  `Transaction.currentEntitlements` (no RevenueCat, no purchase SDK, no API key)

---

## 0. What changed in this pass - read first

1. **Hard paywall, NO free trial.** Only an active paid `pro` subscriber reaches
   the main app. Everyone else is sent to the paywall. The entitlement is
   re-checked on launch and on every foreground (expiry bounces straight back to
   the paywall), and the deep-link / App-Intent path into the app is Pro-gated
   too. There is no trial logic anywhere; do NOT add an introductory offer in App
   Store Connect.

2. **Security re-audit: clean.** No malware, backdoor, tracking, or data
   exfiltration. RLS is on for every table, `anon` has zero data access, and the
   privileged Quick Log functions (`issue_quick_log_key_for`, `quick_log_guarded`)
   are `SECURITY DEFINER` callable only by `service_role`. The only open advisor
   notes are the two documented-intentional ones (`citext` in `public`,
   `quick_log_rate` RLS-with-no-policy).

3. **Subscriptions are native StoreKit 2.** The only purchase dependency left is
   creating the four products in App Store Connect with IDs that match the app
   (section 2). There is no dashboard to configure and no key to paste; once the
   products exist and are approved, purchases work.

4. **Quick Log "Import Shortcut" button is now always functional.** It opens the
   trigger's import link (`Config.quickLogShortcutImportURL` for tap triggers,
   `Config.applePayShortcutImportURL` for Apple Pay), currently working
   placeholders (`https://www.google.com`). There is no "coming soon" copy. Swap the
   placeholder for the published iCloud Shortcut link (section 7).

5. **App Store compliance.** The paywall shows the price + auto-renew disclosure
   and functional **Terms of Use + Privacy Policy** links (Guideline 3.1.2), and a
   **`PrivacyInfo.xcprivacy`** manifest is in the build (declared via
   `scripts/gen_pbxproj.py`). A full **App Store Connect submission kit** (every
   field, paste-ready) plus ready-to-upload marketing screenshots is in
   `app_store_submission/` (see `app_store_submission/APP_STORE_CONNECT_FIELDS.md`).

6. **Rank ladder + badge economy retuned (gamification only, not launch infra).**
   The Platinum rank is now **Emerald** (a distinct green gem), the Gold rank icon
   is a **trophy**, and every **badge target** was lowered, calibrated to a
   realistic ~3-4 logs/week, so an average user reaches Emerald in ~3 months and a
   heavy user reaches Legendary around 6 months. **All XP values and rank
   thresholds are unchanged**, so this touches difficulty and cosmetics only, with
   no effect on the paywall, sync, or purchases. Rank is derived from XP and never
   demotes, so existing users only move up and there is no migration. Full detail,
   the realistic timeline, and the per-badge tables are in `BADGES_AND_RANKS.md`.
   NOTE: the rank images under `app_store_submission/screenshots/` still show the
   old Platinum/rosette art and should be re-captured before the final upload.

7. **RevenueCat removed - now native StoreKit 2 (2026-06-10).** The RevenueCat SDK
   and its SPM dependency (`purchases-ios`) were removed entirely; `Package.resolved`
   is gone and the project links no third-party packages. All in-app purchase logic
   (the hard paywall, the launch/foreground entitlement check, purchase, restore,
   and the expiry re-gate) now runs through `StoreKitService` on native StoreKit 2.
   The subscription protocol was renamed `RevenueCatService` -> `SubscriptionService`
   (`Cashie/Services/SubscriptionService.swift`); `AppContainer.subscriptions` is
   the binding. Both Debug and Release builds are clean and the binary links no
   RevenueCat framework. The Quick Log mint Edge Function, which previously
   verified `pro` server-side via RevenueCat's REST API, has been **re-implemented
   on Apple's App Store Server API** (native StoreKit 2). See section 6c for the
   one-time App Store Connect API key it needs.

---

## 1. The one blocker that makes the app unusable (why section 2 matters)

Subscriptions run on native StoreKit 2 (`StoreKitService`). On launch and every
foreground the app reads `Transaction.currentEntitlements`; an active
`cashie_pro_*` subscription unlocks the main app, anything else lands on the hard
paywall.

For a real purchase to succeed, the four products must exist and be approved in
**App Store Connect** with identifiers that exactly match `StoreKitService.productIDs`.
If they do not, StoreKit returns no products, the paywall can show its fallback
prices but the purchase call fails, and - because of the hard paywall - no one
can get in. Creating those products (section 2) is the one launch blocker on the
purchase side. There is no RevenueCat dashboard, entitlement mapping, or webhook
to configure.

---

## 2. Create the subscription products (do this first)

### 2a. Canonical product IDs (the app already uses these)

| Plan | Product ID (App Store Connect) | Period | Price | Role |
|---|---|---|---|---|
| Monthly | `cashie_pro_monthly` | P1M | $9.99 | shown on paywall |
| Yearly | `cashie_pro_yearly` | P1Y | $79.99 | shown on paywall (preselected anchor) |
| Yearly - mid rescue | `cashie_pro_yearly_mid` | P1Y | $35.88 | exit-intent offer #1 ("70% off") |
| Yearly - deep rescue | `cashie_pro_yearly_special` | P1Y | $23.88 | exit-intent offer #2, final ("80% off") |

All four IDs are already used by the app (`StoreKitService.productIDs`) and the
bundled `Cashie.storekit` test config, so **no app code change is needed for the
IDs.** The only gap is that the products do not exist in App Store Connect yet.

**Paywall funnel (how the products are used):** full price is shown first ($79.99
yearly preselected / $9.99 monthly). The two rescue products only appear at
exit-intent ("Maybe later" tap or backgrounding the app): `$35.88` first, then
`$23.88` once on a later open, then the price locks at full price forever. All
four resolve to the same `pro` entitlement. Full strategy + experiment design:
`pricing-and-paywall-optimization-plan.md`.

### 2b. App Store Connect (create the products, NO trial)

1. App Store Connect -> your app -> Subscriptions -> create a subscription group
   "Cashie Pro".
2. Add **four** auto-renewable subscriptions with the exact IDs/prices above:
   `cashie_pro_monthly` ($9.99/mo), `cashie_pro_yearly` ($79.99/yr),
   `cashie_pro_yearly_mid` ($35.88/yr), and `cashie_pro_yearly_special`
   ($23.88/yr). The two rescue products are required for the funnel to work on
   device - without them the rescue "Claim" buttons no-op.
3. Add a localized display name + description and a review screenshot for each.
4. **Do NOT add any Introductory Offer / free trial.** This is a hard paywall.
5. Submit the products for review with the first build (the first app submission
   reviews the subscriptions alongside the binary).

### 2c. Verify

On a device with a Sandbox tester (section 8b), open the paywall: both plans show
their real App Store prices, and a sandbox purchase reaches the main app. If the
paywall shows only the built-in fallback prices and the purchase fails, the
product IDs in App Store Connect do not match - re-check them against
`StoreKitService.productIDs`.

---

## 3. Move the project out of the VM onto a Mac

1. Zip the project (exclude `build/`, `DerivedData/`, `*.xcuserstate`) or push to a
   private git remote and clone on the Mac.
2. Open `Cashie.xcodeproj` in Xcode 15.4+. There are no Swift packages to resolve.
3. Signing & Capabilities -> set your Team, Automatic signing.
4. Build for a simulator first (clean baseline), then for a device.

> If you add or remove Swift files, the project file is generated:
> `python3 scripts/gen_pbxproj.py`. Do not hand-edit `Cashie.xcodeproj`.

---

## 4. Apple Developer one-time setup

1. Enroll in the Apple Developer Program ($99/yr) if you have not.
2. Register the App ID `com.cashie.app` (or let Xcode auto-create it).
3. Capabilities: the app uses local reminders only, so no special capability is
   required. In-App Purchase is implicit for subscription products. Push
   Notifications is only needed if you later add remote push. (No Sign in with
   Apple - the app is login-free / anonymous.)
4. App Store Connect: create the app record (name, bundle id, primary language,
   category Finance, support URL, privacy policy URL).

---

## 5. Set the keys - the only code edit needed to go live

All live config is centralized in **`Cashie/App/Config.swift`**. Set these in a
local build (keep `Config.swift` out of public git; it holds only public client
keys but there is no reason to publish them):

| Constant | Value | Effect |
|---|---|---|
| `supabaseAnonKey` | Supabase **anon / publishable** key | Turns on live sync + the anonymous identity |
| `postHogAPIKey` | PostHog **public project write** key (optional) | Turns on product analytics |
| `quickLogShortcutImportURL`, `applePayShortcutImportURL` | the two published iCloud Shortcut links - tap triggers + Apple Pay (see section 7) | Both "Import Shortcut" buttons currently open the placeholder `https://www.google.com` |

There is **no purchase key** to set - StoreKit needs none. No other Swift changes
are required to go live: the hard-paywall gating, the StoreKit subscription
service, the Supabase sync engine + anonymous auth, and the Quick Log key flow
(see the open item in 6c) are all already implemented.

---

## 6. Supabase: go live

### 6a. Anon key
- Supabase dashboard -> Settings -> API -> copy the `anon` / publishable key.
- Set `Config.supabaseAnonKey` to it. `Config.hasSupabase` flips true and live
  sync activates. `supabaseURL` is already set.

### 6b. Auth
- Authentication -> Providers -> enable **Anonymous**.
- Authentication -> enable **CAPTCHA / Attack Protection** (the main abuse vector
  of a public anon key is scripted anonymous sign-ups).

### 6c. Quick Log entitlement check - native StoreKit 2 (App Store Server API)
The `mint-quick-log-key` Edge Function verifies the caller's Pro subscription
server-side with Apple's **App Store Server API** - no RevenueCat. The client
sends the `originalTransactionId` of its active entitlement; the function signs a
short-lived ES256 JWT with an App Store Connect API key, asks Apple for the
subscription status, and mints only if it is active on a `cashie_pro_*` product.
The old `REVENUECAT_SECRET_KEY` / `REVENUECAT_ENTITLEMENT_ID` secrets are gone.

To enable it in production, create an **App Store Connect API key** (App Store
Connect -> Users and Access -> Integrations -> In-App Purchase -> generate a key)
and set these Edge Function secrets on the Supabase project (Project Settings ->
Edge Functions -> Secrets, or `supabase secrets set`):

| Secret | Value |
|---|---|
| `APPSTORE_ISSUER_ID` | the Issuer ID shown on the Integrations page |
| `APPSTORE_KEY_ID` | the generated key's Key ID |
| `APPSTORE_PRIVATE_KEY` | the full contents of the downloaded `.p8` (including the BEGIN/END lines) |
| `APP_BUNDLE_ID` | `com.cashie.app` (optional; this is the default) |

Until those secrets are set the function fail-closes (returns `server_misconfigured`)
and simply does not mint, so it is safe to deploy first. Quick Log is optional and
not required for App Review; the in-app subscription is fully functional regardless.

### 6d. Schema / functions
- Already applied and verified on this project (see `BACKEND_SYNC_REPORT.md`): all
  tables, RLS scoping every row to `auth.uid()`, realtime, and the two Edge
  Functions (`mint-quick-log-key`, `quick-log`) are deployed. `mint-quick-log-key`
  verifies Pro via Apple's App Store Server API (see 6c); set its secrets to enable minting.
- For a separate PROD project: re-apply all migrations, re-deploy both Edge
  Functions, re-set the edge secrets, then run the advisor and confirm only the
  two documented intentional notes remain.

---

## 7. Quick Log Shortcut (publish + wire the import link)

Goal: the user taps (Back Tap / Action Button / NFC) and a spend is logged to
their account and shows in the app, even with the app closed.

### 7a. How it works (already built)
- The app mints a per-user key via the **`mint-quick-log-key`** Edge Function
  (verifies the Supabase JWT, checks the Pro subscription via Apple's App Store
  Server API - see 6c - then mints). The key is shown in `QuickLogKeyCard`.
- The shared Shortcut POSTs each spend to the **`quick-log`** Edge Function, which
  rate-limits (per-IP 60/min, per-key 10/min + 200/day) and inserts one
  transaction.
- **Two shortcuts, two import links.** The tap triggers (Back Tap / Action Button)
  use **Cashie Quick Log** (`Config.quickLogShortcutImportURL`); the Apple Pay
  Wallet automation uses a separate **Cashie Apple Pay Log** shortcut
  (`Config.applePayShortcutImportURL`). Build/publish both.

### 7b. Build the shareable Shortcuts (on the Mac/iPhone)
Build **two** shortcuts - "Cashie Quick Log" (tap triggers) and "Cashie Apple Pay
Log" (Wallet automation). Their bodies are identical; publish them under the two
names so each trigger imports the right one. Each is a single "Get Contents of
URL" action:
- URL: `https://fsmdklrrcnnwyzenuaed.supabase.co/functions/v1/quick-log`
- Method: `POST`
- Headers: `x-api-key: <the user's key>`  ·  `Content-Type: application/json`
  (no anon key needed; this function does not verify a JWT)
- Body (JSON):
  ```json
  { "amount": <Amount>, "merchant": "<Merchant>", "category": "bills", "note": "" }
  ```
  `category` is one of: food, transport, shopping, fun, home, health,
  bills, income, other. `Amount` / `Merchant` come from "Ask for Input" actions
  (or are passed by the trigger). Add an Import Question for the API key so the
  user pastes their key once on import.

### 7c. Publish and wire them
1. Shortcuts app -> share each shortcut -> Copy iCloud Link.
2. Put the links in `Config.swift` (replacing the `https://www.google.com`
   placeholders): the Cashie Quick Log link in **`quickLogShortcutImportURL`** and
   the Cashie Apple Pay Log link in **`applePayShortcutImportURL`**. Use either the
   raw `https://www.icloud.com/shortcuts/<id>` link or the
   `shortcuts://import-shortcut?url=<iCloud link>&name=...` import form.
3. The in-app "Import Shortcut" button (`QuickLogKeyCard`) opens the link that
   matches the chosen trigger.

### 7d. Triggers (what you tell users)
- Back Tap: Settings -> Accessibility -> Touch -> Back Tap -> Triple Tap -> pick the shortcut.
- Action Button (iPhone 15 Pro+): Settings -> Action Button -> Shortcut -> pick it.
- Apple Pay-adjacent: Shortcuts -> Automation -> NFC (scan a sticker) -> run it. iOS
  has no native "after Apple Pay" trigger, so NFC tap or Back Tap right after
  paying is the honest equivalent.
- Also runnable by name from Spotlight / Siri.

---

## 8. Testing (do all of this on a real device before TestFlight)

### 8a. Build + first run
1. Plug in the iPhone, select it, set Team + Automatic signing, Run.
2. Trust the developer profile if prompted (Settings -> General -> VPN & Device
   Management).
3. Go through onboarding. An anonymous Supabase user is created silently.

### 8b. StoreKit subscription + hard paywall (sandbox)
Add a Sandbox tester in App Store Connect (Users and Access -> Sandbox), sign into
it on the device (Settings -> App Store -> Sandbox Account).
1. On the paywall, confirm both plans show their real App Store prices (proves
   StoreKit resolved the products = section 2 done). If only the built-in fallback
   prices show and a purchase fails, the product IDs do not match - go to section 2.
2. Buy the monthly plan with the sandbox account. Apple's purchase sheet appears
   (Face ID / double-tap). Confirm you land in the main app.
3. Force-quit and relaunch -> you stay in the app (entitlement re-read from
   `Transaction.currentEntitlements`).
4. Cancel the sandbox subscription (Settings -> sandbox account -> Subscriptions),
   wait for it to lapse (sandbox renews/expire fast), foreground the app -> you are
   bounced to the paywall. This proves the hard-paywall expiry re-gate.
5. Tap "Restore purchase" on a reinstall with the same sandbox account -> Pro
   returns (`AppStore.sync()` + entitlement re-read).

### 8c. Supabase database calls
1. In the app (as a Pro user), add a spend and a goal.
2. Supabase dashboard -> Table editor -> `transactions` / `goals`: confirm the rows
   appear with your `user_id`.
3. Edit a row in the dashboard -> within a few seconds the app updates (realtime),
   or it updates on next foreground (pull).
4. Airplane mode: add a spend -> it shows instantly (offline-first) and the
   "Saving" pill appears; turn networking back on -> the queued write flushes to
   Supabase (the row appears).
5. RLS proof (optional): with a second anonymous user, confirm they cannot see the
   first user's rows.

### 8d. Quick Log automation end to end
> Depends on the section 6c open item being resolved (the mint endpoint's
> entitlement check). Once it is:
1. In the app: You tab -> Quick Log setup. The key loads (Pro-verified). A non-Pro
   user would see "Quick Log is a Cashie Pro feature" / a 403.
2. Tap "Copy API key". Tap "Import Shortcut" (today it opens the placeholder; once
   section 7 is done it opens your real iCloud Shortcut import).
3. Import the shortcut, paste the key into the `x-api-key` prompt, assign it to
   Back Tap.
4. Close the app. Trigger the shortcut, enter an amount. Confirm it succeeds.
5. Open the app -> the spend appears on Today/Spend with `source = quicklog` (live
   via realtime, or on foreground).
6. Tap "Reset key" in the app, then run the old shortcut again -> it now fails
   (the old key is revoked). Re-copy the new key into the shortcut.

### 8e. Local StoreKit testing (before App Store Connect is ready)
You can exercise the full purchase flow in the simulator without App Store Connect
using the bundled `Cashie/Resources/Cashie.storekit` config (already set on the
scheme: Edit Scheme -> Run -> Options -> StoreKit Configuration). It defines the
canonical `cashie_pro_*` IDs with `introductoryOffer: null` (no trial), so running
from Xcode opens Apple's real purchase sheet and grants a local entitlement -
purchase, restore, and the foreground expiry re-gate all work locally. For
end-to-end verification against the App Store, use a Sandbox Apple ID on a device.

---

## 9. TestFlight

1. Set the Release scheme, bump the build number, Product -> Archive.
2. Organizer -> Distribute App -> App Store Connect -> Upload.
3. App Store Connect -> TestFlight -> add internal testers, then external (short
   Beta App Review). Provide test notes and a sandbox/demo flow.
4. Validate on a clean device via the TestFlight app: paywall -> purchase ->
   main app -> add spend -> Quick Log.

---

## 10. App Store submission

1. Listing: iPhone screenshots (6.9" or 6.5"; the app is **iPhone-only**, no iPad
   set), description, keywords, support URL, privacy policy URL.
2. **Subscription disclosure (Guideline 3.1.2):** DONE in the build - the paywall
   shows the price + "auto-renews until cancelled, cancel anytime" and has
   functional **Terms of Use** + **Privacy Policy** links. You only need to HOST
   the Privacy page at the `Config` URL (`cashie.space/privacy`) so it resolves;
   Terms of Use points at Apple's standard EULA. There is no free trial to disclose.
3. App Privacy: a `PrivacyInfo.xcprivacy` manifest is in the build. Fill the App
   Store Connect App Privacy questionnaire to match it - exact answers are in
   `app_store_submission/APP_STORE_CONNECT_FIELDS.md` section 8 (no tracking; the
   user's data + analytics are "not used for tracking"). Note: with RevenueCat
   removed, there is no longer a third-party purchase SDK collecting data - Apple
   handles purchases natively.
4. In-app purchases: attach the subscription products; the first submission
   reviews them with the build.
5. Submit. Respond to reviewer questions with a demo flow.

---

## 11. Files to change / add (next steps, explicit)

| # | File | Change | Status |
|---|---|---|---|
| 1 | `Cashie/App/Config.swift` | Set `supabaseAnonKey`, optional `postHogAPIKey`; swap `quickLogShortcutImportURL` + `applePayShortcutImportURL` from the `google.com` placeholders to the real Shortcut links (no purchase key needed) | **You, on the Mac** |
| 2 | `Cashie/Resources/Cashie.storekit` | Only if prices change. Keep `introductoryOffer: null` (no trial). Already on canonical IDs | Optional |
| 3 | `supabase/functions/mint-quick-log-key/` | Done - now verifies Pro via Apple's App Store Server API (RevenueCat removed). To enable minting, set the App Store Connect API key secrets (section 6c) | Optional (Quick Log only) |
| 4 | App Store Connect | Create the **four** products: `cashie_pro_monthly` $9.99, `cashie_pro_yearly` $79.99, `cashie_pro_yearly_mid` $35.88, `cashie_pro_yearly_special` $23.88 - NO trial (the two rescue products are required for the exit-intent funnel) | **You, on the Mac** |

Everything else is dashboard / App Store Connect / Supabase configuration, not
code. The full data-entry sheet is `app_store_submission/APP_STORE_CONNECT_FIELDS.md`,
with ready-to-upload screenshots in `app_store_submission/screenshots/`.

Code already done (no change needed): hard-paywall gating
(`AppContainer.routeOnLaunch` / `refreshSubscription` / `isProUnlocked`), the
native StoreKit subscription service (`StoreKitService.swift`, protocol in
`SubscriptionService.swift`), Supabase sync + anonymous auth
(`SupabaseService.swift`, `AuthClient.swift`), Quick Log key flow
(`QuickLogKey.swift`, `AppContainer.quickLogKey`, the two Edge Functions), the
now-functional "Import Shortcut" button (`QuickLogKeyCard.swift`), the paywall
Terms/Privacy links + disclosure, and the `PrivacyInfo.xcprivacy` manifest.

---

## 12. Pre-flight checklist

- [ ] Section 2 done: App Store Connect has all **four** products
      (`cashie_pro_monthly` $9.99, `cashie_pro_yearly` $79.99,
      `cashie_pro_yearly_mid` $35.88, `cashie_pro_yearly_special` $23.88),
      NO introductory offer, IDs matching `StoreKitService.productIDs`,
      submitted with the build.
- [ ] On the device the paywall shows real App Store prices and a sandbox purchase
      reaches the main app (Apple's purchase sheet appears).
- [ ] Both rescue offers reachable + purchasable on device: "Maybe later" surfaces
      $35.88; declining + reopening surfaces $23.88; declining that locks full price.
- [ ] Hard paywall verified: lapse/cancel bounces back to the paywall on foreground;
      restore works.
- [ ] Quick Log mint entitlement check resolved (section 6c) before relying on Quick
      Log in production.
- [ ] `Config.supabaseAnonKey` set; writes appear in Supabase Table editor; realtime
      + offline queue verified; `Config.swift` kept out of public git.
- [ ] Supabase **Anonymous** provider on + **CAPTCHA / Attack Protection** on.
- [ ] Quick Log: Pro user mints a key (non-Pro -> 403); the shared Shortcut imports
      and runs; spend lands and shows live; "Reset key" invalidates the old key.
- [ ] `Config.quickLogShortcutImportURL` + `applePayShortcutImportURL` swapped from
      the placeholders to the real published Shortcut links.
- [ ] Terms + Privacy pages hosted at the `Config` URLs (the in-app links +
      auto-renew disclosure + `PrivacyInfo.xcprivacy` are already in the build);
      App Privacy questionnaire filled per `app_store_submission/`.
- [ ] `Config.postHogAPIKey` set (if using analytics); events arrive.
- [ ] Supabase advisor reviewed: only the two documented intentional notes remain.
- [ ] No `service_role` key (or any secret) anywhere in the app or git.
- [ ] Crash-free pass over every screen on a real device.
- [ ] TestFlight build validated on a clean device before submitting.

---

## Appendix: where things live

| Concern | File |
|---|---|
| Keys / endpoints / shortcut link | `Cashie/App/Config.swift` |
| Hard-paywall gating | `Cashie/App/AppContainer.swift` (`routeOnLaunch`, `refreshSubscription`, `isProUnlocked`), `Cashie/App/SplashView.swift`, `Cashie/App/RootView.swift` |
| Paywall UI | `Cashie/Onboarding/PaywallScreen.swift` |
| Subscription gateway (native StoreKit 2) | `Cashie/Services/StoreKitService.swift`, protocol `Cashie/Services/SubscriptionService.swift` |
| StoreKit test config | `Cashie/Resources/Cashie.storekit` |
| Sync engine + live service + realtime | `Cashie/Services/SupabaseService.swift` |
| Anonymous auth | `Cashie/Services/AuthClient.swift` |
| Analytics (PostHog REST) | `Cashie/Services/Analytics.swift` |
| Quick Log key (client) + import card | `Cashie/Services/QuickLogKey.swift`, `Cashie/App/AppContainer.swift` (`quickLogKey`), `Cashie/Modals/QuickLogKeyCard.swift` |
| Quick Log Edge Functions | `supabase/functions/mint-quick-log-key/`, `supabase/functions/quick-log/` |
| Backend report | `BACKEND_SYNC_REPORT.md` |
| Security audit | `SECURITY_AUDIT.md` |
| Tickable checklist | `GO_LIVE_CHECKLIST.html` |
| Rank/badge economy + pacing | `BADGES_AND_RANKS.md` |
| Finalization audit | `FINALIZATION_REPORT.md` |
