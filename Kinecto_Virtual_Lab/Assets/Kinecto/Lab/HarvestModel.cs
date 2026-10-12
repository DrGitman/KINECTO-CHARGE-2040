// Kinecto Virtual Lab: energy module. Same equations as python/kinecto_sim.py.
// Attach once to the avatar. Zones (JointBendSensor / TengContactZone) call AddPvdfBend / AddTengContact.
using UnityEngine;

public class HarvestModel : MonoBehaviour
{
    const float EPS0 = 8.854e-12f;

    [Header("Live slider values (set by KinectoLabController)")]
    [Range(0.2f, 3f)] public float intensity = 1f;
    public bool pvdfOn = true, tengOn = true;

    [Header("Read-only results (SIMULATED)")]
    public double harvestedJ;      // total energy into the buffer
    public double bufferEnergyJ;   // energy stored right now
    public bool statusLightOn;
    public double lightSeconds;

    PvdfParams pv; TengParams tg; BufferParams bf;

    void Awake() { var d = LabParams.Data; pv = d.pvdf; tg = d.teng; bf = d.buffer; }

    public float BufferVoltage => Mathf.Sqrt((float)(2 * bufferEnergyJ / bf.capacitance_f));

    // One bend stroke of a PVDF patch (elbow). bendDegrees comes from the animated joint.
    public void AddPvdfBend(float bendDegrees)
    {
        if (!pvdfOn) return;
        float strain = pv.strain_per_degree * bendDegrees * Mathf.Min(intensity, 1.4f);
        float stress = pv.youngs_modulus_pa * strain;
        float charge = pv.d31_c_per_n * stress * pv.electrode_area_m2;           // Q = d31 * sigma * A
        float cap = EPS0 * pv.relative_permittivity * pv.electrode_area_m2 / pv.thickness_m;
        Add(0.5 * charge * charge / cap * pv.harvest_efficiency);               // E = Q^2 / 2C * eta
    }

    // One contact-separation cycle of a textile TENG patch (shoulder / torso).
    public void AddTengContact()
    {
        if (!tengOn) return;
        float gap = tg.max_gap_m * Mathf.Min(intensity, 1.5f);
        float vOc = tg.surface_charge_c_per_m2 * gap / EPS0;
        float qSc = tg.surface_charge_c_per_m2 * tg.contact_area_m2;
        Add(0.5 * vOc * qSc * tg.harvest_efficiency);
    }

    void Add(double joules) { harvestedJ += joules; bufferEnergyJ += joules; }

    // Called by the controller every simulated step (dt already scaled by time speed).
    public void Step(float dt)
    {
        bufferEnergyJ = System.Math.Max(0, bufferEnergyJ - bf.leakage_w * dt);
        if (statusLightOn)
        {
            bufferEnergyJ = System.Math.Max(0, bufferEnergyJ - bf.load_power_w * dt);
            lightSeconds += dt;
            if (BufferVoltage < bf.load_off_voltage_v) statusLightOn = false;
        }
        else if (BufferVoltage >= bf.load_on_voltage_v) statusLightOn = true;
    }

    public void ResetDay() { harvestedJ = bufferEnergyJ = lightSeconds = 0; statusLightOn = false; }
}
