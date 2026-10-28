// Shared helpers for the device-facing Edge Functions (Unity virtual jacket and door readers).
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-device-key, x-reader-key, authorization, apikey",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Service-role client: devices never get database keys, only their own device key. */
export function serviceClient(): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** True when `key` matches the stored sha256 hash for this device id and kind. */
export async function deviceKeyValid(
  db: SupabaseClient,
  id: string | null | undefined,
  kind: "jacket" | "reader",
  key: string | null,
): Promise<boolean> {
  if (!id || !key) return false;
  const { data } = await db.from("devices").select("key_hash").eq("id", id).eq("kind", kind).maybeSingle();
  return !!data && data.key_hash === (await sha256Hex(key));
}

export const COMFORT_MODES = ["auto", "cool", "warm", "off"];

/** What the jacket needs from the wearer's comfort settings. */
export async function comfortConfig(db: SupabaseClient, jacketId: string) {
  const { data } = await db
    .from("comfort_settings")
    .select("warm_below_c, cool_above_c, mode, updated_at")
    .eq("jacket_id", jacketId)
    .maybeSingle();
  return data;
}
