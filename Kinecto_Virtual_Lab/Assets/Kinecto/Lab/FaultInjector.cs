// Kinecto Virtual Lab: fault injection. Dashboard buttons call these methods to break the virtual jacket on purpose.
// The faults change the simulated readings (so the Python fault engine can detect them) and also raise the
// jacket's own fault flags (like the real ESP32's fault_flags Bluetooth characteristic).
using System.Collections.Generic;
using UnityEngine;

public class FaultInjector : MonoBehaviour
{
    public HarvestModel harvest;
    public ThermalModel thermal;
    public CuffTapReader reader;

    [Header("Extra simulated readings sent with telemetry")]
    public float blowerCurrentMa;       // normal ~120 mA when on
    public float batteryTempC = 29f;
    public bool cuffTagReadable = true;
    public bool bufferCharging = true;

    readonly HashSet<string> active = new HashSet<string>();
    public IReadOnlyCollection<string> ActiveFlags => active;

    public void BodySensorOffline()   { thermal.sensorFault = true; active.Add("body_sensor_offline"); }
    public void HeaterOverLimit()     { thermal.mode = ComfortMode.Warm; thermal.forceOverheat = true; active.Add("heater_over_limit"); }
    public void BlowerCurrentSpike()  { active.Add("blower_current_spike"); }
    public void BufferNotCharging()   { harvest.pvdfOn = harvest.tengOn = false; bufferCharging = false; active.Add("buffer_not_charging"); }
    public void CuffTagUnreadable()   { cuffTagReadable = false; if (reader) reader.enabled = false; active.Add("cuff_tag_unreadable"); }
    public void BatteryHot()          { active.Add("battery_hot"); }

    public void ClearAll()
    {
        thermal.sensorFault = false; thermal.forceOverheat = false;
        harvest.pvdfOn = harvest.tengOn = true; bufferCharging = true;
        cuffTagReadable = true; if (reader) reader.enabled = true;
        active.Clear();
    }

    void Update()
    {
        // readings react to the faults, so the cloud fault engine sees realistic symptoms
        blowerCurrentMa = thermal.blowerOn ? (active.Contains("blower_current_spike") ? 950f : 120f) : 0f;
        float targetBatt = active.Contains("battery_hot") ? 52f : (thermal.heaterOn ? 33f : 29f);
        batteryTempC = Mathf.MoveTowards(batteryTempC, targetBatt, Time.deltaTime * 2f);
        if (active.Contains("heater_over_limit") && thermal.insideC > 40f) thermal.sensorFault = true; // firmware fail-safe trips
    }
}
