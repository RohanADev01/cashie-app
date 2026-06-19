import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// The Quick Log POST endpoint the Shortcut calls. Authenticated by the
// `x-api-key` header (a `qlk_` key), NOT a Supabase JWT — so verify_jwt is
// disabled and auth is custom. It forwards to the rate-limited
// `quick_log_guarded` RPC (per-IP + per-key limits, insert-only).

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-api-key, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);

  const key = req.headers.get("x-api-key") ?? "";
  if (!key) return json({ ok: false, error: "unauthorized" }, 401);

  // First hop in x-forwarded-for is the client IP (Supabase's edge sets it).
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim();

  let body: any = {};
  try { body = await req.json(); } catch (_) { body = {}; }

  const amount = Number(body?.amount);
  if (!isFinite(amount)) return json({ ok: false, error: "invalid_amount" }, 400);
  const merchant = typeof body?.merchant === "string" ? body.merchant : undefined;
  const category = typeof body?.category === "string" ? body.category : undefined;
  const note = typeof body?.note === "string" ? body.note : undefined;

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);
  const { data, error } = await supabase.rpc("quick_log_guarded", {
    p_key: key,
    p_ip: ip,
    p_amount: amount,
    p_merchant: merchant,
    p_category: category,
    p_note: note,
  });
  if (error) return json({ ok: false, error: "server_error" }, 500);

  const result = (data ?? { ok: false, error: "server_error" }) as {
    ok: boolean;
    error?: string;
    id?: string;
  };
  if (!result.ok) {
    const status = result.error === "rate_limited"
      ? 429
      : result.error === "unauthorized"
      ? 401
      : 400;
    return json(result, status);
  }
  return json(result, 200);
});
