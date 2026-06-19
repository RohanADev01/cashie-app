# Cashie - App Store Submission Package

Everything needed to submit **Cashie** to the App Store, in one folder. Built to
be moved onto a Mac with Xcode. Start here, then follow the five steps below. The
detailed runbooks live in `docs/`.

## Key facts

| Thing | Value |
|---|---|
| App name | Cashie |
| Bundle ID | `com.cashie.app` |
| Platform | iOS (iPhone; iOS 16+) |
| Subscription | Cashie Pro - monthly + yearly + two exit-intent rescue offers, auto-renew, **hard paywall, NO free trial** |
| IAP backend | **Native StoreKit 2** (no third-party SDK, no purchase key) |
| Auth model | Offline-first, anonymous, **no login** |
| Backend | Supabase project `fsmdklrrcnnwyzenuaed` (**us-east-1**) |
| Legal entity | SynrgyConnect Pty Ltd, 477 Pitt Street, Haymarket NSW 2000 |
| Website domain | `cashie.space` (ships separately as `cashie-website.zip`) |
| Support email | `cashieapp@outlook.com` |
| Privacy Policy URL | `https://cashie.space/privacy` |
| Support URL | `https://cashie.space/support` |
| Terms / EULA | Apple standard EULA (`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`) |

## What's in this folder

```
cashie-app-store-package/
├── START_HERE.md            <- this file (the master guide)
├── app/                     <- the iOS app (open & build in Xcode)
│   ├── Cashie/              <- all Swift source, Info.plist, Assets, Cashie.storekit
│   ├── Cashie.xcodeproj/    <- project + shared scheme (no SPM dependencies)
│   └── scripts/             <- gen_pbxproj.py (regenerates the project file)
├── app-store-connect/       <- everything you paste into App Store Connect
│   ├── APP_STORE_CONNECT_FIELDS.md  <- paste-ready: name, description, keywords, privacy answers, subscriptions
│   └── screenshots/         <- ready-to-upload (iphone_6.9_inch, iphone_6.5_inch, ipad_13_inch, subscriptions)
├── backend/                 <- Supabase edge functions for Quick Log (optional, see Step 3)
│   └── functions/           <- quick-log, mint-quick-log-key
└── docs/                    <- detailed runbooks & checklists (read these as you go)
```

> The **website** (landing page + Apple-required privacy / support / terms pages)
> ships **separately** as **`cashie-website.zip`**, alongside this package - see Step 2.

## Before you start (prerequisites)

- A Mac with **Xcode 26+** (iOS 26 SDK or later) and a paid **Apple Developer
  Program** account. Apple rejects uploads built with an older SDK at validation,
  so do not archive from Xcode 16/iOS 17.5.
- **App Store Connect** access; create the app record (bundle id `com.cashie.app`).
- A static host for the website (**Vercel** recommended) and control of the
  **cashie.space** DNS.
- The **`cashieapp@outlook.com`** inbox must be live and monitored (Apple checks
  the Support URL and may email it).
- (Optional, for Quick Log) the **Supabase CLI** and access to the Supabase project.

---

## Step 1 - Build & upload the app

1. Open `app/Cashie.xcodeproj` in Xcode. There are **no Swift packages to
   resolve** - subscriptions use native StoreKit 2.
2. Select the **Cashie** target → Signing & Capabilities → set your **Team**.
   Confirm the bundle id is `com.cashie.app`.
3. **Fill in the secrets** in `app/Cashie/App/Config.swift` (empty in source by
   policy - the app runs offline/fallback until you paste real values). There is
   **no purchase key** - StoreKit needs none:

   | Key | What to paste | If left empty |
   |---|---|---|
   | `supabaseAnonKey` | Supabase anon key (project `fsmdklrrcnnwyzenuaed`) | sync stays off (offline-only) |
   | `appStoreID` | numeric App Store ID (after the app record exists) | review deep-link is skipped |
   | `postHogAPIKey` | PostHog `phc_...` write key | analytics fully dormant |
   | `quickLogShortcutImportURL` + `applePayShortcutImportURL` | the two published iCloud Shortcut links (tap triggers + Apple Pay) | both currently a placeholder (`google.com`) |

4. **Do not hand-edit `project.pbxproj`** - it's generated. If you add/remove Swift
   files, run `python3 app/scripts/gen_pbxproj.py` to regenerate it.
5. Select **Any iOS Device (arm64)** → **Product → Archive** → in the Organizer,
   **Distribute App → App Store Connect → Upload**. (The uploaded build is what
   App Review reviews - this package is the kit you build from, not the upload.)

> Full step-by-step with signing/troubleshooting: `docs/APP_STORE_PUBLISH_RUNBOOK.md`
> and the master `docs/GO_LIVE_RUNBOOK.md`.

## Step 2 - Deploy the website to cashie.space

The website ships separately as **`cashie-website.zip`** (alongside this package).
Unzip it - it contains a `website/` folder with everything referenced below.

1. The deployable site is **`website/site/`** (it already contains
   `index/privacy/support/terms.html`, `vercel.json`, and `assets/`).
2. Deploy to Vercel (drag-drop `website/site/` or `vercel --prod` from inside it),
   then attach the **cashie.space** domain. `vercel.json` enables clean URLs so
   `/privacy`, `/support`, `/terms` resolve without `.html`.
3. Verify over HTTPS in an incognito window:
   `https://cashie.space/`, `/privacy`, `/support`, `/terms`.

> Editing & redeploy details: `website/DEPLOY.md`. Support-inbox reply templates:
> `website/SUPPORT_RESPONSES.md`.

## Step 3 - (Optional) Deploy the Quick Log backend

Only needed if you ship the Back Tap / Action Button / Apple Pay quick-logging
feature. The Supabase edge functions are in `backend/functions/`
(`quick-log`, `mint-quick-log-key`).

1. Deploy them with the Supabase CLI (`supabase functions deploy quick-log` etc.).
   `mint-quick-log-key` verifies Pro via Apple's **App Store Server API** - set
   its edge secrets (`APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY`);
   see `docs/GO_LIVE_RUNBOOK.md` §6c.
2. Publish the two iCloud Shortcuts - **"Cashie Quick Log"** (tap triggers) and
   **"Cashie Apple Pay Log"** (Wallet automation) - then set
   `quickLogShortcutImportURL` and `applePayShortcutImportURL` in `Config.swift`.

> Setup walkthrough: `docs/CASHIE_TAP_AUTOMATION.md` and `docs/BACKEND_SYNC_REPORT.md`.

## Step 4 - Fill App Store Connect metadata

1. Open `app-store-connect/APP_STORE_CONNECT_FIELDS.md` - it has paste-ready content
   for every field (name, subtitle, description, keywords, promo text, the
   subscription group + four products, App Privacy answers, review notes). Section
   0 lists the only values you must supply yourself.
2. Upload marketing screenshots from `app-store-connect/screenshots/iphone_6.9_inch/`
   (or `iphone_6.5_inch/` if App Store Connect asks for the 6.5" size). The app is
   **iPhone-only**, so there is no iPad slot - ignore `ipad_13_inch/`. The
   **subscription** review screenshots (one per product) are in
   `app-store-connect/screenshots/subscriptions/`.
3. Set the URLs: **Privacy Policy** → `https://cashie.space/privacy`,
   **Support** → `https://cashie.space/support`, **EULA** → Apple's standard EULA.

## Step 5 - Submit for review

1. Create a **Sandbox tester** and add **App Review notes** explaining how to get
   past the hard paywall. The fields sheet has the exact note to paste.
2. Answer **export compliance** (no non-exempt encryption).
3. Work top-to-bottom through **`docs/GO_LIVE_RUNBOOK.md`** - the master pre-submit
   checklist - then hit **Submit for Review**.

---

## Must-fix before you submit (don't skip these)

- [ ] `Config.swift` secrets pasted in (`supabaseAnonKey`, plus `appStoreID`,
      `postHogAPIKey`, and the two Shortcut links if shipping Quick Log). No purchase key needed.
- [ ] All **four** products created in App Store Connect, in one "Cashie Pro"
      subscription group, **no free trial**, IDs matching `StoreKitService.productIDs`:
      `cashie_pro_monthly` $9.99, `cashie_pro_yearly` $79.99,
      `cashie_pro_yearly_mid` $35.88, `cashie_pro_yearly_special` $23.88
      (the last two are the exit-intent rescue offers) - **see `docs/GO_LIVE_RUNBOOK.md` §2.**
- [ ] **Supabase: enable Anonymous sign-ins** on project `fsmdklrrcnnwyzenuaed`
      (the app creates a silent anonymous account; without this, sync/auth fails).
- [ ] (If shipping Quick Log) set the App Store Connect API key edge secrets so
      `mint-quick-log-key` can verify Pro via Apple's App Store Server API - **`docs/GO_LIVE_RUNBOOK.md` §6c.**
- [ ] Website live at cashie.space (privacy / support / terms resolve over HTTPS).
- [ ] `quickLogShortcutImportURL` + `applePayShortcutImportURL` no longer the `google.com` placeholder (if shipping Quick Log).
- [ ] Remaining integration items in `docs/INTEGRATION_TODO.md` closed out.

## Detailed docs (in `docs/`)

- **`GO_LIVE_RUNBOOK.md`** (+ `.html`) - the master end-to-end go-live runbook.
- **`GO_LIVE_CHECKLIST.html`** - the condensed checklist.
- **`APP_STORE_PUBLISH_RUNBOOK.md`** - Xcode archive → upload specifics.
- **`FINALIZATION_REPORT.md`** - current state / what's done.
- **`SECURITY_AUDIT.md`** - security review notes.
- **`FEATURE_TEST_CHECKLIST.md`** - QA pass before submitting.
- **`BACKEND_SYNC_REPORT.md`** - Supabase sync & Quick Log backend status.
- **`INTEGRATION_TODO.md`** - remaining integration tasks.
- **`CASHIE_TAP_AUTOMATION.md`** (+ `.html`) - Quick Log / Shortcut setup (two shortcuts).
- **`BADGES_AND_RANKS.md`** - badge & rank system reference.
