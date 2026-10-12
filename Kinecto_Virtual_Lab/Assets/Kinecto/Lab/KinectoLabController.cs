// Kinecto Virtual Lab: one controller for the 3D person AND the dashboard state, at the same time.
// Adapted for the v3 HUD (LabHud.cs): the person moves for real (WASD / Shift), the clock runs live or plays the
// average school day fast (x28.5 / x114), weather is Cold / Mild / Hot / Real day, the comfort range comes from the
// phone app. Everything runs in Unity from sim_params.json (no MATLAB). SIMULATED values only.
using System.Linq;
using UnityEngine;

public enum LabWeather { Cold, Mild, Hot, RealDay }

public class KinectoLabController : MonoBehaviour
{
    [Header("Modules")]
    public HarvestModel harvest;
    public ThermalModel thermal;
    public FaultInjector faults;
    public SupabaseBridge bridge;              // optional
    public GaitHarvestFallback gait;           // makes elbow strokes from walking until the rig has bones
    public AmplifierCharge amplifier;          // SPECULATIVE 2040 charging
    public Animator avatar;                    // parameters: Speed (float), Tap (trigger) - optional until the rig is in
    public CharacterController mover;
    public Transform cameraPivot;              // third-person camera; WASD is relative to it

    [Header("Movement")]
    public float walkSpeed = 1.4f, runSpeed = 3.2f, turnSpeed = 10f;

    [Header("Clock")]
    [Tooltip("Hour the lab opens at (10.7 = 10:42)")] public float startHour = 10.7f;
    public const float SpeedFast = 28.5f, SpeedVeryFast = 114f;

    [Header("Comfort range from the phone app")]
    public float warmBelowC = 19f, coolAboveC = 26f;

    // ---- state read by the HUD, DaySun, CuffTapReader, SupabaseBridge, SunShadeZone ----
    public string CurrentActivity { get; private set; } = "standing";
    public float LiveSpeed { get; private set; }               // m/s
    Vector3 planarVel; float fallSpeed; Vector3 lastSafe; bool haveSafe;
    [Tooltip("Jump apex height in metres (Space / gamepad A)")] public float jumpHeight = 0.55f;
    float airTime, jumpCooldown, jumpBuffer;
    public bool Grounded { get; private set; } = true;
    public float PowerMicroW { get; private set; }              // harvested power, smoothed
    public float SimDeltaTime { get; private set; }
    public bool ScheduleRunning => scheduleRunning;
    public float TimeSpeed => scheduleRunning ? timeSpeed : 1f;
    public int SpeedChoice => timeSpeed >= SpeedVeryFast ? 1 : 0;
    public LabWeather Weather { get; private set; } = LabWeather.Hot;
    public float DayHours => daySeconds / 3600f;
    public string ClockText { get { int s = (int)daySeconds; return $"{(s / 3600) % 24:00}:{(s / 60) % 60:00}"; } }
    public float OutsideNowC => BaseOutsideC() + shadeOffsetC;
    [HideInInspector] public float shadeOffsetC;               // set by SunShadeZone

    public string WeatherLabel => Weather switch
    {
        LabWeather.Cold => "Cold morning",
        LabWeather.Mild => "Mild day",
        LabWeather.Hot => "Hot afternoon",
        _ => DayHours < 10f ? "Real day · morning" : DayHours < 15f ? "Real day · midday" : DayHours < 18.5f ? "Real day · afternoon" : "Real day · evening"
    };

    float daySeconds, timeSpeed = SpeedVeryFast;
    bool scheduleRunning;
    double lastHarvestJ;

    void Awake()
    {
        daySeconds = startHour * 3600f;
        var t = LabParams.Data.thermal;
        warmBelowC = t.warm_below_c; coolAboveC = t.cool_above_c;
    }

    // ---------- buttons (wired by LabHud) ----------
    public void WeatherCold() => Weather = LabWeather.Cold;
    public void WeatherMild() => Weather = LabWeather.Mild;
    public void WeatherHot() => Weather = LabWeather.Hot;
    public void WeatherRealDay() => Weather = LabWeather.RealDay;
    public void ModeAuto() => SetMode(ComfortMode.Auto);
    public void ModeCool() => SetMode(ComfortMode.Cool);
    public void ModeWarm() => SetMode(ComfortMode.Warm);
    public void ModeOff() => SetMode(ComfortMode.Off);
    public void SetSpeedFast() => timeSpeed = SpeedFast;            // 9.5 h school day in about 20 min
    public void SetSpeedVeryFast() => timeSpeed = SpeedVeryFast;    // about 5 min

    public void PlaySchoolDay()
    {
        harvest.ResetDay(); thermal.ResetDay(); lastHarvestJ = 0; PowerMicroW = 0;
        if (amplifier) amplifier.ResetDay();
        if (gait) gait.ResetDay();
        daySeconds = 7.5f * 3600f; scheduleRunning = true;
    }
    public void StopSchoolDay() => scheduleRunning = false;
    public void JumpToHour(float h) => daySeconds = h * 3600f;

    void SetMode(ComfortMode m) { if (faults && faults.ActiveFlags.Contains("heater_over_limit")) return; thermal.mode = m; }

    // Called by SupabaseBridge when the wearer changes comfort settings in the real phone app.
    public void ApplyComfortFromApp(float warmBelow, float coolAbove, string mode)
    {
        warmBelowC = warmBelow; coolAboveC = coolAbove;
        if (System.Enum.TryParse(mode, true, out ComfortMode m)) SetMode(m);
    }

    float BaseOutsideC() => Weather switch
    {
        LabWeather.Cold => 6f, LabWeather.Mild => 21f, LabWeather.Hot => 35f, _ => LabParamsExtra.AmbientAt(DayHours)
    };

    void Update()
    {
        thermal.warmBelowC = warmBelowC; thermal.coolAboveC = coolAboveC;

        // Any movement key takes control back from the schedule.
        Vector3 input = new Vector3(LabInput.Horizontal, 0f, LabInput.Vertical);
        if (input.sqrMagnitude > 0.01f) scheduleRunning = false;

        SimDeltaTime = Time.deltaTime * TimeSpeed;
        daySeconds += SimDeltaTime;

        if (scheduleRunning) FollowSchedule(); else LiveControl(input);
        if (LabInput.ModePressed) SetMode((ComfortMode)(((int)thermal.mode + 1) % 4));

        thermal.ambientC = OutsideNowC;
        if (gait) gait.Tick(SimDeltaTime, CurrentActivity);
        if (amplifier) amplifier.Tick(SimDeltaTime, CurrentActivity);
        thermal.Step(SimDeltaTime);
        harvest.Step(SimDeltaTime);

        double dJ = harvest.harvestedJ - lastHarvestJ; lastHarvestJ = harvest.harvestedJ;
        if (SimDeltaTime > 0f) PowerMicroW = Mathf.Lerp(PowerMicroW, (float)(dJ / SimDeltaTime * 1e6), Mathf.Clamp01(Time.deltaTime * 1.5f));
    }

    void LiveControl(Vector3 input)
    {
        bool run = LabInput.Run;
        if (LabInput.JumpPressed) jumpBuffer = 0.15f;                  // remembered briefly so a press is never lost
        Vector3 dir = input;
        if (cameraPivot)
        {
            Vector3 f = cameraPivot.forward; f.y = 0f; f.Normalize();
            Vector3 r = cameraPivot.right; r.y = 0f; r.Normalize();
            dir = f * input.z + r * input.x;
        }
        float mag = Mathf.Clamp01(dir.magnitude);
        float speed = mag * (run ? runSpeed : walkSpeed);
        // accelerate / brake smoothly (no instant 0 -> 3 m/s pops) so the Idle-Walk-Run blend glides
        Vector3 target = dir.sqrMagnitude > 0.0001f ? dir.normalized * speed : Vector3.zero;
        float accel = target.sqrMagnitude > planarVel.sqrMagnitude ? 6f : 9f;
        planarVel = Vector3.MoveTowards(planarVel, target, accel * Time.deltaTime);
        if (mover)
        {
            MoveWithGravity(planarVel);
            if (planarVel.sqrMagnitude > 0.0025f)
            {
                var look = Quaternion.LookRotation(planarVel.normalized);
                mover.transform.rotation = Quaternion.RotateTowards(mover.transform.rotation, look, 540f * Time.deltaTime);
            }
            Vector3 v = mover.velocity; v.y = 0f; LiveSpeed = v.magnitude;
        }
        else LiveSpeed = planarVel.magnitude;
        if (avatar) { avatar.SetFloat("Speed", LiveSpeed, 0.12f, Time.deltaTime); avatar.speed = 1f; }
        CurrentActivity = LiveSpeed < 0.15f ? "standing" : run && LiveSpeed > 2f ? "run" : "walk";
    }

    // Real gravity + collision: the CharacterController capsule slides along walls, doors, trees and props, steps up
    // kerbs (stepOffset) and is pulled down at 9.81 m/s^2 so it always lands on the ground mesh. If anything ever drops
    // it below the world, it is put back on the last solid ground it stood on.
    void MoveWithGravity(Vector3 horizontal)
    {
        if (!mover || !mover.enabled) return;
        jumpCooldown -= Time.deltaTime; jumpBuffer -= Time.deltaTime;
        bool canJump = (mover.isGrounded || airTime < 0.12f) && fallSpeed <= 0f;   // small "coyote time" off kerbs
        if (mover.isGrounded && fallSpeed <= 0f) fallSpeed = -2f;      // small stick-to-ground force on slopes / steps
        else fallSpeed = Mathf.Max(fallSpeed + Physics.gravity.y * Time.deltaTime, -40f);
        {
            if (canJump && jumpBuffer > 0f && jumpCooldown <= 0f)
            {
                jumpBuffer = 0f;
                fallSpeed = Mathf.Sqrt(2f * -Physics.gravity.y * jumpHeight);   // v = sqrt(2 g h)
                if (gait) gait.Impact(fallSpeed);                                // take-off push = kinetic energy too
                jumpCooldown = 0.35f;
                if (avatar) { avatar.ResetTrigger("Tap"); avatar.SetTrigger("Jump"); }
            }
        }
        bool wasAirborne = !mover.isGrounded; float impact = -fallSpeed;
        var flags = mover.Move((horizontal + Vector3.up * fallSpeed) * Time.deltaTime);
        if (wasAirborne && mover.isGrounded && impact > 2.5f && gait) gait.Impact(impact);   // landing impact
        if ((flags & CollisionFlags.Above) != 0 && fallSpeed > 0f) fallSpeed = 0f;   // bumped the head on a ceiling
        Grounded = mover.isGrounded;
        airTime = Grounded ? 0f : airTime + Time.deltaTime;
        if (avatar)
        {
            avatar.SetBool("Grounded", Grounded || airTime < 0.12f);    // ignore tiny drops off kerbs / steps
            avatar.SetFloat("VerticalSpeed", fallSpeed);
        }
        if (Grounded) { lastSafe = mover.transform.position; haveSafe = true; }
        if (mover.transform.position.y < -25f && haveSafe)
        {
            mover.enabled = false; mover.transform.position = lastSafe + Vector3.up * 0.3f; mover.enabled = true;
            fallSpeed = 0f; planarVel = Vector3.zero;
        }
    }

    void FollowSchedule()
    {
        MoveWithGravity(Vector3.zero);
        float h = DayHours; string act = "standing";
        foreach (var seg in LabParamsExtra.AverageDay) if (h >= seg.start && h < seg.end) act = seg.activity;
        CurrentActivity = act;
        LiveSpeed = act == "walk" ? walkSpeed : act == "brisk" ? walkSpeed * 1.3f : act == "run" ? runSpeed : 0f;
        if (avatar) { avatar.SetFloat("Speed", LiveSpeed, 0.2f, Time.deltaTime); avatar.speed = 1f; }
        if (h >= 17f) scheduleRunning = false;            // the school day is over: back to live
    }
}
