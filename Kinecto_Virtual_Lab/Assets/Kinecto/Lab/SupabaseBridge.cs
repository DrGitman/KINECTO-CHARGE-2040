// Kinecto Virtual Lab: "virtual jacket" link to the real Kinecto Care backend (Supabase).
// Every few seconds it sends telemetry + fault flags to the jacket-ingest Edge Function, and it pulls the
// wearer's comfort settings from jacket-config, so the real phone app sees this virtual jacket exactly like a
// real one: live health, real-time fault alerts, booking a fix, FabLab tickets.
//
// Connection details live in StreamingAssets/lab_connection.json (NOT committed; copy lab_connection.example.json).
using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Text;
using UnityEngine;
using UnityEngine.Networking;

[Serializable] public class LabConnection { public string functions_url; public string jacket_id; public string device_key; public float send_every_s = 5f; public bool enabled = true; public string reader_id = "E201-SIM"; public string reader_key; }
[Serializable] public class ComfortConfig { public float warm_below_c; public float cool_above_c; public string mode; }
[Serializable] class TapPayload { public string reader_id; public string tag_id; public string direction; public string ts; }
[Serializable] class TelemetryPayload
{
    public string jacket_id; public string ts; public bool is_virtual = true;
    public float body_c; public float ambient_c; public string mode; public bool heater_on; public bool blower_on;
    public float blower_ma; public float buffer_v; public float harvested_mj; public float battery_pct; public float battery_temp_c;
    public bool cuff_tag_ok; public string activity; public string[] fault_flags;
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

    void Start()
    {
        string path = Path.Combine(Application.streamingAssetsPath, "lab_connection.json");
        if (!File.Exists(path)) { lastStatus = "offline: no lab_connection.json"; return; }
        cfg = JsonUtility.FromJson<LabConnection>(File.ReadAllText(path));
        if (cfg.enabled) { StartCoroutine(SendLoop()); StartCoroutine(ConfigLoop()); }
    }

    IEnumerator SendLoop()
    {
        while (true)
        {
            var p = new TelemetryPayload
            {
                jacket_id = cfg.jacket_id, ts = DateTime.UtcNow.ToString("o"),
                body_c = thermal.sensorFault ? float.NaN : thermal.insideC, ambient_c = thermal.ambientC,
                mode = thermal.mode.ToString(), heater_on = thermal.heaterOn, blower_on = thermal.blowerOn,
                blower_ma = faults.blowerCurrentMa, buffer_v = harvest.BufferVoltage, harvested_mj = (float)(harvest.harvestedJ * 1e3),
                battery_pct = thermal.BatteryLeftPct, battery_temp_c = faults.batteryTempC, cuff_tag_ok = faults.cuffTagReadable,
                activity = lab.CurrentActivity, fault_flags = faults.ActiveFlags.ToArray()
            };
            string json = JsonUtility.ToJson(p).Replace("\"body_c\":NaN", "\"body_c\":null");
            using (var req = new UnityWebRequest(cfg.functions_url + "/jacket-ingest", "POST"))
            {
                req.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(json));
                req.downloadHandler = new DownloadHandlerBuffer();
                req.SetRequestHeader("Content-Type", "application/json");
                req.SetRequestHeader("x-device-key", cfg.device_key);
                yield return req.SendWebRequest();
                lastStatus = req.result == UnityWebRequest.Result.Success ? $"sent {++sent}" : $"send failed: {req.error}";
            }
            yield return new WaitForSeconds(cfg.send_every_s);
        }
    }

    // Comfort settings changed in the real app reach the virtual jacket (like the BLE comfort_settings write).
    IEnumerator ConfigLoop()
    {
        while (true)
        {
            using (var req = UnityWebRequest.Get($"{cfg.functions_url}/jacket-config?jacket_id={cfg.jacket_id}"))
            {
                req.SetRequestHeader("x-device-key", cfg.device_key);
                yield return req.SendWebRequest();
                if (req.result == UnityWebRequest.Result.Success)
                {
                    var c = JsonUtility.FromJson<ComfortConfig>(req.downloadHandler.text);
                    if (c != null && c.cool_above_c > 0) lab.ApplyComfortFromApp(c.warm_below_c, c.cool_above_c, c.mode);
                }
            }
            yield return new WaitForSeconds(10f);
        }
    }

    // Called by CuffTapReader: the Unity door reader posts the tap like a real PN532 station would.
    public void SendTap(string tagId, string direction)
    {
        if (cfg == null || !cfg.enabled || string.IsNullOrEmpty(cfg.reader_key)) return;
        StartCoroutine(PostTap(new TapPayload { reader_id = cfg.reader_id, tag_id = tagId, direction = direction, ts = DateTime.UtcNow.ToString("o") }));
    }

    IEnumerator PostTap(TapPayload tap)
    {
        using (var req = new UnityWebRequest(cfg.functions_url + "/attendance-ingest", "POST"))
        {
            req.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(JsonUtility.ToJson(tap)));
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            req.SetRequestHeader("x-reader-key", cfg.reader_key);
            yield return req.SendWebRequest();
            lastStatus = req.result == UnityWebRequest.Result.Success ? $"tap {tap.direction} sent" : $"tap: {req.downloadHandler.text}";
        }
    }
}
