# Cashie - VM to real device to App Store (publish runbook)

> **Superseded note (2026-06-10):** Cashie now uses **native StoreKit 2** for
> subscriptions - the RevenueCat SDK, its `purchases-ios` SPM dependency, and
> `Package.resolved` were all removed. Any step below that mentions resolving the
> RevenueCat package, setting `revenueCatAPIKey`, or configuring the RevenueCat
> dashboard no longer applies. The only purchase task is creating the
> `cashie_pro_*` products in App Store Connect. **`GO_LIVE_RUNBOOK.md` is the
> authoritative, up-to-date guide** (see its sections 2 and 6c).

The narrow path: take this VM-developed bundle out, open it on your own Mac with
your Apple ID signed in, get it running on your iPhone, and push it to the App
Store. This is the "how do we actually ship it" sequence.

This complements `GO_LIVE_RUNBOOK.md`. That doc explains the backend in depth
(Supabase auth, StoreKit subscriptions, Quick Log). This doc is the publishing
journey and only cross-references the backend where the publish flow needs it.

---

## 0. Read this first: naming and what "live" means here

**Naming.** Everything is now **Cashie**:
- Bundle id: `com.cashie.app`  ·  Xcode scheme/target: `Cashie`  ·  on-disk repo folder: `cashly` (the only thing still named that way; harmless, dev-machine only)
- What users see on the home screen: **Cashie** (`Info.plist` `CFBundleDisplayName`
  = `Cashie`, and `NSFaceIDUsageDescription` says "Cashie").

When you create the App Store Connect record, the public app name is **Cashie**
and the bundle id is `com.cashie.app`. Register that App ID and your IAP products
against `com.cashie.app`.

**Two possible "go live" floors. Pick one before you start:**

| Floor | What works | What you must finish first |
|---|---|---|
| A. Offline-only ship | Full app on-device: spends, ranks, paywall via StoreKit, Face ID lock, local reminders | Just signing + IAP products. No Supabase key, no accounts. |
| B. Accounts + sync ship | Everything in A, plus Sign in with Apple to a real account, multi-device realtime sync, Quick Log Shortcuts | Floor A, **plus** the `SupabaseAuth` code task (section 9) + the Supabase key |

You can ship Floor A to the App Store today and add accounts in a 1.1 update. The
app is built offline-first, so it is fully usable with both keys in `Config.swift`
empty. If you want accounts in v1.0, section 9 is the gating code work.

---

## 1. Verified project facts

- Min iOS: **16.0**  ·  Version: **1.2**  ·  Build: **4**  ·  App category: **Finance** (`LSApplicationCategoryType = public.app-category.finance`; secondary **Lifestyle** is App Store Connect only)  ·  SwiftUI, portrait only, **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`)
- **Build with Xcode 26+ (iOS 26 SDK or later).** Apple rejects uploads built with an older SDK at validation - an iOS 17.5-SDK build fails. Update Xcode before you Archive.
- Signing: `CODE_SIGN_STYLE = Automatic`, **`DEVELOPMENT_TEAM` is not set** (you set it on your Mac)
- **No SPM dependencies** - subscriptions are native StoreKit 2 (RevenueCat removed)
- Capabilities used: **Face ID** (usage string present), **Sign in with Apple**
  (button present, entitlement NOT yet added - see section 5)
- Subscription products (StoreKit config `Cashie/Resources/Cashie.storekit`) - **two** auto-renewable, NO trial:
  - `cashie_pro_monthly` - $9.99 / month (P1M) - shown on paywall
  - `cashie_pro_yearly_v2` - $29.99 / year (P1Y) - shown on paywall (preselected; "SAVE 75%" against the $119.88 monthly-x12 reference)
  One screen, one offer (no exit-intent rescue products) to stay within App Store Guideline 5.6.
- Backend keys (`Cashie/App/Config.swift`): `supabaseURL` set; `supabaseAnonKey`
  intentionally **empty** in source. There is no RevenueCat key - native StoreKit needs none.

---

## 2. Get the code out of the VM

This VM folder is not a git repo, so move the files directly.

1. Copy the project folder to your real Mac. Either:
   - Zip it and AirDrop / transfer, **or**
   - Push to a private git remote here, then clone on the Mac.
2. Exclude build junk (not needed, just bloat): `build/`, `DerivedData/`,
   `*.xcuserstate`, and the local `backups/` folder if large.
3. Keep everything under `Cashie/` and `Cashie.xcodeproj/`, plus the `.storekit`
   file and the markdown runbooks.

> Nothing here is signed or tied to an Apple ID, which is why this step exists:
> all signing happens on your Mac with your account, never in the VM.

---

## 3. One-time Apple Developer setup (developer.apple.com)

Do this once per Apple Developer account.

1. **Enroll** in the Apple Developer Program ($99/yr) if you haven't.
2. **App ID:** register `com.cashie.app`, or let Xcode auto-create it on first
   build (Automatic signing does this).
3. **Capabilities** to enable on the App ID:
   - **Sign in with Apple** (needed for Floor B; harmless to enable now).
   - Push Notifications only if you later add remote push. Local reminders do not
     need it, so leave it off for now.
4. **Sign in with Apple key** (only if doing Floor B): Certificates, Identifiers &
   Profiles -> Keys -> create a "Sign in with Apple" key. Save the `.p8`, the Key
   ID, and your Team ID. You feed these to Supabase later (`GO_LIVE_RUNBOOK.md`
   section 3b).

---

## 4. Open on the Mac and set signing

1. Open `Cashie.xcodeproj` in **Xcode 15.4+** (it's an `.xcodeproj`, no workspace).
2. There are **no SPM packages** to resolve (native StoreKit 2) - the project opens ready to build.
3. Select the `Cashie` target -> **Signing & Capabilities**:
   - Check **Automatically manage signing**.
   - Set **Team** to your Apple Developer team. (This is the one thing the VM
     literally cannot do.)
4. Build for a **simulator** first as a clean baseline (Cmd+B). Fix nothing if it
   builds - it should.

---

## 5. Add the Sign in with Apple capability (one real gap)

The Sign in with Apple button exists in `Cashie/Onboarding/SignInScreen.swift`,
but the project has **no `.entitlements` file**, so the entitlement isn't declared
yet. Without it, the button will fail on a real device/submission.

1. Target -> Signing & Capabilities -> **+ Capability** -> **Sign in with Apple**.
   - Xcode creates `Cashie/Cashie.entitlements` and wires
     `CODE_SIGN_ENTITLEMENTS` automatically. Commit that file.
2. Face ID needs no capability, only the usage string, which is already present
   (`NSFaceIDUsageDescription` in `Info.plist`). Nothing to do.

> If you ship Floor A (offline-only) and want to keep it dead simple, you can
> remove the Sign in with Apple button instead of adding the entitlement. But
> since the button is already there and review expects offered features to work,
> adding the capability is the cleaner path.

---

## 6. Fill in keys (only what your floor needs)

In `Cashie/App/Config.swift`:

- **Floor A (offline):** leave both keys empty. The app runs on the StoreKit
  fallback and the on-device store. Skip to section 7.
- **Floor B (accounts):**
  - `supabaseAnonKey` = the Supabase anon/publishable key (Settings -> API).
  - (No RevenueCat key - subscriptions are native StoreKit 2.)
  - Keep `Config.swift` out of any public git (gitignore it, or move keys to an
    xcconfig). The anon key is safe to ship (RLS protects data) but don't leak it
    in a public repo.
  - Full backend wiring (Apple provider in Supabase, token handoff) is
    `GO_LIVE_RUNBOOK.md` sections 3-4, and the code task is section 9 below.

---

## 7. Build and run on your iPhone

1. Plug in the iPhone, select it as the run destination in Xcode.
2. Cmd+R. First run: on the device, trust the developer profile under
   Settings -> General -> VPN & Device Management.
3. Smoke test on-device:
   - Onboarding completes, Face ID lock works.
   - Add a spend, ranks/Today/Spend update.
   - Open the paywall: with the bundled `Cashie.storekit` scheme option on, the
     real iOS purchase sheet appears (sandbox prices).
   - Floor B only: Sign in with Apple completes and a row appears in Supabase.

---

## 8. Subscriptions: App Store Connect (native StoreKit 2)

The product ids must match the app **exactly** or purchases won't resolve. There
is **no RevenueCat** - the `pro` entitlement is read straight from Apple's
`Transaction.currentEntitlements`, so there is no dashboard, entitlement, or
offering to configure.

1. **App Store Connect -> your app -> Subscriptions:** create one subscription
   group ("Cashie Pro"), then **two** auto-renewable subscriptions with these
   exact product ids, prices, and **NO introductory offer (no trial)**:

   | Plan | Product ID | Price | Role |
   |---|---|---|---|
   | Monthly | `cashie_pro_monthly` | $9.99 | shown on paywall |
   | Yearly | `cashie_pro_yearly_v2` | $29.99 | shown on paywall (preselected; "SAVE 75%") |

   Set a localized display name and a review screenshot for each.
2. **How the paywall uses them:** one screen, one offer - the yearly
   (`cashie_pro_yearly_v2`, preselected) and monthly shown side by side, with the
   yearly's struck-through `$119.88` (12 x $9.99) backing the "SAVE 75%" badge.
   No exit-intent / rescue products (removed for Guideline 5.6). Both resolve to
   the same `pro` entitlement.
3. **Sandbox test on device:** add a sandbox tester in App Store Connect, sign in
   under Settings -> App Store -> Sandbox Account on the device, then verify
   purchase + restore + paywall gating in the build.

(Both products must be created and approved - the paywall is core to the app. The
`.storekit` file only drives the simulator/Xcode runs; on a real device a purchase
no-ops until the products exist in App Store Connect.)

---

## 9. Code task gating Floor B (accounts/sync) - skip for Floor A

Today the Sign in with Apple button only reads the user's name/email to
personalize onboarding (`SignInScreen.handleCompletion`). It does **not** exchange
the Apple identity token for a Supabase session, and `SupabaseAuth.swift` does not
exist yet. Until this is done, there are no real accounts and no cross-device sync.

To finish it, follow `GO_LIVE_RUNBOOK.md` section 4 verbatim:
- Create `Cashie/Services/SupabaseAuth.swift` (the full URLSession-only
  implementation is in that doc).
- In `SignInScreen`, generate a raw nonce, send `sha256(nonce)` on the Apple
  request, and on success pass `credential.identityToken` + the raw nonce to
  `SupabaseAuth.shared.signInWithApple(...)`.
- In `CashieApp.init`, build the live remote with
  `LiveSupabaseService.makeIfConfigured(tokenProvider:)` pointed at
  `SupabaseAuth.shared.validAccessToken`.
- Persist the refresh token in the Keychain so sessions survive relaunch (the
  runbook leaves this as a TODO - close it before shipping accounts).

Then Quick Log Shortcuts (`GO_LIVE_RUNBOOK.md` section 6) becomes available, since
it depends on a signed-in user to mint a key.

---

## 10. Create the App Store Connect app record + listing

1. App Store Connect -> Apps -> + -> New App:
   - Platform iOS, **Name: Cashie**, primary language, bundle id `com.cashie.app`,
     SKU (any unique string), Finance category.
2. Listing: description, keywords, support URL, **privacy policy URL** (required),
   and screenshots for 6.7" and 6.5" iPhone (add iPad sizes only if you support
   iPad - this app is iPhone portrait, so iPhone sizes suffice).
3. **App Privacy:** declare data collection. With Floor B that includes account
   info, financial info, and identifiers; with Floor A (no backend) it is minimal,
   but still declare anything stored. Be accurate - review checks this.
4. If you offer Sign in with Apple, App Review requires it to actually work, which
   is another reason to finish section 5 (and 9 for Floor B).

---

## 11. Archive and upload to TestFlight

1. Set destination to **Any iOS Device (arm64)**, build configuration Release.
2. Bump build number if re-uploading (`CURRENT_PROJECT_VERSION`).
3. Product -> **Archive**.
4. Organizer -> **Distribute App** -> App Store Connect -> Upload. Let it validate.
5. App Store Connect -> TestFlight: wait for processing, add internal testers
   (you), then external testers if you want a wider beta (needs a short Beta App
   Review). Add test notes and, for Floor B, a demo account.
6. Install via the TestFlight app on a clean device and re-run the smoke test.

---

## 12. App Store submission and review

1. Attach the build to the App Store version.
2. Attach the two IAP subscriptions to the version (first submission reviews the
   IAPs alongside the build).
3. Fill "App Review Information": contact, and for Floor B a working demo account
   the reviewer can sign into.
4. Submit. Respond to any reviewer messages using the demo account.

---

## 13. Pre-flight checklist

Shared:
- [ ] Code off the VM, opens and builds on the Mac (simulator clean).
- [ ] Team set, Automatic signing, builds to a real device.
- [ ] **Sign in with Apple capability added** (`Cashie.entitlements` exists) OR the
      button removed for an offline-only ship.
- [ ] Two IAPs created in App Store Connect with exact ids
      (`cashie_pro_monthly` $9.99, `cashie_pro_yearly_v2` $29.99), NO trial.
- [ ] Sandbox purchase + restore verified on device; paywall gates correctly.
- [ ] App Store record uses public name **Cashie**, bundle id `com.cashie.app`.
- [ ] Privacy policy URL + App Privacy declarations filled accurately.
- [ ] Crash-free pass over every screen on a real device.
- [ ] TestFlight build validated on a clean device before submitting.

Floor B only (accounts/sync):
- [ ] `Config.supabaseAnonKey` set; `Config.swift` kept out of public git.
- [ ] Apple auth provider configured in Supabase (Services ID, Team ID, Key ID,
      `.p8`).
- [ ] `SupabaseAuth.swift` built and token provider wired into
      `LiveSupabaseService.makeIfConfigured` (section 9).
- [ ] Keychain persistence of the refresh token done (survives relaunch).
- [ ] Live sync verified across two devices; offline (airplane mode) still works
      and writes flush on reconnect.
- [ ] Quick Log: mint key in app, import shortcut, fire via Back Tap, spend lands
      in the right account live; revoked key is rejected.
- [ ] Supabase advisor reviewed: only the documented intentional notes remain.
- [ ] No `service_role` key anywhere in the app or git.

---

## Appendix: where things live

| Concern | File |
|---|---|
| Keys / endpoints | `Cashie/App/Config.swift` |
| Display name / Face ID string / fonts | `Cashie/Info.plist` |
| Sign in with Apple button | `Cashie/Onboarding/SignInScreen.swift` |
| StoreKit products (ids + prices) | `Cashie/Resources/Cashie.storekit` |
| StoreKit subscriptions + funnel | `Cashie/Services/StoreKitService.swift`, `SubscriptionService.swift`, `Onboarding/PaywallScreen.swift`, `Integration.md` |
| Paywall funnel strategy | `pricing-and-paywall-optimization-plan.md` |
| Sync engine + live service | `Cashie/Services/SupabaseService.swift` |
| Supabase auth (to add) | `Cashie/Services/SupabaseAuth.swift` (section 9) |
| Container wiring | `Cashie/App/AppContainer.swift` |
| Deep backend runbook | `GO_LIVE_RUNBOOK.md` |
| Tickable checklist (HTML) | `GO_LIVE_CHECKLIST.html` |
