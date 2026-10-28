// jacket-ingest: the (virtual) jacket posts telemetry + fault flags every few seconds.
// Updates jacket_status, opens/closes jacket-reported faults, applies a mode change made on the jacket itself,
// and answers with the wearer's comfort settings so app changes reach the jacket on the next send.
import { COMFORT_MODES, comfortConfig, corsHeaders, deviceKeyValid, json, serviceClient } from "../_shared/device.ts";

const FAULT_CODES = [
  "body_sensor_offline", "heater_over_limit", "blower_current_spike",
  "buffer_not_charging", "battery_hot", "cuff_tag_unreadable",
];

const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : null);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON" }, 400);
  }
  const jacketId = String(body.jacket_id ?? "");
  const db = serviceClient();
  if (!(await deviceKeyValid(db, jacketId, "jacket", req.headers.get("x-device-key")))) {
    return json({ error: "unknown jacket or wrong device key" }, 401);
  }

  const mode = String(body.mode ?? "").toLowerCase();
  const flags = Array.isArray(body.fault_flags)
    ? [...new Set(body.fault_flags.map(String).filter((f) => FAULT_CODES.includes(f)))]
    : [];

  const { error: statusError } = await db.from("jacket_status").upsert({
    jacket_id: jacketId,
    ts: typeof body.ts === "string" ? body.ts : null,
    is_virtual: body.is_virtual !== false,
    body_c: num(body.body_c),
    ambient_c: num(body.ambient_c),
    mode: COMFORT_MODES.includes(mode) ? mode : "auto",
    heater_on: body.heater_on === true,
    blower_on: body.blower_on === true,
    blower_ma: num(body.blower_ma),
    buffer_v: num(body.buffer_v),
    buffer_pct: num(body.buffer_pct),
    harvested_mj: num(body.harvested_mj),
    battery_pct: num(body.battery_pct),
    battery_temp_c: num(body.battery_temp_c),
    cuff_tag_ok: body.cuff_tag_ok !== false,
    activity: typeof body.activity === "string" ? body.activity : null,
    fault_flags: flags,
    updated_at: new Date().toISOString(),
  });
  if (statusError) return json({ error: statusError.message }, 500);

  // Jacket-reported faults follow the flags: new flag -> open fault, flag gone -> fixed.
  const { data: active } = await db
    .from("faults")
    .select("id, code")
    .eq("jacket_id", jacketId)
    .eq("source", "jacket")
    .neq("status", "fixed");
  const activeCodes = new Set((active ?? []).map((f) => f.code));
  const toOpen = flags.filter((f) => !activeCodes.has(f));
  const toFix = (active ?? []).filter((f) => !flags.includes(f.code)).map((f) => f.id);
  if (toOpen.length) {
    await db.from("faults").insert(toOpen.map((code) => ({ jacket_id: jacketId, code, source: "jacket" })));
  }
  if (toFix.length) {
    await db.from("faults").update({ status: "fixed", resolved_at: new Date().toISOString() }).in("id", toFix);
  }

  // Mode button on the jacket (or the Unity dashboard) wins over the app until the app changes it again.
  const override = String(body.mode_override ?? "").toLowerCase();
  if (COMFORT_MODES.includes(override)) {
    await db.from("comfort_settings").update({ mode: override, updated_by: "jacket" }).eq("jacket_id", jacketId);
  }

  return json(await comfortConfig(db, jacketId) ?? {});
});
