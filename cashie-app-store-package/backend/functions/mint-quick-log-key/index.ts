import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5.9.6";

// Mints a Quick Log API key, but ONLY for a caller with an active Cashie Pro
// subscription, verified server-side against Apple's App Store Server API
// (native StoreKit 2 — there is no third-party billing service). An
// Apple-signed subscription status can't be forged, so this is the real gate:
// only paying customers get a key.
//
// Flow: verify the caller's Supabase JWT -> read uid -> look the subscription
// up with Apple using the originalTransactionId the client sends -> if it is
// active on a cashie_pro_* product, mint via the service-role-only
// issue_quick_log_key_for(uid) RPC (stores only a SHA-256 hash, returns the raw
// key once). Minting is service-role-only and takes an explicit uid so it can't
// be called directly by a signed-in user to bypass the entitlement check.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// App Store Connect API key, created in App Store Connect under Users and
// Access -> Integrations -> In-App Purchase (or a Team key with access). Set
// these three as edge-function secrets (the private key is the full .p8 PEM,
// including the BEGIN/END lines and newlines).
const ASC_ISSUER_ID = Deno.env.get("APPSTORE_ISSUER_ID") ?? "";
const ASC_KEY_ID = Deno.env.get("APPSTORE_KEY_ID") ?? "";
const ASC_PRIVATE_KEY = Deno.env.get("APPSTORE_PRIVATE_KEY") ?? "";
const BUNDLE_ID = Deno.env.get("APP_BUNDLE_ID") ?? "com.cashie.app";

const PRO_PRODUCT_IDS = new Set([
  "cashie_pro_monthly",
  "cashie_pro_yearly",
]);

// App Store Server API hosts. Try production first, then sandbox — App Review
// purchases are in the sandbox environment, per Apple's guidance.
const ASC_HOSTS = [
  "https://api.storekit.itunes.apple.com",
  "https://api.storekit-sandbox.itunes.apple.com",
];

const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// Decode a JWS payload (the middle segment) without verifying its signature.
// Safe here: the JWS comes straight from Apple's App Store Server API over an
// authenticated TLS connection, so the transport is the trust anchor.
function decodeJwsPayload(jws: string): any {
  const part = (jws ?? "").split(".")[1] ?? "";
  const b64 = part.replace(/-/g, "+").replace(/_/g, "/")
    .padEnd(Math.ceil(part.length / 4) * 4, "=");
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return JSON.parse(new TextDecoder().decode(bytes));
}

// The short-lived ES256 JWT the App Store Server API requires for auth.
async function appStoreBearer(): Promise<string> {
  const key = await importPKCS8(ASC_PRIVATE_KEY, "ES256");
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT({ bid: BUNDLE_ID })
    .setProtectedHeader({ alg: "ES256", kid: ASC_KEY_ID, typ: "JWT" })
    .setIssuer(ASC_ISSUER_ID)
    .setIssuedAt(now)
    .setExpirationTime(now + 600)
    .setAudience("appstoreconnect-v1")
    .sign(key);
}

// True if the originalTransactionId has an active (or in-grace) subscription on
// a cashie_pro_* product, as reported by Apple.
async function hasActivePro(originalTransactionId: string): Promise<boolean> {
  const bearer = await appStoreBearer();
  for (const host of ASC_HOSTS) {
    const resp = await fetch(
      `${host}/inApps/v1/subscriptions/${encodeURIComponent(originalTransactionId)}`,
      { headers: { Authorization: `Bearer ${bearer}` } },
    );
    if (resp.status === 404) continue; // not in this environment; try the other
    if (!resp.ok) continue;
    const body = await resp.json();
    for (const group of body?.data ?? []) {
      for (const last of group?.lastTransactions ?? []) {
        // status 1 = active, 4 = in billing grace period -> still entitled.
        if (last?.status !== 1 && last?.status !== 4) continue;
        try {
          const info = decodeJwsPayload(last.signedTransactionInfo);
          if (PRO_PRODUCT_IDS.has(info?.productId)) return true;
        } catch (_) {
          // keep scanning the remaining transactions
        }
      }
    }
  }
  return false;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }

  // User-bound client only to verify the JWT and read the uid.
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  const uid = userData.user.id;

  // Body: { original_transaction_id, label?, reset? }. `reset` revokes existing
  // keys first.
  let label = "Quick Log";
  let reset = false;
  let originalTransactionId = "";
  try {
    const body = await req.json();
    if (typeof body?.label === "string" && body.label.trim()) {
      label = body.label.trim().slice(0, 60);
    }
    if (body?.reset === true) reset = true;
    if (typeof body?.original_transaction_id === "string") {
      originalTransactionId = body.original_transaction_id.trim();
    }
  } catch (_) {
    // empty body is fine
  }

  if (!ASC_ISSUER_ID || !ASC_KEY_ID || !ASC_PRIVATE_KEY) {
    return json({ ok: false, error: "server_misconfigured" }, 500);
  }
  if (!originalTransactionId) {
    return json({ ok: false, error: "not_pro" }, 403);
  }

  // Verify the Pro subscription with Apple.
  let active = false;
  try {
    active = await hasActivePro(originalTransactionId);
  } catch (_) {
    return json({ ok: false, error: "entitlement_check_failed" }, 502);
  }
  if (!active) return json({ ok: false, error: "not_pro" }, 403);

  // Service-role client for the privileged mint (and optional revoke). The uid
  // is supplied explicitly from the verified JWT above.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

  if (reset) {
    await admin.from("quick_log_keys").update({ revoked: true }).eq("user_id", uid);
  }

  const { data: rawKey, error: rpcErr } = await admin.rpc("issue_quick_log_key_for", {
    p_uid: uid,
    p_label: label,
  });
  if (rpcErr || typeof rawKey !== "string") {
    return json({ ok: false, error: "mint_failed" }, 500);
  }

  return json({ ok: true, key: rawKey });
});
