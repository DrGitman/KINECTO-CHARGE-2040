// Kinecto Virtual Lab: attendance module.
// Put this on a reader station (PN532 model) with a small trigger collider.
// The avatar's cuff tag is a child of the left hand bone with a tiny collider + tag "CuffTag".
// Classrooms have two readers on the same session: the tap-IN reader outside the door and the tap-OUT station inside.
// A tap-in while already in (or a tap-out while not in) is logged as such, so the attendance log stays consistent.
// The Hub door reader is access only (Toggle). Logs session id + time only (mock ID). No location history is ever stored.
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

public class CuffTapReader : MonoBehaviour
{
    public enum Direction { Toggle, In, Out }
    public Direction direction = Direction.Toggle;
    public string sessionId = "EPH810S";
    public Light readerLight;                 // green = recorded, amber = already recorded / no tap-in
    public AudioSource beep;
    public UnityEvent<string> onLog;          // dashboard listens to show the tap log
    public SupabaseBridge bridge;            // optional: posts the tap to attendance-ingest (Attendance desk updates live)
    public FaultInjector faults;             // optional: "Cuff tag unreadable" fault makes taps fail

    public readonly List<string> log = new List<string>();
    float enterTime = -1f, lastTap = -999f;
    AttendanceParams p;

    /// <summary>who is checked in to which session (shared by the IN and OUT readers of a room); mock student only</summary>
    static readonly Dictionary<string, bool> checkedIn = new Dictionary<string, bool>();
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)] static void ResetState() => checkedIn.Clear();
    public static bool IsCheckedIn(string session) => checkedIn.TryGetValue(session, out var v) && v;
    public bool CheckedIn => IsCheckedIn(sessionId);

    void Awake() { p = LabParams.Data.attendance; }

    void OnTriggerEnter(Collider other) { if (other.CompareTag("CuffTag")) enterTime = Time.time; }
    void OnTriggerExit(Collider other) { if (other.CompareTag("CuffTag")) enterTime = -1f; }

    void Update()
    {
        if (enterTime < 0f || Time.time - enterTime < p.dwell_s) return;   // must hold the cuff ~0.3 s
        enterTime = -1f;
        string clock = FindObjectOfType<KinectoLabController>()?.ClockText ?? Time.time.ToString("0");
        if (Time.time - lastTap < p.debounce_s)
        {
            Show(Color.yellow); Add($"{clock}  {sessionId}  already recorded"); return;
        }
        if (faults && !faults.cuffTagReadable) { Show(Color.red); Add($"{clock}  {sessionId}  tag unreadable"); return; }
        lastTap = Time.time;
        bool wasIn = CheckedIn;
        bool tapIn = direction == Direction.In || (direction == Direction.Toggle && !wasIn);
        if (tapIn && wasIn && direction == Direction.In)
        {   // second tap-in without a tap-out: nothing new to record, the doors still open
            Show(Color.yellow); Add($"{clock}  {sessionId}  {p.mock_student_id}  IN already recorded"); return;
        }
        checkedIn[sessionId] = tapIn;
        string dir = tapIn ? "IN" : "OUT";
        string note = !tapIn && !wasIn ? "  (no tap-in)" : "";
        Add($"{clock}  {sessionId}  {p.mock_student_id}  {dir}{note}");
        Show(note.Length > 0 ? Color.yellow : Color.green); if (beep) beep.Play();
        if (bridge) bridge.SendTap(p.mock_student_id, dir, (ok, message) =>
        {   // the cloud has the final say (e.g. the lecturer has not opened the session yet)
            if (!ok) Show(Color.red);
            Add($"{clock}  {sessionId}  cloud: {message}");
        });
    }

    void Add(string entry) { log.Add(entry); onLog?.Invoke(entry); }

    void Show(Color c) { if (readerLight) { readerLight.color = c; readerLight.enabled = true; CancelInvoke(nameof(Off)); Invoke(nameof(Off), 0.8f); } }
    void Off() { if (readerLight) readerLight.enabled = false; }
}
