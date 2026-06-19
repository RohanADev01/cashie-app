# Cashie Tap Automation - Quick Log Shortcuts

How Cashie lets a user log a spend with a triple Back Tap, the Action Button,
or right after Apple Pay, without opening the app. This is the TapSheet pattern,
re-pointed at Cashie's own Supabase backend and adapted to Cashie's transaction
schema.

There are **two shortcuts**, because the triggers are two different workflows:
**Cashie Quick Log** (tap triggers - Back Tap / Action Button) and **Cashie Apple
Pay Log** (the Wallet automation). Each has its own iCloud import link in
`Config.swift` (`quickLogShortcutImportURL` and `applePayShortcutImportURL`).

Last updated 2026-06-13.

---

## 1. The idea (and what is and isn't "the app")

The magic is not in the app. It is a small Apple Shortcut the user imports once
and configures with a personal API key. From then on, firing the shortcut posts
the spend straight to Cashie's API and it shows up in the app.

```
Cashie app                         Apple Shortcuts                Cashie backend (Supabase)
----------                         ---------------                -------------------------
Quick Log setup screen
  - shows a per-user API key  ->   user pastes key once
  - "Import Shortcut" button  ->   imports "Cashie Quick Log"
                                   asks amount / category / note
                                   POST  x-api-key + JSON     ->   insert-only endpoint
                                                                   validates key -> inserts ONE row
                                                                   source = quicklog
App refreshes (realtime / on   <-                              <-  returns { ok, id } only
next open) and the spend shows
```

Two surfaces have to exist:

1. **In-app setup** (YOU tab -> "Set up Quick Log", and the onboarding setup
   screen): show the user their API key so they can copy it, plus an "Import
   Shortcut" button and the steps to paste the key when adding the shortcut.
2. **A pre-built shortcut** the user imports from an iCloud link, which collects
   the spend and POSTs it with their key.

---

## 2. How Cashie differs from TapSheet

TapSheet posts `flowType` / `expenseType` to a generic `/v1/transactions`
endpoint on Render. Cashie does NOT use those fields. Cashie's model is:

| Concept | TapSheet | Cashie |
|---|---|---|
| Backend | Render API (`snapsheet-api.onrender.com`) | Supabase (`fsmdklrrcnnwyzenuaed`) |
| Auth in shortcut | `x-api-key` header | `x-api-key` header (same UX) |
| Expense vs income | `flowType` / `expenseType` fields | inferred from `category` (`income` = income, else expense). No flow fields. |
| Category | free-ish list | fixed `spend_category` enum (10 values) |
| Source tag | n/a | every shortcut row is `source = quicklog` |
| Write scope | insert | insert ONLY (no read, no delete; deletion is app-only) |

---

## 3. Data model mapping (the contract)

Cashie's `public.transactions` columns the shortcut path touches:

| Column | Type | Set by | Notes |
|---|---|---|---|
| `user_id` | uuid | server (from key) | never sent by the shortcut; derived from the key owner |
| `merchant` | text | shortcut | the "description"; trimmed, capped at 80 chars; defaults to "Quick Log" |
| `amount` | numeric | shortcut | must be > 0 and <= 1,000,000; rounded to 2dp server-side |
| `category` | `spend_category` | shortcut | lowercased server-side; invalid -> `other` |
| `note` | text (nullable) | shortcut | optional; blank becomes null |
| `occurred_at` | timestamptz | server | set to `now()` |
| `source` | `transaction_source` | server | forced to `quicklog` |
| `id`, `created_at`, `updated_at` | - | server | defaults |

**`spend_category` values (send one of these exactly; case-insensitive):**
`food`, `transport`, `shopping`, `fun`, `home`, `health`, `bills`,
`income`, `other`.

In the shortcut's "Choose from List", use single-word labels that lowercase
cleanly to those values: **Food, Transport, Shopping, Fun, Home, Health,
Bills, Income, Other**. (The in-app label for `food` is "Food & Drinks", but the
shortcut must send "Food" so it maps to the enum.)

---

## 4. The per-user API key

### Format and minting
- Key format: `qlk_` followed by 48 hex chars (e.g. `qlk_9f2a...`), 192 bits.
- Minted server-side by the **`mint-quick-log-key` Edge Function**, which is the
  Pro gate: it verifies the caller's Supabase JWT, then confirms an active Cashie
  Pro subscription via Apple's **App Store Server API** (native StoreKit 2;
  RevenueCat removed - see `GO_LIVE_RUNBOOK.md` section 6c), then mints via the
  service-role-only `issue_quick_log_key_for(uid)`
  RPC. That RPC stores **only** a SHA-256 hash of the key plus a short display
  prefix and a label; the raw key is returned exactly once and never stored in
  plaintext. The legacy `issue_quick_log_key()` and `quick_log()` RPCs are now
  locked down (callable by no external role) so minting/inserting can't bypass
  the Edge Functions.
- The app fetches the minted key (Pro users only) and keeps the raw key in the
  **iOS Keychain**, showing it (with copy) on the setup screen.

### What the key can and cannot do
- It maps to exactly one user and authorizes exactly one action: **insert one
  transaction** via the `quick_log` endpoint.
- It cannot read, list, update, or delete anything. It returns only
  `{ ok, id }`. Even the owner's own data is never returned.
- It can be revoked (sets `revoked = true`); after that the endpoint returns
  `unauthorized`. Revoking and re-minting is the "reset shortcut access" flow.
- A leaked key only lets someone insert junk spends into that one account
  (annoying, fully recoverable by revoking + deleting the rows in the app). It
  exposes no data and cannot touch other users.

### Current status (this build)
- The setup UI fetches a real, **server-minted** `qlk_...` key (Pro-gated) and
  caches it in the Keychain. With no Supabase backend configured (dev/previews)
  it falls back to a local inert key so the card still renders.
- Both Edge Functions are deployed: `mint-quick-log-key` (Pro-verified mint) and
  `quick-log` (rate-limited insert). The "Import Shortcut" button is still a
  **placeholder** (no iCloud link yet); publishing the shortcut is the remaining
  step.

---

## 5. The endpoint (POST only, insert only)

### Production endpoint: the `quick-log` Edge Function (deployed)
A thin `x-api-key` front door that rate-limits and forwards to the insert-only
primitive. The Shortcut calls this; it never touches the database directly.

```
POST https://fsmdklrrcnnwyzenuaed.functions.supabase.co/quick-log

Headers:
  x-api-key: qlk_<the user's key>
  Content-Type: application/json

Body:
  {
    "amount": 40,
    "merchant": "Beer",
    "category": "food",
    "note": ""
  }

Response:
  { "ok": true, "id": "..." }
  { "ok": false, "error": "unauthorized" }   (unknown / revoked key, 401)
  { "ok": false, "error": "rate_limited" }    (429)
  { "ok": false, "error": "invalid_amount" }  (400)
```

The Edge Function (`verify_jwt = false`; auth is the custom `x-api-key`):
1. Reads `x-api-key` and the caller IP (`x-forwarded-for`).
2. Calls the service-role-only `quick_log_guarded(key, ip, amount, …)` RPC, which
   enforces a **per-IP** flood guard (60/min) then validates the key against the
   SHA-256 hash in `quick_log_keys`, then **per-key** limits (10/min, 200/day),
   then inserts ONE `quicklog` row for the key's owner and bumps `last_used_at`.
3. Relays `{ ok, id }` / the error with an appropriate status.

It does nothing else - no select, no update, no delete - and never returns user
data. Rate-limit counters live in the locked `quick_log_rate` table (RLS on, no
policies; only the SECURITY DEFINER functions touch it).

### Why this is safe
- **Insert only.** `quick_log_guarded` exposes no read/update/delete. Deletion
  happens only inside the app (authenticated, RLS).
- **Pro-gated minting.** A key only exists if `mint-quick-log-key` verified an
  active `pro` entitlement, so outsiders/non-payers can't obtain one.
- **Key-gated + hashed.** The server stores only a SHA-256 hash; the raw key
  lives on the user's device.
- **No open RPC surface.** `quick_log()` and `issue_quick_log_key()` are no
  longer callable by `anon`/`authenticated`; the only ways in are the two Edge
  Functions, which run as service-role. Rate limiting bounds a leaked key and
  blunts endpoint floods.
- **Minimal shortcut secret.** The Shortcut carries only the user's `x-api-key`.

---

## 6. The "Cashie Quick Log" shortcut - tap triggers (build this, then share)

This shortcut, named **Cashie Quick Log**, serves the **tap** triggers: Back Tap
and the Action Button. (The Apple Pay automation uses a separate shortcut - see
section 7.) Build it once in the Shortcuts app, then Share -> Copy iCloud Link to
get the `https://www.icloud.com/shortcuts/...` link, and put that link in
`Config.quickLogShortcutImportURL` - it's what the tap-trigger "Import Shortcut"
button opens. On import, the shortcut prompts the user for the **x-api-key** value
(which is what the in-app screen tells them to paste). The in-app copy refers to
this shortcut by the exact name "Cashie Quick Log" so the setup steps match.

Note on naming: this imported shortcut (Cashie Quick Log) is separate from the
app's built-in App Intents, which appear in Shortcuts/Siri automatically as
"Log Expense" and "Open Quick Log". The guided setup uses the imported "Cashie
Quick Log" because that is the one carrying the API key.

Actions, top to bottom:

1. **Ask for Number** - Prompt: "Amount". Allow Decimal: yes. Allow Negative: no.
   -> Set variable `amount`.
2. **Ask for Text** - Prompt: "Name (optional)". -> Set variable `merchant`.
3. **List** (6-9 items): Food, Transport, Shopping, Fun, Home, Health,
   Bills, Other. Then **Choose from List** - Prompt: "Category". -> Set variable
   `category`.
4. **Get Contents of URL**
   - URL: `https://fsmdklrrcnnwyzenuaed.functions.supabase.co/quick-log`
   - Method: `POST`
   - Headers: `x-api-key` = (the import question value), `Content-Type` =
     `application/json`
   - Request Body: JSON
     - `amount` (Number) = `amount`
     - `merchant` (Text) = `merchant`
     - `category` (Text) = `category`
     - `note` (Text) = (empty / optional)
5. **Show Notification** - "Logged [amount] to [category] in Cashie".

Notes:
- The import question that captures `x-api-key` is what makes it auto-fill on
  every later run, with no app open.
- No `flowType` / `expenseType` - Cashie does not use them. Income is just the
  `income` category if you add it to the list.

---

## 7. The "Cashie Apple Pay Log" shortcut - Wallet automation (separate shortcut)

Apple Pay is a different workflow, so it gets its **own** shortcut, **Cashie Apple
Pay Log**, with its own iCloud import link in `Config.applePayShortcutImportURL`
(the Apple Pay setup screen's "Import Shortcut" button opens this one, not the tap
shortcut). iOS Shortcuts has a Wallet automation trigger that fires when you pay
with a chosen Apple Pay card (this is what TapSheet uses, see
`cashie_automation_shortcuts.rtfd`).

Build it the same way as section 6 (the POST body is identical) but publish it
under the name **Cashie Apple Pay Log**, so the user imports the right one for
this trigger and can tune it independently (e.g. a default category). Two honest
caveats: Apple Pay does NOT pass the merchant/amount to the shortcut, so it still
asks the user to confirm the amount; and the first run must be "Run After
Confirmation" (a shortcut can't run while the phone is locked without it). After
the first payment the user can switch it to run immediately for hands-off logging.

Setup (mirrors the rtfd):

1. Shortcuts app -> **Automation** tab.
2. Tap **+** -> **Create Personal Automation**.
3. Select **Wallet**, choose the card, then on the next screen pick **Cashie
   Apple Pay Log** to run.
4. Set **Run After Confirmation** for the first payment.
5. After the first payment, switch it to **Run Immediately** to fully automate.

---

## 8. In-app setup flow (what the user sees)

On the Quick Log setup screen (YOU tab -> "Set up Quick Log", mirrored in
onboarding):

1. **Your API key** - shown masked with a Reveal toggle and a **Copy** button.
   Tapping Copy puts the raw `qlk_...` key on the clipboard.
2. **Import Shortcut** - opens the iCloud link for the shortcut that matches the
   chosen trigger: **Cashie Quick Log** for Back Tap / Action Button, or **Cashie
   Apple Pay Log** for Apple Pay (placeholders until the links are published).
3. Steps shown next to the buttons:
   - "Copy your API key."
   - "Tap Import Shortcut, then Add Shortcut in the Shortcuts app."
   - "Paste your key into the x-api-key prompt."
   - The final step is trigger-specific (assign to Back Tap, the Action Button, or
     the Wallet automation).

Then the trigger setup (a chooser in the app):
- **Back Tap:** Settings -> Accessibility -> Touch -> Back Tap -> Triple Tap ->
  Cashie Quick Log.
- **Action Button:** Settings -> Action Button -> Shortcut -> Cashie Quick Log.
- **Apple Pay:** Shortcuts -> Automation -> + -> Create Personal Automation ->
  Wallet -> run Cashie Apple Pay Log (Run After Confirmation first, then Run
  Immediately). See section 7.

---

## 9. Security summary + what is built vs. later

**Built now (this build)**
- Native App Intents + `cashie://` deep links (no key, no login, offline): log via
  Back Tap / Action Button / Siri by opening or silently logging into the app.
- Quick Log setup UI with a real, copyable per-user `qlk_...` API key (Keychain).
- "Import Shortcut" placeholder button.
- Backend insert-only `quick_log` + `issue_quick_log_key` RPCs (deployed, tested).

**Phase 2 (activates the headless POST path)**
- Silent Supabase anonymous auth (no login) so the app can call
  `issue_quick_log_key` and mint the real server-side key.
- The Edge Function (`x-api-key`, rate limit + HMAC, insert only).
- The shared iCloud "Cashie Quick Log" shortcut; wire the real link into the
  "Import Shortcut" button.
- Key revoke / rotate UI.

**Security guarantees (do not regress)**
- The shortcut key is POST/insert ONLY. No read, update, or delete via any
  key-gated endpoint. Deletion is app-only.
- The server stores only a SHA-256 hash of the key. Raw key lives on-device.
- The Supabase URL and anon key are public by design; safety comes from RLS plus
  the per-user insert-only key, not from hiding the URL.
- Keys are revocable; a leaked key can only insert into its own account and
  exposes no data.
