// Kinecto Virtual Lab: SPECULATIVE 2040 Kinecto Amplifier - the jacket's kinetic energy, amplified and used.
// Story object for the futures part of the project: it cannot create energy, it stands for a far better harvesting
// core that captures a share of the body's movement power (amplifier_2040 in sim_params.json). Today's real jacket
// only lights the cuff. The amplified power goes, in order, to:
//   1. the device in the inner-pocket USB-C (phone / earbuds case / watch band), until it is full
//   2. the heater / fan battery (thermal battery) - so walking keeps the comfort system running
using UnityEngine;

public enum ChargeDevice { Phone, Earbuds, Watch, Nothing }

public class AmplifierCharge : MonoBehaviour
{
    public ChargeDevice device = ChargeDevice.Earbuds;
    public ThermalModel thermal;                      // surplus tops up the thermal battery
    public KinectoLabController lab;

    [Header("Battery sizes (Wh)")]
    public float earbudsCaseWh = 1.87f;     // ~500 mAh case
    public float watchWh = 1.1f;            // ~300 mAh band
    [Header("Start levels (%)")]
    public float phonePct = 35f, earbudsPct = 42f, watchPct = 60f;

    /// Amplified power right now (W) and where it goes.
    public float PowerW { get; private set; }
    public string Destination { get; private set; } = "";
    public double DeliveredWh { get; private set; }            // today, to devices + battery

    public void ChoosePhone() => device = ChargeDevice.Phone;
    public void ChooseEarbuds() => device = ChargeDevice.Earbuds;
    public void ChooseWatch() => device = ChargeDevice.Watch;
    public void ChooseNothing() => device = ChargeDevice.Nothing;

    AmplifierParams P => LabParamsExtra.Amplifier;

    float CapacityWh(ChargeDevice d) => d == ChargeDevice.Phone ? P.phone_battery_wh : d == ChargeDevice.Earbuds ? earbudsCaseWh : watchWh;

    public float percent
    {
        get => device == ChargeDevice.Phone ? phonePct : device == ChargeDevice.Earbuds ? earbudsPct : device == ChargeDevice.Watch ? watchPct : 0f;
        private set { if (device == ChargeDevice.Phone) phonePct = value; else if (device == ChargeDevice.Earbuds) earbudsPct = value; else if (device == ChargeDevice.Watch) watchPct = value; }
    }

    public string DeviceName => device.ToString();

    /// Body movement power for the current motion: follows the real speed in live mode (any movement counts).
    float BodyPowerW(string activity)
    {
        var bp = P.body_motion_power_w;
        if (lab && !lab.ScheduleRunning)
        {
            float v = lab.LiveSpeed;
            return v < 0.15f ? bp.standing : v <= 1.4f ? Mathf.Lerp(bp.standing, bp.walk, v / 1.4f) : Mathf.Lerp(bp.walk, bp.run, Mathf.InverseLerp(1.4f, 3.2f, v));
        }
        return bp.Get(activity);
    }

    float ChargePowerW(string activity) => BodyPowerW(activity) * P.capture_fraction * P.charge_efficiency;

    /// "about +1% every 48 s of walking" - computed from the same numbers.
    public string HintText
    {
        get
        {
            if (device == ChargeDevice.Nothing) return "Nothing plugged in · amplified energy tops up the heater battery";
            if (percent >= 100f) return $"{DeviceName} full · amplified energy now tops up the heater battery";
            float walkW = P.body_motion_power_w.walk * P.capture_fraction * P.charge_efficiency;
            float sPerPct = CapacityWh(device) * 0.01f * 3600f / Mathf.Max(walkW, 1e-6f);
            string every = sPerPct < 90f ? $"{sPerPct:0} s" : $"{sPerPct / 60f:0} min";
            return $"USB-C in the inner pocket · about +1% every {every} of walking";
        }
    }

    public void Tick(float simDt, string activity)
    {
        PowerW = ChargePowerW(activity);
        double wh = PowerW * simDt / 3600.0;
        DeliveredWh += wh;
        if (device != ChargeDevice.Nothing && percent < 100f)
        {
            Destination = DeviceName.ToLower();
            percent = Mathf.Min(100f, percent + (float)(wh / CapacityWh(device) * 100.0));
        }
        else if (thermal)
        {
            Destination = "heater battery";
            thermal.batteryUsedWh = System.Math.Max(0.0, thermal.batteryUsedWh - wh);
        }
    }

    public void ResetDay() { DeliveredWh = 0; }
}
