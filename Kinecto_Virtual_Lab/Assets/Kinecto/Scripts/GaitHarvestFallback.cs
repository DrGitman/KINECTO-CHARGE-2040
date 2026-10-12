// Kinecto Virtual Lab: every bit of kinetic energy the jacket sees becomes electricity (SIMULATED).
// Sources, each with the SAME HarvestModel equations as JointBendSensor / TengContactZone:
//   elbow bends (PVDF patches)        - per arm cycle, bend angle from the zones in sim_params.json
//   shoulder swing (TENG patches)     - per arm cycle
//   torso / back contact (TENG panel) - per footstep (two steps per arm cycle)
//   turning / twisting (TENG torso)   - per 30 degrees the body turns
//   starting off / speeding up        - a kinetic burst on the PVDF patches when the body accelerates
//   jumps (take-off + landing)        - the jacket slaps the back / shoulders: TENG contacts scaled by the impact speed
// Arm cycles follow the person's real speed in live mode (any movement counts), the activity table in day mode.
// Works until the rig has bones; then JointBendSensor / TengContactZone take over the elbow + shoulder sources.
using System;
using System.Collections.Generic;
using UnityEngine;

public class GaitHarvestFallback : MonoBehaviour
{
    public HarvestModel harvest;
    public KinectoLabController lab;
    public Transform body;                    // the player (for turning)
    [Tooltip("Optional: set when the rig is in; then the real bone sensors take over elbows + shoulders")] public JointBendSensor[] boneSensors;
    [Tooltip("Sensor zones on the jacket: they light up when they make energy")] public Renderer[] pvdfZones, tengZones;

    public static readonly string[] Sources = { "elbow bend", "shoulder swing", "back contact", "body twist", "speed-up", "jump impact" };
    public readonly double[] SourceJ = new double[6];          // energy today per source

    /// Energy of the last stroke and where it came from (HUD callout).
    public double LastBendJ { get; private set; }
    public int LastSource { get; private set; }
    public float LastBendTime { get; private set; } = -99f;
    public event Action<int, double> OnHarvest;

    double cycles, steps; float lastYaw; bool yawInit; float lastSpeed;
    readonly Dictionary<Renderer, float> flash = new Dictionary<Renderer, float>();

    void Start()
    {
        foreach (var r in Zones()) if (r) r.enabled = false;            // only visible while they make energy
    }

    IEnumerable<Renderer> Zones()
    {
        if (pvdfZones != null) foreach (var r in pvdfZones) yield return r;
        if (tengZones != null) foreach (var r in tengZones) yield return r;
    }

    bool BonesActive()
    {
        if (boneSensors == null) return false;
        foreach (var s in boneSensors) if (s && s.isActiveAndEnabled && s.upperArm && s.lowerArm) return true;
        return false;
    }

    /// Take-off or landing: the jacket hits the back and shoulders. impactSpeed in m/s (about 3 for a normal jump).
    public void Impact(float impactSpeed)
    {
        if (!harvest) return;
        int contacts = Mathf.Clamp(Mathf.RoundToInt(impactSpeed * 1.5f), 1, 12);
        double b = harvest.harvestedJ;
        for (int i = 0; i < contacts; i++) harvest.AddTengContact();
        harvest.AddPvdfBend(Mathf.Clamp(impactSpeed * 8f, 10f, 45f));            // the elbows flex on the landing too
        var z = new List<Renderer>(); if (tengZones != null) z.AddRange(tengZones); if (pvdfZones != null) z.AddRange(pvdfZones);
        Record(5, b, z.ToArray());
    }

    public void ResetDay() { for (int i = 0; i < SourceJ.Length; i++) SourceJ[i] = 0; }

    void Record(int src, double before, Renderer[] zones)
    {
        double gained = harvest.harvestedJ - before;
        if (gained <= 0) return;
        SourceJ[src] += gained; LastBendJ = gained; LastSource = src; LastBendTime = Time.time;
        OnHarvest?.Invoke(src, gained);
        if (zones != null) foreach (var r in zones) if (r) flash[r] = Time.time + 0.25f;
    }

    public void Tick(float simDt, string activity)
    {
        var act = LabParamsExtra.Activities.Get(activity);
        if (act == null || simDt <= 0f) { UpdateFlash(); return; }
        harvest.intensity = act.intensity;
        bool live = lab && !lab.ScheduleRunning;
        float speed = lab ? lab.LiveSpeed : 0f;

        // arm cycles per minute: from the real speed in live mode (walk 1.4 m/s -> 52/min, run 3.2 m/s -> 80/min)
        float cpm = act.arm_cycles_per_min;
        if (live)
        {
            var walk = LabParamsExtra.Activities.walk; var run = LabParamsExtra.Activities.run; var stand = LabParamsExtra.Activities.standing;
            cpm = speed < 0.15f ? stand.arm_cycles_per_min
                : speed <= 1.4f ? Mathf.Lerp(stand.arm_cycles_per_min, walk.arm_cycles_per_min, speed / 1.4f)
                : Mathf.Lerp(walk.arm_cycles_per_min, run.arm_cycles_per_min, Mathf.InverseLerp(1.4f, 3.2f, speed));
        }
        float bend = LabParamsExtra.ElbowBendDegrees(activity);
        bool bones = BonesActive();
        cycles += cpm / 60.0 * simDt;
        int n = 0;
        while (cycles >= 1.0 && n < 400)
        {
            cycles -= 1.0; n++;
            if (!bones)
            {
                double b0 = harvest.harvestedJ;
                for (int z = 0; z < LabParamsExtra.PvdfZoneCount; z++) { harvest.AddPvdfBend(bend); harvest.AddPvdfBend(bend); }   // bend + release
                Record(0, b0, pvdfZones);
                double b1 = harvest.harvestedJ;
                harvest.AddTengContact(); harvest.AddTengContact();          // left + right shoulder
                Record(1, b1, tengZones);
            }
            steps += 2;
        }
        // footsteps press the back / torso panel (walking and running only)
        while (steps >= 1.0 && n < 800)
        {
            steps -= 1.0; n++;
            if (speed > 0.3f || activity == "walk" || activity == "run" || activity == "brisk")
            { double b = harvest.harvestedJ; harvest.AddTengContact(); Record(2, b, tengZones); }
        }
        // turning / twisting the torso
        if (body)
        {
            float yaw = body.eulerAngles.y;
            if (!yawInit) { lastYaw = yaw; yawInit = true; }
            float turned = Mathf.Abs(Mathf.DeltaAngle(lastYaw, yaw));
            if (turned >= 30f) { lastYaw = yaw; double b = harvest.harvestedJ; harvest.AddTengContact(); harvest.AddTengContact(); Record(3, b, tengZones); }
        }
        // speeding up: a burst on the elbow patches proportional to the jump in speed
        if (live && speed - lastSpeed > 0.6f)
        {
            double b = harvest.harvestedJ;
            harvest.AddPvdfBend(Mathf.Clamp((speed - lastSpeed) * 25f, 10f, 60f));
            Record(4, b, pvdfZones);
            lastSpeed = speed;
        }
        else if (speed < lastSpeed) lastSpeed = speed;
        UpdateFlash();
    }

    void UpdateFlash()
    {
        foreach (var r in Zones())
        {
            if (!r) continue;
            bool on = flash.TryGetValue(r, out float until) && Time.time < until;
            if (r.enabled != on) r.enabled = on;
        }
    }
}
