// Kinecto Virtual Lab: comfort module (body-side + ambient TMP117, Auto mode, heater / blower, thermal battery).
// Same model as python/kinecto_day.py. Comfort sensing only, not medical.
using UnityEngine;

public enum ComfortMode { Auto, Cool, Warm, Off }

public class ThermalModel : MonoBehaviour
{
    [Header("Live inputs")]
    public ComfortMode mode = ComfortMode.Auto;
    public float ambientC = 22f;            // set by the day clock, or by the "Outside temperature" slider
    public float warmBelowC = 19f, coolAboveC = 26f;   // the wearer's comfort range from the app
    public bool sensorFault;                // toggle in the dashboard to test fail-safe OFF
    public bool forceOverheat;              // fault injection: heater stuck on with a much stronger effect

    [Header("Read-only (SIMULATED)")]
    public float insideC;
    public bool heaterOn, blowerOn;
    public double batteryUsedWh;
    public float BatteryLeftPct => Mathf.Max(0f, 100f * (1f - (float)(batteryUsedWh / p.battery_wh)));

    ThermalParams p; bool autoHeat, autoCool;

    void Awake() { p = LabParams.Data.thermal; insideC = Target(0f); }

    float Target(float effect) => p.jacket_insulation_mix * p.skin_temp_c + (1f - p.jacket_insulation_mix) * ambientC + effect;

    public void Step(float dt)
    {
        if (sensorFault || mode == ComfortMode.Off) { heaterOn = blowerOn = false; }
        else if (mode == ComfortMode.Warm) { heaterOn = true; blowerOn = false; }
        else if (mode == ComfortMode.Cool) { heaterOn = false; blowerOn = true; }
        else
        {   // Auto with hysteresis
            if (!autoHeat && insideC < warmBelowC) autoHeat = true;
            if (autoHeat && insideC > warmBelowC + p.hysteresis_c) autoHeat = false;
            if (!autoCool && insideC > coolAboveC) autoCool = true;
            if (autoCool && insideC < coolAboveC - p.hysteresis_c) autoCool = false;
            heaterOn = autoHeat; blowerOn = autoCool && !autoHeat;
        }
        if (forceOverheat && !sensorFault) heaterOn = true;
        float effect = heaterOn ? (forceOverheat ? p.heater_effect_c * 4f : p.heater_effect_c) : blowerOn ? p.blower_effect_c : 0f;
        insideC += (Target(effect) - insideC) * dt / p.time_constant_s;
        float watts = p.mcu_sensors_w + (heaterOn ? p.heater_w : 0f) + (blowerOn ? p.blower_w : 0f);
        batteryUsedWh += watts / p.boost_efficiency * dt / 3600.0;
    }

    public void ResetDay() { batteryUsedWh = 0; insideC = Target(0f); autoHeat = autoCool = false; }
}
