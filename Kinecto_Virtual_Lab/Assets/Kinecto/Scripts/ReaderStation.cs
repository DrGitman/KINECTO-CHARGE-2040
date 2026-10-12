// Kinecto Virtual Lab: classroom door reader station.
// Sits next to the user's CuffTapReader (PN532 model) on the reader prop. Pressing E near it moves the student's
// cuff tag into the reader for a moment (the arm reach), CuffTapReader logs IN / OUT after the 0.3 s dwell, and the
// glass doors slide open. "Cuff not reading" (fault) keeps the doors shut. Leaving the room opens the doors freely
// (exit sensor). Only session id + time are logged; mock id only.
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ReaderStation : MonoBehaviour
{
    public CuffTapReader reader;
    public SlidingDoor doors;
    public string roomName = "Room E201";
    public Transform player;
    public Transform cuffTag;                 // the cuff proxy on the player (tag "CuffTag", kinematic rigidbody)
    public LabHud hud;
    public KinectoLabController lab;
    public float reach = 1.9f;
    [Tooltip("Classroom readers record attendance; the Kinecto Hub door is access only")] public bool attendance = true;

    static readonly List<ReaderStation> all = new List<ReaderStation>();
    public static ReaderStation Nearest { get; private set; }
    public static string LastTapText { get; private set; }     // "Tapped IN · Room E201 · 10:02" for the HUD chip
    public bool InReach => player && Vector3.Distance(Flat(player.position), Flat(transform.position)) <= reach;

    bool tapping, gotLog;
    Transform cuffParent; Vector3 cuffLocal;

    static Vector3 Flat(Vector3 v) => new Vector3(v.x, 0f, v.z);

    void OnEnable()
    {
        all.Add(this);
        if (reader) { if (reader.onLog == null) reader.onLog = new UnityEngine.Events.UnityEvent<string>(); reader.onLog.AddListener(OnLog); }
    }
    void OnDisable() { all.Remove(this); if (reader && reader.onLog != null) reader.onLog.RemoveListener(OnLog); }

    void Update()
    {
        // nearest reader in reach (for the HUD prompt and the E key)
        ReaderStation best = null; float bd = float.MaxValue;
        foreach (var s in all)
        {
            if (!s.player) continue;
            float d = Vector3.Distance(Flat(s.player.position), Flat(s.transform.position));
            if (d <= s.reach && d < bd) { bd = d; best = s; }
        }
        Nearest = best;
        if (best == this && !tapping && LabInput.TapPressed) StartCoroutine(Tap());
    }

    IEnumerator Tap()
    {
        tapping = true; gotLog = false;
        // turn to face the reader and play the Mixamo reach/scan clip, then touch the cuff to the reader mid-reach
        if (lab && lab.avatar) { lab.avatar.ResetTrigger("Tap"); lab.avatar.SetTrigger("Tap"); }
        if (player)
        {
            Vector3 to = transform.position - player.position; to.y = 0f;
            if (to.sqrMagnitude > 0.0001f)
            {
                Quaternion from = player.rotation, aim = Quaternion.LookRotation(to.normalized);
                for (float a = 0f; a < 1f; a += Time.deltaTime / 0.25f) { player.rotation = Quaternion.Slerp(from, aim, Mathf.SmoothStep(0f, 1f, a)); yield return null; }
                player.rotation = aim;
            }
        }
        yield return new WaitForSeconds(0.2f);
        if (cuffTag)
        {
            cuffParent = cuffTag.parent; cuffLocal = cuffTag.localPosition;
            cuffTag.SetParent(null, true);
            cuffTag.position = transform.position;            // reach the cuff to the reader
            var col = cuffTag.GetComponent<Collider>(); if (col) col.enabled = true;
        }
        float t = 0f;
        while (t < 0.9f && !gotLog) { t += Time.deltaTime; yield return null; }
        if (cuffTag)
        {
            var col = cuffTag.GetComponent<Collider>(); if (col) col.enabled = false;   // only "reads" while tapping
            cuffTag.SetParent(cuffParent, false); cuffTag.localPosition = cuffLocal; cuffTag.localRotation = Quaternion.identity;
        }
        if (!gotLog)   // reader switched off by the "Cuff not reading" fault: nothing was logged
        {
            if (hud) hud.ShowToast($"Cuff not reading · {roomName} · door stays shut", LabHud.Red);
        }
        yield return new WaitForSeconds(0.4f);
        tapping = false;
    }

    void OnLog(string entry)
    {
        gotLog = true;
        string clock = lab ? lab.ClockText : "";
        if (entry.Contains("tag unreadable"))
        {
            if (hud) hud.ShowToast($"Cuff not reading · {roomName} · door stays shut", LabHud.Red);
            return;
        }
        if (entry.Contains("already recorded"))
        {
            if (hud) hud.ShowToast($"Already recorded · {roomName} · {clock}", LabHud.Gold);
            if (doors) doors.Open(6f);
            return;
        }
        string dir = entry.EndsWith("OUT") ? "OUT" : "IN";
        LastTapText = attendance ? $"Tapped {dir} · {roomName} · {clock}" : $"Access granted · {roomName} · {clock}";
        if (hud) hud.ShowToast(attendance ? $"Tapped {dir} · {roomName} · {clock} · attendance recorded" : $"Access granted · {roomName} · {clock}", LabHud.Green);
        if (doors) doors.Open(6f);
    }
}
