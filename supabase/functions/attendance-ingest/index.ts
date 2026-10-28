// attendance-ingest: a door reader (Unity CuffTapReader or a real PN532 station) posts a cuff tap.
// The tap goes through record_tap, the same rules the Attendance website uses, and the website sees it live.
import { corsHeaders, deviceKeyValid, json, serviceClient } from "../_shared/device.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, message: "invalid JSON" }, 400);
  }
  const readerId = String(body.reader_id ?? "");
  const db = serviceClient();
  if (!(await deviceKeyValid(db, readerId, "reader", req.headers.get("x-reader-key")))) {
    return json({ ok: false, message: "unknown reader or wrong reader key" }, 401);
  }

  // Server time is the tap time, so a wrong device clock cannot move attendance.
  const { data, error } = await db.rpc("record_tap", {
    p_tag: String(body.tag_id ?? ""),
    p_direction: String(body.direction ?? ""),
    p_reader_id: readerId,
    p_session_id: body.session_id ? String(body.session_id) : null,
    p_source: "Unity reader",
  });
  if (error) return json({ ok: false, message: error.message }, 500);
  return json(data, data?.ok ? 200 : 422);
});
