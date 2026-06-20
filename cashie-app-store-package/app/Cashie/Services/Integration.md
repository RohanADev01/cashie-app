# Backend integration · Supabase + StoreKit

Subscriptions run on **native StoreKit 2** (`StoreKitService`) — there is no
third-party billing SDK to add or configure. Supabase boots with a mock
implementation; to wire up real sync you swap that one binding in
`AppContainer.init` and add the Supabase SDK as a Swift package.

---

## Supabase

### What we need from you

| Item | Where it goes | Notes |
|------|---------------|-------|
| Project URL (e.g. `https://xxxxx.supabase.co`) | `Config.swift` (gitignored) | Public, safe to ship in app |
| `anon` public key | `Config.swift` | Public, RLS protects data |
| `service_role` key | **Never** in the app | Server-side / Edge Functions only |
| Project ID (for the MCP tool) | Env var when running MCP | dev project, never prod |

### Code changes

1. Add the official SDK as a Swift Package dependency:
   `https://github.com/supabase-community/supabase-swift`, pin to an exact
   version, never `main`.
2. Create `Cashie/Services/LiveSupabaseService.swift` implementing the
   `SupabaseService` protocol that lives in this folder.
3. Create `Cashie/Config.swift` (add to `.gitignore`):
   ```swift
   enum Config {
       static let supabaseURL = URL(string: "https://YOUR_PROJECT.supabase.co")!
       static let supabaseAnonKey = "YOUR_ANON_KEY"
   }
   ```
4. In `AppContainer.init`, swap the Supabase binding (subscriptions already
   default to native StoreKit and need no change):
   ```swift
   init(supabase: SupabaseService = LiveSupabaseService(),
        subscriptions: SubscriptionService = StoreKitService()) { ... }
   ```

### Schema (Supabase)

Run as a migration. **Every table must have RLS enabled** + a policy keyed on
`auth.uid()`. No app code reads or writes the `service_role` key.

```sql
-- users (extends auth.users via auth.uid())
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  first_name text,
  archetype_id text,
  streak_days int default 0,
  total_saved numeric default 0,
  has_face_id bool default true,
  has_notifications bool default true,
  quick_log_setup bool default false,
  created_at timestamptz default now()
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  merchant text not null,
  amount numeric not null,
  category text not null,
  date timestamptz not null,
  note text,
  source text default 'manual',
  created_at timestamptz default now()
);
create index on public.transactions (user_id, date desc);

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  emoji text not null,
  name text not null,
  target_amount numeric not null,
  current_amount numeric default 0,
  target_date date not null,
  created_at timestamptz default now()
);
create index on public.goals (user_id);

create table public.deposits (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.goals on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  amount numeric not null,
  date timestamptz default now(),
  added_by text default 'You'
);
create index on public.deposits (goal_id, date desc);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  emoji text,
  title text not null,
  body text,
  kind text not null,
  is_unread bool default true,
  date timestamptz default now()
);
create index on public.notifications (user_id, date desc);
```

### RLS policies (run after creating tables)

```sql
alter table public.profiles      enable row level security;
alter table public.transactions  enable row level security;
alter table public.goals         enable row level security;
alter table public.deposits      enable row level security;
alter table public.notifications enable row level security;

-- Users only see their own rows
create policy "own profile"      on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "own transactions" on public.transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own goals"        on public.goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own deposits"     on public.deposits
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own notifications" on public.notifications
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

> **Never** disable RLS in code or via the MCP tool. If a query needs to bypass
> it, route through a server-side Edge Function with the `service_role` key
> kept on the server.

### Edge Functions worth building later

| Function | Purpose |
|---|---|
| `weekly-wrapped` | Cron job that builds the weekly summary + creates a notification |
| `archetype-recompute` | Periodically refreshes archetype based on recent spend |
| `goal-autopilot` | Skims small amounts toward goals after each payday |

---

## Subscriptions (native StoreKit 2)

Cashie ships with **no third-party purchase SDK**. `StoreKitService` talks to
StoreKit 2 directly: it loads `Product`s, presents Apple's purchase sheet, and
resolves the `pro` entitlement from `Transaction.currentEntitlements`. There is
nothing to install and no API key — purchases work as soon as the products
exist in App Store Connect.

### What we need from you

| Item | Where it goes |
|------|---------------|
| Auto-renewable subscription products | App Store Connect (human-only) |
| Product IDs (must match the app exactly) | already set in `StoreKitService.productIDs` + `Cashie.storekit` |

The two product IDs the app expects:

- `cashie_pro_monthly` — $9.99 / month
- `cashie_pro_yearly_v2` — $29.99 / year (the single yearly plan; shown as "SAVE 75% vs monthly")

### Code changes

None required — the binding already defaults to `StoreKitService()`. The only
thing that must line up is the **product IDs**:

1. Create the two auto-renewable subscriptions above in App Store Connect,
   all in one subscription group, **with no introductory offer** (Cashie has no
   free trial). Signing/distribution happens on your Mac, not in this VM.
2. Confirm the IDs match `StoreKitService.productIDs` and the bundled
   `Cashie/Resources/Cashie.storekit` (used for local testing on the scheme).

### Testing locally

The scheme references `Cashie.storekit`, so running from Xcode on the simulator
opens the real StoreKit purchase sheet (with Face ID / double-tap confirmation)
and grants a local entitlement — no sandbox account needed. For end-to-end
verification against the App Store, use a Sandbox Apple ID on a real device.

> There is no RevenueCat dashboard, entitlement mapping, or webhook to set up.
> The single launch dependency is "the product IDs exist in App Store Connect."

---

## Security guardrails (recap from `IOS_DEV_CLAUDE.md`)

- No secrets in source code or commits, `Config.swift` is gitignored
- `service_role` key never enters the app or any client
- All Supabase tables have RLS enabled before any data is written
- All API keys are sandbox/dev unless we're explicitly cutting prod
- App-side validation is defense-in-depth; the database is the source of truth
