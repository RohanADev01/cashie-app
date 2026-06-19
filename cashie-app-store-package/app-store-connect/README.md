# Cashie - App Store submission kit

Everything to fill in an App Store Connect submission, plus ready-to-upload
screenshots. Generated 2026-06-13.

## What's here

- **`APP_STORE_CONNECT_FIELDS.md`** - the fill-in sheet. Every App Store Connect
  field with paste-ready content: app name, subtitle, description, keywords,
  promo text, URLs, pricing, the subscription group + both products (no free
  trial), the subscription review screenshots, App Privacy nutrition-label
  answers, App Review notes (with the Sandbox path for the hard paywall), export
  compliance, and a final submit checklist. Section 0 lists the only values you
  must supply yourself; everything else pastes verbatim.

- **`screenshots/`** - ready-to-upload images built from real in-app captures:
  - `iphone_6.9_inch/` - 1320 x 2868, 7 marketing images.
  - `iphone_6.5_inch/` - 1242 x 2688, the same 7 images fitted to the 6.5" size.
    App Store Connect takes EITHER the 6.9" or the 6.5" iPhone set - upload
    whichever matches the size its upload box asks for.
  - `ipad_13_inch/` - 2064 x 2752, kept for reference only. The app is
    **iPhone-only**, so no iPad screenshots are needed (App Store Connect won't
    show an iPad slot).
  - `subscriptions/` - the subscription review screenshot (the single paywall
    showing both plans). Attach `01_paywall_monthly_and_yearly.png` to each of
    the two products per §5 of the sheet.
  - 24-bit PNG, no transparency, each well under 8 MB.
  - Regenerate marketing set: `python3 scripts/gen_app_store_screenshots.py`

## Before you submit

1. Do `GO_LIVE_RUNBOOK.md` section 2 first (create the `cashie_pro_*` subscription
   products in App Store Connect with IDs matching `StoreKitService.productIDs`)
   or no one can subscribe. Subscriptions are native StoreKit 2 - no RevenueCat.
2. Host the Terms of Use + Privacy Policy pages at the `Config` URLs (they are
   linked from the in-app paywall and required by App Review).
3. Set the keys in `Cashie/App/Config.swift` and test on a device per the runbook
   before archiving.

The runbook (`GO_LIVE_RUNBOOK.md` / `.html`) is the end-to-end sequence; this
folder is just the App Store Connect data-entry part of it.
