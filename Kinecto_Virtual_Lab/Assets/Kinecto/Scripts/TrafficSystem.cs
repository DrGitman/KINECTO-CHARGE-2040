// Kinecto Virtual Lab: Windhoek traffic. Builds a lane graph from the city's road grid (same constants the Blender
// city was built from), spawns the low-poly cars and drives them: left-hand traffic, clockwise round the Christuskirche
// roundabout, smooth turns at junctions (one car at a time through a junction box), safe following distance, and every
// car brakes for people (the player and the NPCs) on the road ahead. Cars are solid (kinematic colliders) and their
// wheels spin with their speed. Heights come from ground ray casts so the cars sit on the terrain.
using System.Collections.Generic;
using UnityEngine;

public class TrafficSystem : MonoBehaviour
{
    [Header("Cars")]
    public GameObject[] carPrefabs;
    public int carCount = 38;
    public float cruise = 11f;                       // m/s (40 km/h in town)
    public LayerMask groundMask = ~0;
    [Tooltip("ray-cast only these (the road surface, then the ground) so cars never land on trees or roofs")] public Collider[] groundColliders;
    public Transform player;
    [Tooltip("spawn more cars near the campus, where you can see them")] public Vector3 focus = new Vector3(0, 0, 0);

    // ---- road grid in BLENDER coordinates (x east, y north); Unity = (-x, h, -y)
    static readonly float[] XS = { -630, -530, -430, -330, -230, -130, 0, 130, 230, 330, 430, 530, 630 };
    static readonly float[] YS = { -465, -365, -265, -165, -65, 20, 105, 205, 305, 405, 505 };
    const float INDEP_X = 330, RMA_X = 530, MAIN_Y = -65, FIDEL_Y = -165;
    static readonly Vector2 RB = new Vector2(530, -165); const float RB_R = 44f;

    public class Node { public int id; public Vector2 p; public bool roundabout; public List<Edge> outs = new List<Edge>(); public TrafficCar holder; public float holdUntil; public float half = 7f; }
    public class Edge
    {
        public Node a, b; public float lane; public Vector3 p0, p1; public float length; public List<TrafficCar> cars = new List<TrafficCar>();
        public Vector3 Dir => (p1 - p0).normalized;
        public Vector3 At(float s) => Vector3.Lerp(p0, p1, Mathf.Clamp01(s / Mathf.Max(length, 0.01f)));
    }
    public readonly List<Node> nodes = new List<Node>();
    public readonly List<Edge> edges = new List<Edge>();
    public readonly List<TrafficCar> cars = new List<TrafficCar>();
    public static TrafficSystem Instance;

    public static Vector3 U(Vector2 b, float h = 0f) => new Vector3(-b.x, h, -b.y);

    static bool NS(float x, float y)                 // is (x, y) on a north-south road?
    {
        if (y < -465 || y > 505) return false;
        if (x == 0) return (y >= -465 && y <= -65) || (y >= 105 && y <= 505);
        return true;
    }
    static bool EW(float x, float y)
    {
        if (y == MAIN_Y) return x >= -650 && x <= 650;
        if (x < -630 || x > 630) return false;
        if (y == 20) return (x >= -630 && x <= -130) || (x >= 130 && x <= 630);
        return true;
    }
    static float WidthNS(float x) => x == INDEP_X ? 24f : x == RMA_X ? 14f : 9f;
    static float WidthEW(float y) => y == MAIN_Y ? 10f : y == FIDEL_Y ? 12f : 9f;
    static float LaneOff(float width) => width >= 20f ? 7.5f : 2.2f;

    void Awake() { Instance = this; }

    void Start()
    {
        Build();
        Spawn();
    }

    void Build()
    {
        var grid = new Dictionary<(float, float), Node>();
        foreach (var x in XS) foreach (var y in YS)
            if (NS(x, y) && EW(x, y))
            {
                var n = new Node { id = nodes.Count, p = new Vector2(x, y) };
                n.roundabout = Mathf.Approximately(x, RB.x) && Mathf.Approximately(y, RB.y);
                n.half = n.roundabout ? RB_R : Mathf.Max(WidthNS(x), WidthEW(y)) * 0.5f + 2f;
                grid[(x, y)] = n; nodes.Add(n);
            }
        // north-south links
        foreach (var x in XS)
            for (int j = 0; j < YS.Length - 1; j++)
            {
                float y0 = YS[j], y1 = YS[j + 1];
                if (!grid.TryGetValue((x, y0), out var a) || !grid.TryGetValue((x, y1), out var b)) continue;
                if (!NS(x, (y0 + y1) * 0.5f)) continue;
                Link(a, b, LaneOff(WidthNS(x))); Link(b, a, LaneOff(WidthNS(x)));
            }
        foreach (var y in YS)
            for (int i = 0; i < XS.Length - 1; i++)
            {
                float x0 = XS[i], x1 = XS[i + 1];
                if (!grid.TryGetValue((x0, y), out var a) || !grid.TryGetValue((x1, y), out var b)) continue;
                if (!EW((x0 + x1) * 0.5f, y)) continue;
                Link(a, b, LaneOff(WidthEW(y))); Link(b, a, LaneOff(WidthEW(y)));
            }
    }

    void Link(Node a, Node b, float lane)
    {
        Vector2 d = (b.p - a.p).normalized;
        Vector2 left = new Vector2(-d.y, d.x);                          // Blender: left of travel = (-dy, dx)
        Vector2 s = a.p + d * a.half + left * lane, e = b.p - d * b.half + left * lane;
        var ed = new Edge { a = a, b = b, lane = lane, p0 = Ground(U(s)), p1 = Ground(U(e)) };
        ed.length = Vector3.Distance(ed.p0, ed.p1);
        if (ed.length < 2f) return;
        a.outs.Add(ed); edges.Add(ed);
    }

    public Vector3 Ground(Vector3 p)
    {
        if (groundColliders != null && groundColliders.Length > 0)
        {
            var ray = new Ray(p + Vector3.up * 150f, Vector3.down);
            foreach (var c in groundColliders)
                if (c && c.Raycast(ray, out var h, 400f)) return h.point;
            return p;
        }
        if (Physics.Raycast(p + Vector3.up * 120f, Vector3.down, out var hit, 400f, groundMask, QueryTriggerInteraction.Ignore))
        {
            if (hit.collider.GetComponentInParent<TrafficCar>() == null) return hit.point;
        }
        return p;
    }

    void Spawn()
    {
        if (carPrefabs == null || carPrefabs.Length == 0 || edges.Count == 0) return;
        var rnd = new System.Random(2040);
        int tries = 0;
        while (cars.Count < carCount && tries++ < carCount * 60)
        {
            var e = edges[rnd.Next(edges.Count)];
            float dist = Vector3.Distance((e.p0 + e.p1) * 0.5f, focus);
            if (rnd.NextDouble() > 1.0 / (1.0 + dist / 220f)) continue;          // denser traffic near the campus
            float s = (float)rnd.NextDouble() * e.length;
            bool clash = false;
            foreach (var c in e.cars) if (Mathf.Abs(c.s - s) < 14f) { clash = true; break; }
            if (clash) continue;
            // wrap the model so the FBX axis fix-up rotation on its root is kept (the car drives along +Z of the wrapper)
            var go = new GameObject("Car_" + cars.Count);
            go.transform.SetParent(transform, false);
            var model = Instantiate(carPrefabs[rnd.Next(carPrefabs.Length)], go.transform, false);
            model.name = carPrefabs[0] ? model.name.Replace("(Clone)", "") : model.name;
            var car = go.GetComponent<TrafficCar>() ?? go.AddComponent<TrafficCar>();
            car.Init(this, e, s, cruise * (0.85f + 0.3f * (float)rnd.NextDouble()), rnd.Next());
            cars.Add(car);
        }
    }

    // ---------- junction paths
    public Edge NextEdge(Edge from, System.Random rnd)
    {
        var n = from.b; var opts = new List<Edge>();
        foreach (var e in n.outs) if (e.b != from.a) opts.Add(e);
        if (opts.Count == 0) opts.AddRange(n.outs);                 // dead end: turn round
        // prefer straight on a little
        Vector3 d = from.Dir; Edge straight = null;
        foreach (var e in opts) if (Vector3.Dot(e.Dir, d) > 0.9f) straight = e;
        if (straight != null && rnd.NextDouble() < 0.45) return straight;
        return opts[rnd.Next(opts.Count)];
    }

    /// <summary>points from the end of one lane to the start of the next, through the junction or round the roundabout</summary>
    public List<Vector3> TurnPath(Edge from, Edge to)
    {
        var pts = new List<Vector3>();
        var n = from.b;
        if (n.roundabout)
        {
            Vector3 c = U(n.p); float r = RB_R - 3.5f;
            float a0 = Mathf.Atan2(from.p1.z - c.z, from.p1.x - c.x), a1 = Mathf.Atan2(to.p0.z - c.z, to.p0.x - c.x);
            // left-hand traffic goes clockwise seen from above. In Unity (x, z) with x = -east, clockwise from above is +angle
            float da = Mathf.Repeat(a1 - a0, Mathf.PI * 2f);
            if (da < 0.3f) da += Mathf.PI * 2f;
            int steps = Mathf.Max(6, Mathf.CeilToInt(da / 0.12f));
            pts.Add(from.p1);
            for (int i = 1; i < steps; i++)
            {
                float a = a0 + da * i / steps;
                pts.Add(Ground(c + new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a)) * r));
            }
            pts.Add(to.p0);
            return pts;
        }
        Vector3 p0 = from.p1, p2 = to.p0;
        Vector3 d0 = from.Dir, d2 = to.Dir;
        if (Vector3.Dot(d0, d2) < -0.9f)                         // U-turn
        {
            Vector3 side = Vector3.Cross(Vector3.up, d0);
            Vector3 mid = (p0 + p2) * 0.5f + d0 * 6f;
            pts.Add(p0); pts.Add(p0 + d0 * 4f); pts.Add(mid); pts.Add(p2 + d0 * 4f); pts.Add(p2);
            return pts;
        }
        // quadratic bezier through the intersection of the two lane lines
        Vector3 ctrl;
        if (Vector3.Dot(d0, d2) > 0.95f) ctrl = (p0 + p2) * 0.5f;
        else
        {
            // intersect p0 + t d0 with p2 - u d2 in xz
            float den = d0.x * (-d2.z) - d0.z * (-d2.x);
            float t = Mathf.Abs(den) < 1e-4f ? Vector3.Distance(p0, p2) * 0.5f : ((p2.x - p0.x) * (-d2.z) - (p2.z - p0.z) * (-d2.x)) / den;
            ctrl = p0 + d0 * t;
        }
        int k = 8;
        for (int i = 0; i <= k; i++)
        {
            float u = i / (float)k;
            Vector3 q = (1 - u) * (1 - u) * p0 + 2 * (1 - u) * u * ctrl + u * u * p2;
            pts.Add(i == 0 || i == k ? q : Ground(q));
        }
        return pts;
    }

    // ---------- junction lock: one car at a time in a junction box (the roundabout lets cars share the ring)
    public bool RequestNode(Node n, TrafficCar c)
    {
        if (n.roundabout) return RingClear(n, c);
        if (n.holder == null || n.holder == c || Time.time > n.holdUntil) { n.holder = c; n.holdUntil = Time.time + 8f; return true; }
        return false;
    }
    public void ReleaseNode(Node n, TrafficCar c) { if (n.holder == c) n.holder = null; }

    bool RingClear(Node n, TrafficCar me)
    {
        Vector3 c = U(n.p);
        foreach (var o in cars)
        {
            if (o == me || !o.InTurn || o.TurnNode != n) continue;
            if (Vector3.Distance(o.transform.position, me.transform.position) < 16f) return false;
        }
        return true;
    }

    /// <summary>true if a person (player / NPC) stands in the car's way</summary>
    public static readonly List<Transform> Pedestrians = new List<Transform>();
    /// <summary>distance along the lane to the nearest person standing in the car's path (float.MaxValue if none)</summary>
    public float PersonDistance(Vector3 pos, Vector3 fwd, float range)
    {
        float best = float.MaxValue;
        Test(player);
        foreach (var p in Pedestrians) Test(p);
        return best;
        void Test(Transform t)
        {
            if (!t) return;
            Vector3 d = t.position - pos; d.y = 0;
            float f = Vector3.Dot(d, fwd); if (f < 0.5f || f > range) return;
            if (Mathf.Abs(Vector3.Dot(d, Vector3.Cross(Vector3.up, fwd))) < 2.0f) best = Mathf.Min(best, f);
        }
    }

    public bool PersonAhead(Vector3 pos, Vector3 fwd, float dist)
    {
        if (player && Ahead(player.position)) return true;
        foreach (var p in Pedestrians) if (p && Ahead(p.position)) return true;
        return false;
        bool Ahead(Vector3 q)
        {
            Vector3 d = q - pos; d.y = 0;
            float f = Vector3.Dot(d, fwd); if (f < 0.5f || f > dist) return false;
            return Mathf.Abs(Vector3.Dot(d, Vector3.Cross(Vector3.up, fwd))) < 2.0f;
        }
    }

    void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.cyan;
        foreach (var e in edges) Gizmos.DrawLine(e.p0 + Vector3.up, e.p1 + Vector3.up);
    }
}
