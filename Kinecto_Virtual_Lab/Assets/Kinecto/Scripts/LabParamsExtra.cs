// Kinecto Virtual Lab: the parts of sim_params.json that LabParams.cs does not read (activities, zones, the
// SPECULATIVE 2040 amplifier, the average student day, the ambient temperature profile, the class sessions).
// Same file, same numbers as the Python model; LabParams.cs is left unchanged.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text.RegularExpressions;
using UnityEngine;

[Serializable] public class ActivityParams { public float arm_cycles_per_min, intensity; }
[Serializable] public class ActivitiesParams
{
    public ActivityParams seated, standing, walk, brisk, run;
    public ActivityParams Get(string name) => name switch
    {
        "seated" => seated, "standing" => standing, "brisk" => brisk, "run" => run, "walk" => walk, _ => standing
    };
}
[Serializable] public class ZoneParams { public string name, type; public float bend_degrees_walk, bend_degrees_run; }
[Serializable] public class MotionPowerParams
{
    public float seated, standing, walk, brisk, run;
    public float Get(string name) => name switch
    {
        "seated" => seated, "standing" => standing, "brisk" => brisk, "run" => run, "walk" => walk, _ => standing
    };
}
[Serializable] public class AmplifierParams { public bool enabled; public float capture_fraction, charge_efficiency, phone_battery_wh; public MotionPowerParams body_motion_power_w; }
[Serializable] class LabExtraData { public ActivitiesParams activities; public ZoneParams[] zones; public AmplifierParams amplifier_2040; }

public struct DaySegment { public float start, end; public string activity; }
public struct ClassSession { public float start, end; public string id; }

public static class LabParamsExtra
{
    static bool loaded;
    static LabExtraData data;
    static readonly List<DaySegment> day = new List<DaySegment>();
    static readonly List<Vector2> ambient = new List<Vector2>();
    static readonly List<ClassSession> sessions = new List<ClassSession>();

    public static ActivitiesParams Activities { get { Load(); return data.activities; } }
    public static ZoneParams[] Zones { get { Load(); return data.zones; } }
    public static AmplifierParams Amplifier { get { Load(); return data.amplifier_2040; } }
    public static IReadOnlyList<DaySegment> AverageDay { get { Load(); return day; } }
    public static IReadOnlyList<ClassSession> Sessions { get { Load(); return sessions; } }

    static float H(string hh, string mm) => int.Parse(hh) + int.Parse(mm) / 60f;

    static string Section(string json, string key, string endKey)
    {
        int a = json.IndexOf("\"" + key + "\"", StringComparison.Ordinal);
        if (a < 0) return "";
        int b = endKey == null ? json.Length : json.IndexOf("\"" + endKey + "\"", a + key.Length, StringComparison.Ordinal);
        return json.Substring(a, (b < 0 ? json.Length : b) - a);
    }

    static void Load()
    {
        if (loaded) return;
        loaded = true;
        string json = File.ReadAllText(Path.Combine(Application.streamingAssetsPath, "sim_params.json"));
        data = JsonUtility.FromJson<LabExtraData>(json);
        foreach (Match m in Regex.Matches(Section(json, "average_student_day", "thermal"), "\\[\\s*\"(\\d\\d):(\\d\\d)\"\\s*,\\s*\"(\\d\\d):(\\d\\d)\"\\s*,\\s*\"(\\w+)\"\\s*\\]"))
            day.Add(new DaySegment { start = H(m.Groups[1].Value, m.Groups[2].Value), end = H(m.Groups[3].Value, m.Groups[4].Value), activity = m.Groups[5].Value });
        foreach (Match m in Regex.Matches(Section(json, "ambient_profile_c", "attendance"), "\\[\\s*\"(\\d\\d):(\\d\\d)\"\\s*,\\s*(-?[\\d.]+)\\s*\\]"))
            ambient.Add(new Vector2(H(m.Groups[1].Value, m.Groups[2].Value), float.Parse(m.Groups[3].Value, CultureInfo.InvariantCulture)));
        foreach (Match m in Regex.Matches(Section(json, "sessions", "amplifier_2040"), "\\[\\s*\"(\\d\\d):(\\d\\d)\"\\s*,\\s*\"(\\d\\d):(\\d\\d)\"\\s*,\\s*\"([^\"]+)\"\\s*\\]"))
            sessions.Add(new ClassSession { start = H(m.Groups[1].Value, m.Groups[2].Value), end = H(m.Groups[3].Value, m.Groups[4].Value), id = m.Groups[5].Value });
    }

    /// Outside temperature of an average Windhoek day at this hour (linear between the profile points).
    public static float AmbientAt(float hour)
    {
        Load();
        if (ambient.Count == 0) return 22f;
        hour = Mathf.Repeat(hour, 24f);
        if (hour <= ambient[0].x) return ambient[0].y;
        for (int i = 1; i < ambient.Count; i++)
            if (hour <= ambient[i].x) return Mathf.Lerp(ambient[i - 1].y, ambient[i].y, Mathf.InverseLerp(ambient[i - 1].x, ambient[i].x, hour));
        return ambient[ambient.Count - 1].y;
    }

    /// Bend angle (degrees) of the PVDF elbow zones for an activity, from the zones list.
    public static float ElbowBendDegrees(string activity)
    {
        Load();
        float walk = 25f, run = 60f;
        foreach (var z in data.zones) if (z.type == "pvdf") { walk = z.bend_degrees_walk; run = z.bend_degrees_run; break; }
        return activity switch { "run" => run, "brisk" => Mathf.Lerp(walk, run, 0.25f), "walk" => walk, "standing" => walk * 0.4f, _ => walk * 0.25f };
    }

    public static int PvdfZoneCount { get { Load(); int n = 0; foreach (var z in data.zones) if (z.type == "pvdf") n++; return Mathf.Max(n, 1); } }
    public static int TengZoneCount { get { Load(); int n = 0; foreach (var z in data.zones) if (z.type == "teng") n++; return n; } }
}
