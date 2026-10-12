// Kinecto Virtual Lab: the NUST Kinecto Hub, where jackets are diagnosed and repaired.
// Diagnostic Bay scanner (E): reads the jacket's fault flags + health and shows the result.
// Repair & Maintenance bench (E): the technicians fix every active fault (robot arms work for a few seconds),
// the fault flags clear, the next telemetry to the phone app shows the jacket healthy again.
// The fault banner's "Fix" books a repair: the HUD then shows the way to the Hub.
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class HubStation : MonoBehaviour
{
    public enum Kind { Repair, Diagnostic }
    public Kind kind = Kind.Repair;
    public string label = "Repair & Maintenance";
    public KinectoLabController lab;
    public FaultInjector faults;
    public HarvestModel harvest;
    public ThermalModel thermal;
    public LabHud hud;
    public Transform player;
    public Transform[] arms;                  // robot arms that move while repairing
    public float reach = 2.4f, repairSeconds = 6f;

    public static bool RepairBooked;          // set by the HUD "Fix" button, cleared after the repair
    public static bool Busy { get; private set; }
    static readonly List<HubStation> all = new List<HubStation>();
    public static HubStation Nearest { get; private set; }

    Quaternion[] armRest;

    void OnEnable() => all.Add(this);
    void OnDisable() => all.Remove(this);
    void Start() { armRest = arms?.Select(a => a ? a.localRotation : Quaternion.identity).ToArray(); }

    static Vector3 Flat(Vector3 v) => new Vector3(v.x, 0f, v.z);

    void Update()
    {
        HubStation best = null; float bd = float.MaxValue;
        foreach (var s in all)
        {
            if (!s.player) continue;
            float d = Vector3.Distance(Flat(s.player.position), Flat(s.transform.position));
            if (d <= s.reach && d < bd) { bd = d; best = s; }
        }
        Nearest = best;
        if (best == this && !Busy && LabInput.TapPressed) StartCoroutine(kind == Kind.Repair ? Repair() : Diagnose());
    }

    public static string FaultName(string id) => id switch
    {
        "body_sensor_offline" => "Sensor stops", "heater_over_limit" => "Heater too hot", "blower_current_spike" => "Fan blocked",
        "buffer_not_charging" => "Not charging", "cuff_tag_unreadable" => "Cuff not reading", "battery_hot" => "Battery hot", _ => id
    };

    IEnumerator Diagnose()
    {
        Busy = true;
        if (hud) hud.ShowToast("Scanning your jacket · Diagnostic Bay", LabHud.Teal);
        yield return new WaitForSeconds(2f);
        var f = faults.ActiveFlags.ToList();
        if (f.Count == 0)
            hud?.ShowToast($"Diagnosis · all OK · buffer {harvest.BufferVoltage:0.0} V · battery {thermal.BatteryLeftPct:0}%", LabHud.Green);
        else
            hud?.ShowToast($"Diagnosis · {f.Count} fault{(f.Count > 1 ? "s" : "")}: {string.Join(", ", f.Select(FaultName))} · repair at the bench", LabHud.Red);
        Busy = false;
    }

    IEnumerator Repair()
    {
        if (faults.ActiveFlags.Count == 0)
        {
            hud?.ShowToast("Nothing to repair · your jacket is healthy", LabHud.Green);
            RepairBooked = false; yield break;
        }
        Busy = true;
        var list = string.Join(", ", faults.ActiveFlags.Select(FaultName));
        float t = 0f;
        while (t < repairSeconds)
        {
            t += Time.deltaTime;
            hud?.ShowToast($"Repairing · {list} · {Mathf.CeilToInt(repairSeconds - t)} s", LabHud.Gold);
            if (arms != null)
                for (int i = 0; i < arms.Length; i++)
                    if (arms[i]) arms[i].localRotation = armRest[i] * Quaternion.Euler(0f, Mathf.Sin((t + i) * 2.4f) * 55f, 0f);
            yield return null;
        }
        if (arms != null) for (int i = 0; i < arms.Length; i++) if (arms[i]) arms[i].localRotation = armRest[i];
        bool heater = faults.ActiveFlags.Contains("heater_over_limit");
        faults.ClearAll();
        if (heater && lab) lab.ModeAuto();
        RepairBooked = false; Busy = false;
        hud?.ShowToast($"Jacket repaired · Kinecto Hub · {(lab ? lab.ClockText : "")}", LabHud.Green);
    }
}
