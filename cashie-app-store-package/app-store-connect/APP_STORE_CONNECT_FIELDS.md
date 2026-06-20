# Cashie - App Store Connect submission (fill-in sheet)

Every field App Store Connect asks for, with paste-ready content. Everything is
filled in except the handful of values only you can supply (see the table just
below) - those are marked `<...>` throughout. Copy is written in Cashie's voice
("Money, but actually kind."). Last updated 2026-06-13.

> Heads-up on the hard paywall: the whole app is behind the subscription. Apple
> reviews behind the paywall, so the reviewer MUST be able to subscribe. Give
> them a working Sandbox path (see section 9, App Review Information). A 100%
> hard paywall can draw a 3.1.1/2.1 question; the review notes below pre-empt it.

---

## 0. Inputs only you can supply (gather these first)

These are the ONLY values not pre-filled below. Get them ready and the rest of
this sheet is straight copy-paste.

| Placeholder | Where it's used | What to put |
|---|---|---|
| `<your legal name or company>` | Copyright (§2), App Review contact (§9) | Your real name or registered company. Also fills the website privacy policy. |
| `<your phone>` | App Review Information (§9) | A real phone number Apple can reach. |
| `<sandbox email>` / `<sandbox password>` | App Review notes (§9) | A Sandbox tester you create in App Store Connect → Users and Access → Sandbox → Testers. Create it before you submit. |
| `appStoreID` (numeric) | `Config.swift`, in-app "Rate" link | Auto-assigned by Apple the moment you create the app record (§1). Paste it back into `Config.swift` then. |

Everything else - name, subtitle, description, keywords, all four subscription
products and prices, privacy answers, review notes - is final text you can paste
verbatim.

---

## Order of operations in App Store Connect

1. Create the app record (section 1).
2. Create the subscription group + products (section 5) - do this early; new
   subscriptions need processing time and a first review with the build.
3. Set pricing/availability (section 4).
4. Fill App Information + this version's metadata (sections 1-3).
5. Upload screenshots (section 7).
6. Complete App Privacy (section 8).
7. Upload the build from Xcode (Archive -> Distribute), attach it, add the
   subscriptions to the version.
8. App Review Information (section 9) + Export compliance (section 10).
9. Submit.

---

## 1. App Information (set once, app-level)

| Field | Value |
|---|---|
| App Name (max 30) | `Cashie: Smart Budget Tracker` |
| Subtitle (max 30) | `Know what's safe to spend` |
| Bundle ID | `com.cashie.app` |
| SKU | `cashie-ios-001` |
| Primary Language | English (U.S.) |
| Primary Category | Finance |
| Secondary Category | Lifestyle |
| Content Rights | Does NOT contain, show, or access third-party content -> "No" |
| Age Rating | 4+ (answer every questionnaire item "None"; not in Kids category; no unrestricted web) |

Alternate name options if `Cashie: Smart Budget Tracker` is taken: `Cashie - Budget & Save` (22), `Cashie: Daily Budget` (20).

> Home-screen icon label stays the short `Cashie` (`CFBundleDisplayName` in `Info.plist`). The long `Cashie: Smart Budget Tracker` is the App Store listing name only; a 28-character title would truncate under the icon.

---

## 2. This version's metadata (per-localization; do English first)

### Promotional Text (max 170, editable anytime without review)
```
Cashie tells you what's safe to spend today, helps you save for what actually matters, and logs a spend in one tap. Money, but actually kind.
```

### Description (max 4000)
```
Cashie is the budgeting app that finally feels kind.

Most money apps make you feel behind. Cashie does the opposite: it does the math for you and gives you one number you can trust, every single day.

KNOW WHAT'S SAFE TO SPEND
Open Cashie and see exactly how much you can spend today and still hit your goals. No spreadsheets, no guilt, no "where did it all go?".

SEE WHERE IT ACTUALLY GOES
Every expense is sorted and clear at a glance. Spot the leaks, keep the joy, and watch your weekly and monthly picture come together automatically.

SAVE FOR WHAT ACTUALLY MATTERS
Turn the things you want into real, funded goals: a trip, a buffer, a big purchase. Cashie shows you what each goal costs per week so it actually happens.

MEET YOUR MONEY PERSONALITY
A quick quiz builds a plan around how you really spend, not how a banker thinks you should. Your archetype, your traits, your plan.

BUILD HABITS THAT STICK
Streaks, ranks, and small wins turn budgeting into something you actually want to come back to.

LOG A SPEND IN ONE TAP
Set up Quick Log and add a spend with a Back Tap, the Action Button, or Siri, even with Cashie closed. The fastest logging you'll find anywhere.

PRIVATE BY DESIGN
Your data is yours. It is protected on device and synced to your own private, encrypted account. No selling your data, no ad tracking, ever.

SUBSCRIPTION REQUIRED
Cashie is a subscription app. A paid Cashie Pro subscription is required to use the app and unlock all features. Plans:
- Yearly: $29.99 per year (best value)
- Monthly: $9.99 per month

Prices are shown in USD; you are billed in your local currency at the rate shown at checkout. There is no free trial. Payment is charged to your Apple Account at confirmation of purchase. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple Account settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://cashie.space/privacy
```

### Keywords (max 100 chars, comma-separated, no spaces)
```
budget,expense tracker,spending,savings,money manager,budgeting,save money,daily budget,finance,goal
```

### What's New (release notes for 1.2)
```
More polish all around. Your saving goals now show right inside "Where it went" on the home screen, budgets shade from green to amber as you near a cap, and the goal and spend views got cleaner and more consistent. Logging with a tap is quicker to reach too.
```

> Version 1.1 notes (for reference): "A fresh new look. We brightened up the whole app, added little touches of life and motion, refreshed onboarding, and polished a bunch of rough edges. Cleaner, lighter, and nicer to come back to every day."
>
> Version 1.0 notes (for reference): "The first version of Cashie. Know what's safe to spend, save for what matters, and log a spend in one tap. Welcome in."

### URLs
| Field | Value |
|---|---|
| Support URL (required) | `https://cashie.space/support` |
| Marketing URL (optional) | `https://cashie.space` |
| Privacy Policy URL (required) | `https://cashie.space/privacy` |
| Support email | `cashieapp@outlook.com` |

> These pages MUST resolve before review. The in-app paywall Terms/Privacy links
> point at the same targets via `Config.termsOfUseURL` (Apple's standard EULA) and
> `Config.privacyPolicyURL` (`https://cashie.space/privacy`).

### Copyright
```
2026 <Your legal name or company>
```

---

## 3. Localizations (locales)

Ship English (U.S.) first. App Store Connect requires the primary language;
everything else is optional. Recommended add-on locales (the app UI is currently
English, so localize store metadata only, or defer):

- English (U.S.) - REQUIRED, primary. Use the copy above.
- English (U.K.), English (Australia), English (Canada) - optional, reuse the
  U.S. copy (spelling already neutral).
- Defer non-English locales until the app UI is localized, or App Review may flag
  store copy that does not match the app language.

For each added locale, App Store Connect asks for: Name, Subtitle, Promotional
Text, Description, Keywords, Support URL, Marketing URL, and Screenshots.

---

## 4. Pricing and Availability

| Field | Value |
|---|---|
| Price (the app download) | Free (Tier 0) |
| Availability | All territories (or your chosen set) |
| Pre-orders | Off |
| Distribution | Public on the App Store |

Monetization is entirely via the auto-renewable subscriptions in section 5.

---

## 5. Subscriptions (In-App Purchases) - NO free trial

Create ONE subscription group, then the **two** products. Product IDs must
EXACTLY match the app (`StoreKitService.productIDs`); see `GO_LIVE_RUNBOOK.md`
section 2. Subscriptions are native StoreKit 2 - there is no RevenueCat to configure.

**Single paywall (Guideline 5.6):** both products are shown on one paywall,
yearly preselected. The yearly plan ($29.99) carries the discount inline - the
struck-through $119.88 is the genuine 12 x $9.99 monthly cost, so "SAVE 75%" is
truthful. There is NO secondary / exit-intent / "rescue" offer wall (the prior
two-tier funnel was removed to comply with the 5.6 rejection).

### Subscription Group
| Field | Value |
|---|---|
| Reference Name (internal) | `Cashie Pro` |
| Group Display Name / localization (shown to users, English) | `Cashie Pro` |
| App Name (subscription group, if asked) | `Cashie` |

> **Subscription group order/rank:** put `cashie_pro_yearly_v2` at the top, then
> monthly. Rank only affects upgrade/downgrade proration within the group; it
> does not change what the paywall shows.

### Product 1 - Monthly
| Field | Value |
|---|---|
| Product ID | `cashie_pro_monthly` |
| Reference Name (internal) | `Cashie Pro Monthly` |
| Duration | 1 Month |
| Price | $9.99 USD (auto-fills other territories) |
| Display Name (max 30) | `Cashie Pro Monthly` |
| Description (max 45) | `All of Cashie, billed monthly.` |
| Introductory Offer | NONE (do not add a free trial) |
| Review screenshot | `screenshots/subscriptions/01_paywall_monthly_and_yearly.png` |

### Product 2 - Yearly
| Field | Value |
|---|---|
| Product ID | `cashie_pro_yearly_v2` |
| Reference Name (internal) | `Cashie Pro Yearly` |
| Duration | 1 Year |
| Price | $29.99 USD |
| Display Name (max 30) | `Cashie Pro Yearly` |
| Description (max 45) | `All of Cashie, best value. Billed yearly.` |
| Introductory Offer | NONE |
| Review screenshot | `screenshots/subscriptions/01_paywall_monthly_and_yearly.png` |

### Per-product extras (required for review)
- **Localized display name + description** (English at minimum) - the exact text
  is in each product table above. Add it under the product's "App Store
  Localization" section.
- **Review screenshot (required on each of the 2 products)** - the ready-to-upload
  file is named in each table above and lives in
  `screenshots/subscriptions/`. They are real device captures of the live
  paywall, so each price matches its product:
  - `01_paywall_monthly_and_yearly.png` - $9.99 monthly + $29.99 yearly (products 1 & 2)
- **Review note** (paste on each product): `Subscription unlocks the full app (hard paywall). Test with the Sandbox account in the App Review notes. There is a single paywall with both plans; there is no secondary or exit-intent offer.`
- **Subscription privacy policy URL** (App Store Connect asks for this at the
  group level): `https://cashie.space/privacy`.
- **App-specific shared secret:** NOT needed. Native StoreKit 2 verifies
  transactions on device; there is no server doing receipt validation.
- **Tax category:** the default for software subscriptions is fine; no special
  selection needed.

---

## 6. App Review Information helper - subscription terms text

App Review requires the binding terms be visible. They are on the paywall in-app
(price + auto-renew + Terms + Privacy links). The standard Apple-required language
(also in the description) is:

```
Cashie Pro is an auto-renewable subscription. Payment is charged to your Apple Account at purchase confirmation. It renews automatically unless cancelled at least 24 hours before the period ends. Manage or cancel in Apple Account settings.
```

---

## 7. Screenshots

Two kinds, both ready to upload, in `screenshots/`:

**A. Marketing screenshots** (the App Store product page gallery):

| Device class in App Store Connect | Folder | Pixel size | Count |
|---|---|---|---|
| iPhone 6.9" Display | `iphone_6.9_inch/` | 1320 x 2868 | 7 |
| iPhone 6.5" Display | `iphone_6.5_inch/` | 1242 x 2688 | 7 |

> **The app is iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`), so **no iPad
> screenshots are needed or accepted** - App Store Connect won't show an iPad
> slot. The `ipad_13_inch/` folder is left in the package for reference only;
> ignore it. (iPhone-only also avoids the iPad multitasking-orientation upload
> rejection a Universal portrait-only build hits.)

> **Which iPhone set to upload:** App Store Connect accepts EITHER the 6.9" OR
> the 6.5" set for iPhone - you do not need both. Upload whichever matches the
> slot/size your App Store Connect is asking for (it lists the accepted pixel
> sizes next to the upload box). Both folders contain the same 7 images, same
> order; the 6.5" set is the 6.9" set fitted to 1242 x 2688 (no cropping or
> stretching). If unsure, the 6.5" set (1242 x 2688) is accepted on every
> current iPhone record.

**B. Subscription review screenshots** (one required on each of the 2 products,
see §5): `screenshots/subscriptions/` - `01_paywall_monthly_and_yearly.png`.
This is a real capture of the live single paywall, so the on-screen price
($9.99 monthly, $29.99 yearly) matches each product.

- 24-bit PNG, no transparency, each well under 8 MB.
- Apple auto-scales the 6.9" set down to 6.5" and smaller, so you only upload the
  6.9" iPhone set.
- Upload order = filename order (01..07): Today (safe-to-spend), Rank (Legendary),
  Badges, Goals, Money Personality, Quick Log, and "Log in 2 seconds" (the
  tap-the-back-of-your-phone teaser, with the radiating-rings illustration).
  Captured from the latest build (redesigned home + the gamified rank/badges screens).

The app ships **iPhone-only**, so the `ipad_13_inch/` set is not used (kept only
for reference). If you ever decide to ship Universal, you would first make the
screens iPad-adaptive (max-width / centered layout) and add all four iPad
orientations - but that is out of scope for this iPhone-first launch.

Regenerate anytime: `python3 scripts/gen_app_store_screenshots.py`.

App Previews (optional video): not included. If you add one, 6.9" is 886 x 1920
or 1080 x 1920, 15-30s, .mov/.mp4.

---

## 8. App Privacy (nutrition label) - exact answers

These match the bundled `Cashie/Resources/PrivacyInfo.xcprivacy`.

**Does this app collect data? Yes.**
**Do you use data to track users? NO.** (No IDFA, no ATT prompt, no cross-app/site tracking.)

Declare these data types. For each: "Collected", purpose as noted, **Linked to the
user's identity = Yes** (everything is tied to the user's anonymous account id),
**Used for tracking = No**.

| Category -> Data type | Purpose(s) | Linked | Tracking |
|---|---|---|---|
| Financial Info -> Other Financial Info | App Functionality | Yes | No |
| Identifiers -> User ID (anonymous account id; no name/email) | App Functionality, Analytics | Yes | No |
| Purchases -> Purchase History (Apple-native StoreKit; processed by Apple) | App Functionality | Yes | No |
| Usage Data -> Product Interaction (via PostHog) | Analytics | Yes | No |

Notes:
- Cashie collects NO name, email, phone, contacts, location, photos, or contact info.
- Subscriptions are native StoreKit 2 - Apple processes purchases; there is no
  third-party purchase SDK collecting data. PostHog (first-party analytics, only
  if `Config.postHogAPIKey` is set) is the only third party, and ships its own
  privacy manifest covered by the table above.
- If you ship WITHOUT a PostHog key, you may drop the "Product Interaction" row
  and the "Analytics" purpose from the User ID row.

---

## 9. App Review Information

| Field | Value |
|---|---|
| Sign-in required? | **No** (the app creates a silent anonymous account; there is no login) |
| Demo account | Not applicable (no login). Provide a Sandbox tester instead (below). |
| Contact First/Last name | `<your name>` |
| Phone | `<your phone>` |
| Email | `cashieapp@outlook.com` |

### Review Notes (paste this)
```
Cashie has no login. On first launch it silently creates an anonymous account, so no demo credentials are needed.

IMPORTANT - the full app is behind an auto-renewable subscription (hard paywall). To review the main app, please subscribe using a Sandbox account:
1. On the device, sign into a Sandbox Apple Account (Settings > App Store > Sandbox Account). We have created one; credentials: <sandbox email> / <sandbox password>. Or use your own reviewer Sandbox account.
2. Launch Cashie, complete the short onboarding/quiz, reach the paywall, and tap to subscribe to Cashie Pro Monthly (cashie_pro_monthly). The sandbox purchase is free and unlocks everything.
3. You will land on the Today screen with the full app.

Optional feature - Quick Log: the "Quick Log" setup (You tab) mints a private API key and offers a shared Shortcut so a spend can be logged via Back Tap / Action Button / Siri. The key can only ADD a spend to the user's own account; it cannot read or delete data. This is optional and not required to review the app.

Data sync uses the user's own private Supabase account over HTTPS. Subscriptions use Apple's native In-App Purchase (StoreKit). No ad tracking, no IDFA.
```

---

## 10. Export Compliance

Cashie uses only standard encryption (HTTPS/TLS), which is exempt. To skip the
per-build prompt, add to `Cashie/Info.plist`:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```
Then in App Store Connect answer: Uses encryption -> Yes; Qualifies for exemption
(standard encryption only) -> Yes.

---

## 11. Final submit checklist

- [ ] Subscription group + both products created (`cashie_pro_monthly` $9.99, `cashie_pro_yearly_v2` $29.99), prices set, NO introductory offer, the matching `screenshots/subscriptions/` review screenshot attached to each, review note pasted.
- [ ] Product IDs match the app (`StoreKitService.productIDs`); RUNBOOK section 2 done.
- [ ] App Name, Subtitle, Promo Text, Description, Keywords, URLs, Copyright filled (only the §0 `<...>` inputs needed your own values).
- [ ] iPhone marketing screenshots uploaded (6.9" or 6.5"; app is **iPhone-only**, no iPad set).
- [ ] Build made with **Xcode 26+ / iOS 26 SDK** (Apple rejects older SDKs at upload).
- [ ] App Privacy completed per section 8; `PrivacyInfo.xcprivacy` in the build.
- [ ] Support, Marketing, Privacy, and Terms URLs all resolve live.
- [ ] Build uploaded, attached to the version, subscriptions added to the version.
- [ ] App Review notes + Sandbox account provided; contact info set.
- [ ] Export compliance answered (`ITSAppUsesNonExemptEncryption=false`).
- [ ] Age rating 4+ set; content rights "No".
- [ ] Submit for Review.
```
