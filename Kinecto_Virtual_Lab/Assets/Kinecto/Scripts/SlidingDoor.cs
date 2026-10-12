// Kinecto Virtual Lab: pair of sliding glass doors. Opened by a ReaderStation tap (player) or a campus NPC's tap;
// the exit sensor on the inside opens them freely when someone walks out. Closes again after the hold time.
using System.Collections.Generic;
using UnityEngine;

public class SlidingDoor : MonoBehaviour
{
    public Transform left, right;
    public Transform reader;                  // marks the OUTSIDE (the reader side)
    public Transform player;
    public float slide = 1.2f, speed = 2.2f, exitSensor = 2.0f;

    /// <summary>campus NPCs: they use the exit sensor and keep the doors open while passing, like the player</summary>
    public static readonly List<Transform> Agents = new List<Transform>();

    Vector3 lClosed, rClosed, dir, mid, outside;
    float open, holdUntil; bool ready;
    public bool IsOpen => open > 0.6f;
    public float OpenAmount => open;
    public Vector3 Mid { get { Init(); return mid; } }
    public Vector3 OutsideDir { get { Init(); return outside; } }   // unit vector from the doors towards the reader side

    void Awake() { Init(); }

    void Init()
    {
        if (ready || !left || !right) return;
        ready = true;
        lClosed = left.position; rClosed = right.position;
        mid = (lClosed + rClosed) * 0.5f;
        dir = left.position - right.position; dir.y = 0f; dir.Normalize();
        Vector3 n = Vector3.Cross(dir, Vector3.up);
        outside = reader && Vector3.Dot(reader.position - mid, n) < 0f ? -n : n;
    }

    public void Open(float seconds) { holdUntil = Mathf.Max(holdUntil, Time.time + seconds); }

    void Sense(Transform t)
    {
        if (!t) return;
        Vector3 d = t.position - mid; d.y = 0f;
        float m = d.magnitude;
        if (m > exitSensor) return;
        bool inside = Vector3.Dot(d, outside) < 0f;
        if (inside) Open(1.2f);                       // exit sensor: walk out freely
        else if (open > 0.05f) Open(1.2f);            // stay open while passing through, close ~1 s after
    }

    void Update()
    {
        Init();
        Sense(player);
        if (!CampusNpc.Paused) for (int i = 0; i < Agents.Count; i++) Sense(Agents[i]);
        float target = Time.time < holdUntil ? 1f : 0f;
        open = Mathf.MoveTowards(open, target, Time.deltaTime * speed);
        float e = Mathf.SmoothStep(0f, 1f, open) * slide;
        left.position = lClosed + dir * e;
        right.position = rClosed - dir * e;
    }
}
