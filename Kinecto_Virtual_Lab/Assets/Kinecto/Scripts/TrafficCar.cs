// Kinecto Virtual Lab: one traffic car. Follows its lane, keeps its distance to the car in front, waits for the
// junction box, turns on a smooth curve, brakes for people, spins its wheels.
using System.Collections.Generic;
using UnityEngine;

public class TrafficCar : MonoBehaviour
{
    public float s;                                    // distance along the current lane
    public bool InTurn => turn != null;
    public TrafficSystem.Node TurnNode => turnNode;

    TrafficSystem sys; TrafficSystem.Edge edge, next;
    List<Vector3> turn; int turnI; TrafficSystem.Node turnNode;
    float speed, cruise, accel = 3.2f, brake = 7f;
    System.Random rnd;
    Transform[] wheels; Quaternion[] wheelRest; float wheelR = 0.33f, wheelAngle;
    float halfLen = 2.3f;
    Vector3 lastPos;

    public void Init(TrafficSystem system, TrafficSystem.Edge e, float startS, float cruiseSpeed, int seed)
    {
        sys = system; edge = e; s = startS; cruise = cruiseSpeed; speed = cruise * 0.6f; rnd = new System.Random(seed);
        edge.cars.Add(this);
        var ws = new List<Transform>();
        foreach (var t in GetComponentsInChildren<Transform>()) if (t.name.Contains("Wheel_")) ws.Add(t);
        wheels = ws.ToArray();
        wheelRest = new Quaternion[wheels.Length];
        for (int i = 0; i < wheels.Length; i++) wheelRest[i] = wheels[i].localRotation;
        var rends = GetComponentsInChildren<Renderer>();
        if (rends.Length > 0)
        {
            var b = rends[0].bounds; foreach (var r in rends) b.Encapsulate(r.bounds);
            halfLen = b.extents.z;
            foreach (var w in wheels) { var wr = w.GetComponent<Renderer>(); if (wr) wheelR = Mathf.Max(0.2f, wr.bounds.extents.y); }
            foreach (var c in GetComponentsInChildren<Collider>()) if (c.gameObject != gameObject) Destroy(c);
            var col = gameObject.GetComponent<BoxCollider>(); if (!col) col = gameObject.AddComponent<BoxCollider>();
            col.center = transform.InverseTransformPoint(b.center); col.size = new Vector3(b.size.x, b.size.y, b.size.z);
        }
        var rb = gameObject.GetComponent<Rigidbody>(); if (!rb) rb = gameObject.AddComponent<Rigidbody>(); rb.isKinematic = true; rb.interpolation = RigidbodyInterpolation.None;
        transform.position = edge.At(s); transform.rotation = Quaternion.LookRotation(edge.Dir);
        lastPos = transform.position;
        next = sys.NextEdge(edge, rnd);
    }

    void Update()
    {
        if (sys == null) return;
        float dt = Time.deltaTime;
        float target = cruise;
        Vector3 fwd = transform.forward;

        // the car ahead on the same lane
        float gap = float.MaxValue;
        if (turn == null)
        {
            foreach (var o in edge.cars) if (o != this && o.s > s) gap = Mathf.Min(gap, o.s - s);
            float toEnd = edge.length - s;
            // approaching the junction: queue until the box is free
            if (toEnd < 14f)
            {
                bool ok = sys.RequestNode(edge.b, this);
                if (!ok) gap = Mathf.Min(gap, toEnd + halfLen);
                if (ok && toEnd < 0.5f) StartTurn();
            }
        }
        else
        {
            foreach (var o in sys.cars)
            {
                if (o == this) continue;
                Vector3 d = o.transform.position - transform.position; d.y = 0;
                float f = Vector3.Dot(d, fwd);
                if (f > 0 && f < 12f && Mathf.Abs(Vector3.Dot(d, transform.right)) < 2.2f) gap = Mathf.Min(gap, f);
            }
        }
        float safe = halfLen * 2f + 3f + speed * 1.1f;
        if (gap < safe) target = Mathf.Min(target, Mathf.Max(0f, (gap - halfLen * 2f - 1.5f) * 1.2f));
        // someone in the lane: brake smoothly and wait ~5 m in front of them until they step aside
        float pd = sys.PersonDistance(transform.position, fwd, 26f);
        if (pd < 26f) { float allow = (pd - halfLen - 5f) * 1.1f; target = Mathf.Min(target, allow < 0.5f ? 0f : allow); }
        if (turn != null) target = Mathf.Min(target, turnNode.roundabout ? 8f : 5.5f);

        speed = Mathf.MoveTowards(speed, target, (target > speed ? accel : brake) * dt);
        float ds = speed * dt;

        if (turn == null)
        {
            s += ds;
            Vector3 p = edge.At(s);
            Place(p, edge.Dir, dt);
            if (s >= edge.length && sys.RequestNode(edge.b, this)) StartTurn();
        }
        else
        {
            // walk along the turn polyline
            while (ds > 0f && turnI < turn.Count - 1)
            {
                Vector3 a = transform.position, b = turn[turnI + 1];
                Vector3 flat = b - a; flat.y = 0;
                float L = flat.magnitude;
                if (L <= ds) { ds -= L; turnI++; transform.position = b; }
                else { Vector3 p = a + flat.normalized * ds; p.y = Mathf.Lerp(a.y, b.y, ds / Mathf.Max(L, 1e-3f)); Place(p, flat.normalized, dt); ds = 0f; }
            }
            if (turnI >= turn.Count - 1) EndTurn();
        }

        // wheels
        float moved = Vector3.Distance(lastPos, transform.position); lastPos = transform.position;
        wheelAngle = Mathf.Repeat(wheelAngle + moved / wheelR * Mathf.Rad2Deg, 360f);
        for (int i = 0; i < wheels.Length; i++) wheels[i].localRotation = wheelRest[i] * Quaternion.Euler(wheelAngle, 0, 0);
    }

    void Place(Vector3 p, Vector3 dir, float dt)
    {
        transform.position = p;
        if (dir.sqrMagnitude > 1e-4f)
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(new Vector3(dir.x, 0, dir.z)), Mathf.Clamp01(dt * 8f));
    }

    void StartTurn()
    {
        if (turn != null) return;
        if (next == null) next = sys.NextEdge(edge, rnd);
        turnNode = edge.b;
        turn = sys.TurnPath(edge, next); turnI = 0;
        edge.cars.Remove(this);
    }

    void EndTurn()
    {
        sys.ReleaseNode(turnNode, this);
        edge = next; s = 0f; edge.cars.Add(this);
        turn = null; turnNode = null;
        next = sys.NextEdge(edge, rnd);
    }
}
