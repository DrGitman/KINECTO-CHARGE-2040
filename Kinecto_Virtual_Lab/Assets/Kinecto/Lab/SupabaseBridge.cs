// Kinecto Virtual Lab: "virtual jacket" link to the real Kinecto Care backend (Supabase).
// Every few seconds it sends telemetry + fault flags to the jacket-ingest Edge Function. The reply carries the
// wearer's comfort settings, so a change in the phone app reaches the lab on the next send, and a mode change
// made here (mode key / dashboard) goes back to the app. The real phone app sees this virtual jacket exactly like
// a real one: live health, real-time fault alerts, comfort settings in sync.
//
// Connection details live in StreamingAssets/lab_connection.json (NOT committed; copy lab_connection.example.json).
using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Text;
using UnityEngine;
using UnityEngine.Networking;

[Serializable] public class LabConnection { public string functions_url; public string jacket_id; public string device_key; public float send_every_s = 2f; public bool enabled = true; public string reader_id = "E201-SIM"; public string reader_key; }
[Serializable] public class ComfortConfig { public float warm_below_c; public float cool_above_c; public string mode; public string updated_at; }
[Serializable] class TapPayload { public string reader_id; public string tag_id; public string direction; public string ts; }
[Serializable] class TapResult { public bool ok; public string message; }
[Serializable] class TelemetryPayload
{
    public string jacket_id; public string ts; public bool is_virtual = true;
    public float body_c; public float ambient_c; public string mode; public bool heater_on; public bool blower_on;
    public float blower_ma; public float buffer_v; public float buffer_pct; public float harvested_mj; public float battery_pct; public float battery_temp_c;
    public bool cuff_tag_ok; public string activity; public string[] fault_flags;
    public string mode_override;   // set when the mode was changed here, empty otherwise
}

public class SupabaseBridge : MonoBehaviour
{
    public HarvestModel harvest;
    public ThermalModel thermal;
    public FaultInjector faults;
    public KinectoLabController lab;

    [Header("Status (read-only)")]
    public string lastStatus = "not connected";
    public int sent;

    LabConnection cfg;
    string appliedStamp;                  // updated_at of the comfort settings last applied here
    ComfortMode? syncedMode;              // mode the app and the lab last agreed on; null until the first reply

    void Start()
    {
        string path = Path.Combine(Application.streamingAssetsPath, "lab_connection.json");
        if (!File.Exists(path)) { lastStatus = "offline: no lab_connection.json"; return; }
        cfg = JsonUtility.FromJson<LabConnection>(File.ReadAllText(path));
        if (cfg.enabled) StartCoroutine(SendLoop());
    }

    IEnumerator SendLoop()
    {
        while (true)
        {
            // The heater fault forces Warm; that is not the wearer's choice, so it is not sent to the app.
            bool modeChangedHere = syncedMode.HasValue && thermal.mode != syncedMode.Value && !faults.ActiveFlags.Contains("heater_over_limit");
            var p = new TelemetryPayload
            {
                jacket_id = cfg.jacket_id, ts = DateTime.UtcNow.ToString("o"),
                body_c = thermal.sensorFault ? float.NaN : thermal.insideC, ambient_c = thermal.ambientC,
                mode = thermal.mode.ToString(), heater_on = thermal.heaterOn, blower_on = thermal.blowerOn,
                blower_ma = faults.blowerCurrentMa, buffer_v = harvest.BufferVoltage,
                buffer_pct = Mathf.Clamp01(harvest.BufferVoltage / LabParams.Data.buffer.load_on_voltage_v) * 100f,
                harvested_mj = (float)(harvest.harvestedJ * 1e3),
                battery_pct = thermal.BatteryLeftPct, battery_temp_c = faults.batteryTempC, cuff_tag_ok = faults.cuffTagReadable,
                activity = lab.CurrentActivity, fault_flags = faults.ActiveFlags.ToArray(),
                mode_override = modeChangedHere ? thermal.mode.ToString() : ""
            };
            string json = JsonUtility.ToJson(p).Replace("\"body_c\":NaN", "\"body_c\":null");
            using (var req = new UnityWebRequest(cfg.functions_url + "/jacket-ingest", "POST"))
            {
                req.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(json));
                req.downloadHandler = new DownloadHandlerBuffer();
                req.SetRequestHeader("Content-Type", "application/json");
                req.SetRequestHeader("x-device-key", cfg.device_key);
                yield return req.SendWebRequest();
                if (req.result == UnityWebRequest.Result.Success)
                {
                    lastStatus = $"sent {++sent}";
                    ApplyConfig(req.downloadHandler.text);   // after a mode_override this echoes the new mode back
                }
                else lastStatus = $"send failed: {req.error}";
            }
            yield return new WaitForSeconds(cfg.send_every_s);
        }
    }

    // Comfort settings changed in the real app reach the virtual jacket (like the BLE comfort_settings write).
    void ApplyConfig(string body)
    {
        var c = JsonUtility.FromJson<ComfortConfig>(body);
        if (c == null || c.cool_above_c <= 0 || c.updated_at == appliedStamp) return;
        appliedStamp = c.updated_at;
        lab.ApplyComfortFromApp(c.warm_below_c, c.cool_above_c, c.mode);
        if (Enum.TryParse(c.mode, true, out ComfortMode m)) syncedMode = m;
    }

    // Called by CuffTapReader: the Unity door reader posts the tap like a real PN532 station would.
    // onResult gets the server's answer (recorded, or why it was rejected, e.g. session not open).
    public void SendTap(string tagId, string direction, Action<bool, string> onResult = null)
    {
        if (cfg == null || !cfg.enabled || string.IsNullOrEmpty(cfg.reader_key)) return;
        StartCoroutine(PostTap(new TapPayload { reader_id = cfg.reader_id, tag_id = tagId, direction = direction, ts = DateTime.UtcNow.ToString("o") }, onResult));
    }

    IEnumerator PostTap(TapPayload tap, Action<bool, string> onResult)
    {
        using (var req = new UnityWebRequest(cfg.functions_url + "/attendance-ingest", "POST"))
        {
            req.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(JsonUtility.ToJson(tap)));
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            req.SetRequestHeader("x-reader-key", cfg.reader_key);
            yield return req.SendWebRequest();
            TapResult r = null;
            try { r = JsonUtility.FromJson<TapResult>(req.downloadHandler.text); } catch (ArgumentException) { }
            string message = r?.message ?? req.error ?? "no answer";
            bool ok = req.result == UnityWebRequest.Result.Success && r != null && r.ok;
            lastStatus = ok ? $"tap {tap.direction} sent" : $"tap: {message}";
            onResult?.Invoke(ok, message);
        }
    }
}
