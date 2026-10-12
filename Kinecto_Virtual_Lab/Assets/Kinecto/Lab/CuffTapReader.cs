// Kinecto Virtual Lab: attendance module.
// Put this on the classroom reader station (PN532 model) with a small trigger collider.
// The avatar's cuff tag is a child of the left hand bone with a tiny collider + tag "CuffTag".
// Logs session id + time only (mock ID). No location history is ever stored.
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

public class CuffTapReader : MonoBehaviour
{
    public string sessionId = "EPH810S";
    public Light readerLight;                 // green = recorded, amber = already recorded
    public AudioSource beep;
    public UnityEvent<string> onLog;          // dashboard listens to show the tap log
    public SupabaseBridge bridge;            // optional: posts the tap to attendance-ingest (Attendance desk updates live)
    public FaultInjector faults;             // optional: "Cuff tag unreadable" fault makes taps fail

    public readonly List<string> log = new List<string>();
    float enterTime = -1f, lastTap = -999f; bool checkedIn;
    AttendanceParams p;

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
            Show(Color.yellow); log.Add($"{clock}  {sessionId}  already recorded"); onLog?.Invoke(log[^1]); return;
        }
        if (faults && !faults.cuffTagReadable) { Show(Color.red); log.Add($"{clock}  {sessionId}  tag unreadable"); onLog?.Invoke(log[^1]); return; }
        lastTap = Time.time; checkedIn = !checkedIn;
        string entry = $"{clock}  {sessionId}  {p.mock_student_id}  {(checkedIn ? "IN" : "OUT")}";
        log.Add(entry); onLog?.Invoke(entry); Show(Color.green); if (beep) beep.Play();
        if (bridge) bridge.SendTap(p.mock_student_id, checkedIn ? "IN" : "OUT");
    }

    void Show(Color c) { if (readerLight) { readerLight.color = c; readerLight.enabled = true; CancelInvoke(nameof(Off)); Invoke(nameof(Off), 0.8f); } }
    void Off() { if (readerLight) readerLight.enabled = false; }
}
