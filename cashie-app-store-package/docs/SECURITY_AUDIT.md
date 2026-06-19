# Cashie security and production-readiness audit

> **Update (2026-06-10):** the RevenueCat SDK was removed; subscriptions now use
> **native StoreKit 2**. This *reduces* the attack surface described below - there
> is no longer a `purchases-ios` SPM dependency, no `api.revenuecat.com` runtime
> egress, and no RevenueCat customer aliasing. Egress/dependency rows that mention
> RevenueCat are obsolete. The Quick Log mint Edge Function's server-side `pro`
> check has been re-implemented on Apple's **App Store Server API** (no RevenueCat);
> it needs only an App Store Connect API key, set as edge secrets - see
> `GO_LIVE_RUNBOOK.md` section 6c.

Date: 2026-06-07
Scope: the full iOS app source (~17K lines of Swift), the Xcode build config, and
the Supabase backend.
Goal: prove the app is safe to run, free of malware / backdoors / data
exfiltration, and ready for production.

Method: three independent code audits run in parallel over the whole codebase
(1: malware and exfiltration, 2: crash-safety, 3: data-security and privacy),
plus manual review of the network, storage, auth, and payment paths, plus backend
verification through the Supabase MCP (RLS, grants, advisors).

---

## Verdict: SAFE TO RUN. No malice found.

> The bullets below describe the 2026-06-07 audit. Features added since (identity,
> hard paywall, PostHog analytics, secure Quick Log keys) qualify two of them; see
> the **Update 2026-06-08** section immediately below.

- No malware, no backdoor, no data exfiltration. (Product analytics was later
  added: first-party usage events to PostHog over REST, no ad/cross-app tracking,
  no IDFA - see the 2026-06-08 update.)
- At audit time the only network destination was the user's own Supabase project,
  over HTTPS / WSS, dormant until a key + sign-in are added. Destinations added
  since: PostHog (analytics, once a key is set). Apple's App Store handles purchases natively.
- No insecure transport, no certificate-validation bypass, no dynamic or
  obfuscated code, no private-API abuse, no clipboard scraping, no device
  identifiers, no analytics **SDKs** (the added analytics is hand-rolled REST,
  no SDK, no session replay).
- Builds clean (Debug and Release) and launches without crashing in the
  production configuration (verified on the simulator).

---

## Update 2026-06-08 (changes since the audit)

Features added after this audit: a silent **anonymous Supabase identity** (`AuthClient.swift`), a **hard paywall** + Pro-gating, **PostHog analytics** (REST, no SDK), and **Pro-verified, rate-limited Quick Log keys** (two Edge Functions). Net security effect is neutral-to-positive. Full detail in `IMPLEMENTATION_PLAN_identity_paywall_analytics.md`.

**New app-side network destinations:**
- `https://us.i.posthog.com` (or your region) - first-party product-usage analytics over HTTPS. Dormant until `Config.postHogAPIKey` is set.
- The project's own Supabase Edge Functions (`mint-quick-log-key`, `quick-log`). `mint-quick-log-key` calls Apple's App Store Server API (`api.storekit.itunes.apple.com`) server-side to verify the subscription; no purchase service is contacted from the app.

**Analytics (corrects "no analytics" above):** the app now sends first-party product-usage events (onboarding funnel, app opens, spends logged) to PostHog, a third-party analytics processor, keyed to the anonymous Supabase uid. Still NO cross-app/ad tracking, NO IDFA / ATT, NO device identifiers, NO session replay, NO SDK. Declare as usage data "not used for tracking" under App Privacy + `PrivacyInfo.xcprivacy`.

**Secrets posture:** `Config.swift` holds only PUBLIC client values (Supabase anon, PostHog write key) - safe to ship; native StoreKit needs no purchase key. Sensitive secrets (`SUPABASE_SERVICE_ROLE_KEY`, and the App Store Connect API key trio `APPSTORE_ISSUER_ID` / `APPSTORE_KEY_ID` / `APPSTORE_PRIVATE_KEY`) are Edge-Function-only, never in the app or repo.

**Backend hardening (improves the advisor state below):** the SECURITY DEFINER functions are locked down - `quick_log()`, `issue_quick_log_key()`, `issue_quick_log_key_for()`, `quick_log_guarded()`, and `quick_log_bump()` are revoked from `anon`/`authenticated` (callable by no external role). Minting is Pro-gated (verified server-side against Apple's App Store Server API) and service-role-only; inserts go through the rate-limited `quick_log_guarded` (per-IP 60/min, per-key 10/min + 200/day).

**Residual risk to mitigate before launch:** the public anon key allows scripted anonymous sign-ups (auth.users / row bloat) - enable Supabase CAPTCHA / Attack Protection. Identity is per-install (local Keychain), so there is no cross-device sync or reinstall data restore (a deliberate simplicity choice).

---

## What the app talks to (complete list)

| Destination | Owner | Purpose | Verdict |
|---|---|---|---|
| `https://fsmdklrrcnnwyzenuaed.supabase.co` (+ `wss://` realtime, + `/functions/v1/` Edge Functions) | The user's own Supabase | App data sync + Quick Log key mint/post, dormant until key + auth | Safe |
| `https://apps.apple.com/...` | Apple | Manage subscription, write a review | Safe |
| `App-prefs:...ACCESSIBILITY` | Apple (iOS Settings) | Deep link to Back Tap / Action Button setup | Safe |
| `mailto:cashieapp@outlook.com` | App support | Opens Mail, no data attached | Safe |
| `https://us.i.posthog.com` (your region) | PostHog | First-party product-usage analytics (REST, no SDK); dormant until `postHogAPIKey` set | Safe (declared usage data) |
| `https://api.storekit.itunes.apple.com` | Apple | App Store Server API - server-side (Edge Function) subscription verification for Quick Log minting; never called from the app | Safe |

Aside from first-party PostHog product analytics (added 2026-06-08; no SDK, no
tracking, no session replay), no other telemetry, pastebin, webhook, or unknown
host exists anywhere in the app. No IDFA, no `identifierForVendor`, no
AppTrackingTransparency.

---

## Crash-safety: ship-safe

Zero reachable crash risks. Every money and progress division is guarded against
zero, so empty budgets, zero-target goals, and brand-new accounts all degrade to
a safe `0` instead of trapping. All stored and remote data decodes through safe
fallbacks. There are no `try!`, `as!`, or `fatalError` calls in the app code. The
few force-unwraps that exist are on compile-time constants.

---

## Data security: hardened in this pass

Findings from the audit and the fixes applied:

| Was | Now |
|---|---|
| Financial JSON stored in plaintext with only default protection | Written with `.completeFileProtection` (encrypted at rest, unreadable while the device is locked) |
| Data directory included in device backups | Excluded from iCloud / iTunes / Finder backups (it re-syncs from Supabase, so this is lossless) |
| Privacy lock failed OPEN on a device that cannot evaluate biometrics (a dev passthrough) | Fails CLOSED on a real device; the simulator passthrough is now `#if targetEnvironment(simulator)` only |
| App switcher could snapshot live balances | The veil now raises on `willResignActive`, before the system snapshot is taken |
| CSV export temp file unprotected | Written with `.completeFileProtection` |
| One force-unwrap on the live-sync REST path | Now throws instead of force-unwrapping |

Permissions remain minimal (Face ID only, declared in `Info.plist`). There is no
sensitive logging anywhere: the only log statements are DEBUG-gated and print
collection counts, never amounts, email, tokens, or request bodies.

---

## Production hardening (this pass)

- Fake demo data (sample transactions and goals) is now DEBUG-only. Release first
  launch starts empty. Dev builds keep the sample set for screenshots and
  previews.
- Dev launch arguments (`-resetStore`, `-startAt`, `-archetype`, `-resetPaywall`,
  `-resetSubscription`) are now compiled out of release builds entirely, so the
  shipping binary carries no state-reset or screen-jump hooks. (`-syncSelfTest`
  was already DEBUG-only.)
- The app name is "Cashie" everywhere (splash wordmark, lock screen, Face ID
  prompt, Pro plan names, badges, subscription copy). The internal identifiers are
  now also "Cashie": bundle id `com.cashie.app`, the Xcode scheme, and the
  `Cashie.xcodeproj` project file. The `cashie.app` support domain, the
  `cashie_pro_*` StoreKit product IDs, and the `CashieUser` type are all consistent
  with "Cashie". The only remaining "cashly" is the on-disk repo folder name, which
  is dev-machine only and never ships.

---

## Backend (Supabase dev project `fsmdklrrcnnwyzenuaed`)

- RLS is enabled on every table; policies scope rows to `auth.uid() = user_id`.
- `anon` (not signed in) has zero data access (no SELECT / INSERT / UPDATE /
  DELETE on any user table). `authenticated` has CRUD, but only on its own rows.
- No `service_role` key anywhere in the app or the repo.
- All per-user tables were reset to 0 rows (clean production slate). `auth.users`
  and the marketing `contact_messages` table were intentionally left untouched.
- Advisor (updated 2026-06-08): the two previously-flagged SECURITY DEFINER
  exposure notes are now **resolved** - `quick_log()` and `issue_quick_log_key()`
  are revoked from `anon`/`authenticated` (callable by no external role).
  Remaining notices, both documented and intentional:
  1. `citext` extension installed in `public` (pre-existing; moving it risks the
     existing `contact_messages.email` column type).
  2. `quick_log_rate` has RLS enabled with no policies (INFO) - intentional: the
     rate-limit table is locked to the SECURITY DEFINER functions / service-role
     only, so no PostgREST access is wanted.
- Quick Log entry points are now Edge Functions: `mint-quick-log-key` (Pro-gated,
  verifies the subscription via Apple's App Store Server API, mints via the
  service-role-only `issue_quick_log_key_for(uid)`) and `quick-log` (rate-limited
  `quick_log_guarded`). No `service_role` key or App Store Connect API key in the app/repo.

---

## Build and run verification

- Debug build: BUILD SUCCEEDED.
- Release build: BUILD SUCCEEDED, warning-clean.
- Release binary installed and launched on the iPhone 15 Pro simulator from a
  clean install: it launches, the splash shows "CASHIE", it advances into
  onboarding, and the process stays alive (no crash).

---

## Honest gaps (need a real Mac plus device, cannot be done in this VM)

- A live round trip needs the Supabase anon key in `Config`, the **Anonymous**
  provider enabled (+ CAPTCHA), and on-device verification. The anonymous auth
  client (`AuthClient.swift`) and token wiring are done (no Sign in with Apple);
  the rest is config + device testing (see the 2026-06-08 runbook update).
- Quick Log key minting IS wired (Pro-gated, server-minted, cached). Remaining:
  set the App Store Connect API key edge secrets (`APPSTORE_ISSUER_ID` /
  `APPSTORE_KEY_ID` / `APPSTORE_PRIVATE_KEY`), publish the iCloud Shortcut, and
  wire its link into `Config.quickLogShortcutImportURL`; then device-test the
  mint -> copy -> Shortcut -> insert flow (runbook section 6c / 7).
- A `PrivacyInfo.xcprivacy` manifest is required and must now declare the added
  product-usage analytics (PostHog) as usage data **not** used for tracking, plus
  required-reason APIs. Keep the App Privacy nutrition label in sync.
- Anonymous-signup abuse: enable Supabase CAPTCHA / Attack Protection before launch.

---

## Backup

A full source backup was taken before any change in this pass:
`backups/cashly_pre_prod_20260607-005707.tar.gz` (excludes only the regenerable
build output).
