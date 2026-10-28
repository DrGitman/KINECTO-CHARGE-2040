// jacket-config: the jacket reads the wearer's comfort settings (jacket-ingest also returns them on every send).
import { comfortConfig, corsHeaders, deviceKeyValid, json, serviceClient } from "../_shared/device.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const jacketId = new URL(req.url).searchParams.get("jacket_id");
  const db = serviceClient();
  if (!(await deviceKeyValid(db, jacketId, "jacket", req.headers.get("x-device-key")))) {
    return json({ error: "unknown jacket or wrong device key" }, 401);
  }
  const config = await comfortConfig(db, jacketId!);
  return config ? json(config) : json({ error: "no comfort settings for this jacket" }, 404);
});
