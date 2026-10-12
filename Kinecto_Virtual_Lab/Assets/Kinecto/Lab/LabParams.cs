// Kinecto Virtual Lab: loads sim_params.json (same file the Python model uses).
// Put sim_params.json in Assets/StreamingAssets/.
using System;
using System.IO;
using UnityEngine;

[Serializable] public class PvdfParams { public float youngs_modulus_pa, d31_c_per_n, relative_permittivity, thickness_m, electrode_area_m2, strain_per_degree, harvest_efficiency; }
[Serializable] public class TengParams { public bool enabled; public float surface_charge_c_per_m2, contact_area_m2, max_gap_m, harvest_efficiency; }
[Serializable] public class BufferParams { public float capacitance_f, leakage_w, load_on_voltage_v, load_off_voltage_v, load_power_w; }
[Serializable] public class ThermalParams {
    public float skin_temp_c, jacket_insulation_mix, time_constant_s, warm_below_c, cool_above_c, hysteresis_c;
    public float heater_w, heater_effect_c, blower_w, blower_effect_c, mcu_sensors_w, battery_wh, boost_efficiency;
}
[Serializable] public class AttendanceParams { public float read_range_m, dwell_s, debounce_s; public string mock_student_id; }
[Serializable] public class LabParamsData { public PvdfParams pvdf; public TengParams teng; public BufferParams buffer; public ThermalParams thermal; public AttendanceParams attendance; }

public static class LabParams
{
    static LabParamsData _data;
    public static LabParamsData Data
    {
        get
        {
            if (_data == null)
            {
                string path = Path.Combine(Application.streamingAssetsPath, "sim_params.json");
                _data = JsonUtility.FromJson<LabParamsData>(File.ReadAllText(path));
            }
            return _data;
        }
    }
}
