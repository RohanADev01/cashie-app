# Backend sync, security and loading indicator

Implementation + test report. Covers the Supabase schema sync, RLS lockdown,
realtime, the offline-first sync engine with optimistic UI and local backup, and
the in-app loading indicator.

Supabase project: `fsmdklrrcnnwyzenuaed` (name "Cashie (us-east-1)"), Postgres 17.

> **Update (2026-06-13):** the backend was **recreated in `us-east-1`** (lower
> global latency) as an exact copy of the original `ap-southeast-2` / Sydney
> project, which is now retired. The full schema (all 13 migrations incl. a
> `bootstrap_rls_auto_enable` step and a `match_source_revoke_definer_rpc_from_api_roles`
> parity fix), both Edge Functions, and grants/advisors were verified identical to
> the source. The `mint-quick-log-key` function no longer uses RevenueCat; it
> verifies Pro via Apple's **App Store Server API** (see `GO_LIVE_RUNBOOK.md` §6c).
> Manual steps still pending on the new project: enable **Anonymous sign-ins**, and
> set the App Store Connect API key edge secrets (for Quick Log minting only).

---

## 1. Supabase schema synced to the current app

The project already had 8 tables. Compared against the live Swift models, two
gaps were closed (migrations applied via MCP):

| Migration | Change | Why |
|---|---|---|
| `sync_schema_archived_at_and_rank_badge_state` | `goals.archived_at timestamptz` | `Goal.archivedAt` powers Past Wins / archive. Could not round-trip without it. |
| (same) | `app_settings.last_seen_rank`, `celebrated_badge_ids text[]`, `badge_baseline_seeded bool` | The ranks + badges systems are new. Ranks/badges themselves are *derived* from live data, so only the "already celebrated" bookkeeping in `AppSettings` needs to persist. |

Model to table mapping (all per-user, keyed by `user_id` to `auth.users`):

| App model | Table | Notes |
|---|---|---|
| `CashieUser` | `profiles` | `traits` stored as jsonb, `archetype_id` text |
| `AppSettings` | `app_settings` | now includes rank/badge celebration state |
| `Transaction` | `transactions` | `date` to `occurred_at`, `category`/`source` are DB enums |
| `CategoryBudget` | `category_budgets` | composite PK `(user_id, category)` |
| `Goal` | `goals` | `targetDate` to `date`, `archivedAt` to `archived_at` |
| `Deposit` | `deposits` | child of goals, `date` to `occurred_at` |
| `AppNotification` | `notifications` | `kind` is a DB enum |

---

## 2. Security: no external party can read or write app data

Verified empirically through the Supabase MCP.

- RLS is **enabled on every table** (8/8).
- Every per-user table has own-rows-only policies: `auth.uid() = user_id`
  (`profiles` uses `auth.uid() = user_id`). No policy uses a permissive `true`.
- Table grants (the decisive layer):
  - `anon` (not signed in): **no SELECT/INSERT/UPDATE/DELETE** on any user
    table. Proven: `select ... from public.transactions` as `anon` returns
    `permission denied for table transactions`.
  - `authenticated` (signed in): full CRUD, but every row is still constrained
    to the caller by RLS, so a signed-in user can only ever touch their own data.
  - Migration `grant_dml_to_authenticated_only` set this up (the tables
    previously had no DML granted to either role, which would have blocked the
    app entirely once live).
- `contact_messages` (marketing form) allows `anon` INSERT only, with strict
  length/value checks, and has **no SELECT policy**, so nobody external can read
  submissions.
- Hardened `public.rls_auto_enable()` (a SECURITY DEFINER event-trigger helper):
  revoked EXECUTE from `anon`/`authenticated`/`public`, closing the RPC attack
  surface the security advisor flagged. Same for the other trigger helpers.
- `service_role` key is never referenced anywhere in the app.
- Security advisors after changes: clean except one low-severity note,
  `citext` extension installed in `public`. Left in place on purpose: moving it
  would risk breaking the existing `contact_messages.email` column type. It does
  not expose any data. Recommended as a later cleanup.

---

## 3. Realtime database sync

- `supabase_realtime` publication previously contained **no tables**. Added all
  7 per-user tables (`enable_realtime_on_user_tables`).
- Set `REPLICA IDENTITY FULL` on all 7 so RLS can authorize UPDATE/DELETE
  realtime events (the default identity only ships the primary key, which the
  `user_id` policy cannot match).
- Client: `RealtimeConnection` (Phoenix protocol over
  `URLSessionWebSocketTask`) inside `LiveSupabaseService`. It connects, joins the
  public schema channel, heartbeats, and triggers a pull on any change. It is
  fully defensive (every failure reconnects with backoff; nothing can crash the
  app) and **dormant until an auth token is available**.

---

## 4. App architecture: offline-first, optimistic, local backup, loading

All new code lives in existing files (no Xcode project changes), so the build
graph is unchanged.

### SyncEngine (`Services/SupabaseService.swift`)
An `actor` that is the single `SupabaseService` the app talks to:

- **Reads** come straight from the durable on-device store (instant, offline).
- **Writes** hit the on-device store **first** (data is never lost), then push
  to Supabase in the background.
- **Optimistic UI**: the container already mutates published state immediately;
  the engine persists locally and syncs behind it.
- **Local backup**: the file-backed store (`LocalStore`, JSON in Application
  Support) is always written. This is the "store to local in case the database
  fails" path. The app stays fully usable with no network.
- **Retry outbox**: pending remote ops are persisted to disk, deduped, and
  flushed on launch / foreground / after each success, so writes eventually
  reach the server. The outbox is only used when a remote is configured.
- **Auto stay in sync**: pulls all collections on launch and foreground, merges
  into local, and refreshes the UI; realtime triggers the same merge.
- **Never stuck**: every remote op has a 12s timeout and the in-flight counter
  is always decremented (even on failure/timeout).

### Loading indicator (`App/RootView.swift`)
`SyncStatusBar` + `SyncIndicator`: a small pill at the top that shows a spinner
and "Saving" while an action is in flight, flashes a green "Saved" check when it
settles, then fades out. It is driven purely by the in-flight count and has a
14s watchdog auto-hide, so it can never get stuck on screen.

### LiveSupabaseService (`Services/SupabaseService.swift`)
A dependency-free Supabase client over `URLSession` (PostgREST) plus the realtime
client. No SPM package was added. It maps every model to/from the snake_case DB
row shape. It stays **dormant** until BOTH a Supabase anon key is set in
`Config` AND an access-token provider (a signed-in Supabase session) is supplied;
until then every call returns immediately and the app runs fully offline.

---

## 5. Testing and results

- **Build**: `BUILD SUCCEEDED` (Debug, iphonesimulator). All new code, including
  the dormant live client, compiles.
- **Runtime**: launched on iPhone 15 Pro simulator and ran a DEBUG-only self
  test (`-syncSelfTest`) that drives every write path through the real container
  methods: add/delete transaction, create goal, add deposit, remove deposit,
  change a budget, toggle a setting, delete goal.
  - No crash anywhere: the process stayed alive through the full sequence.
  - Loading indicator showed "Saving" then a green "Saved", and **cleared**
    (final frame has no pill, confirming it does not get stuck).
  - Optimistic UI updated live (Safe-to-Spend changed instantly as state moved).
  - Durable persistence verified on disk: `budgets.json` bills cap = 99,
    `settings.json` `dailyReminderEnabled` = true and the new rank/badge fields
    present, `goals.json` cleaned up (no leftover from the create/delete round
    trip).
- **Database**: schema, RLS, grants, realtime publication and replica identity
  all verified via MCP queries.

The one thing that cannot be exercised end-to-end in this environment is a real
signed-in Supabase round trip (it needs Sign in with Apple to Supabase auth and
network egress). The schema/RLS/grants are proven server-side, and the offline
path is proven on device.

---

## 6. To go fully live

1. Paste the anon (publishable) key into `Config.supabaseAnonKey` in a local,
   gitignored build. The URL is already set.
2. Wire Sign in with Apple to Supabase auth and pass the session access token via
   `LiveSupabaseService.makeIfConfigured(tokenProvider:)`. The `handle_new_user`
   trigger seeds the `profiles` + `app_settings` rows on first sign-in.
3. That is all: the `SyncEngine` then activates background sync + realtime
   automatically. No app logic changes required.
4. Optional later: move the `citext` extension out of `public`; add the
   Edge Functions described in `Cashie/Services/Integration.md`.

## Notes
- `-syncSelfTest` is `#if DEBUG` only dev scaffolding (it never ships in
  release). Remove it if you do not want it.
