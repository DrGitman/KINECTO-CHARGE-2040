// Kinecto Virtual Lab: campus life director. Finds the rooms (card reader + sliding doors + the room's floor area),
// the courtyard, the gate, the Hub work stations and the theatre stage at start-up, and hands out valid NavMesh spots
// to the NPCs (CampusNpc): where to stand to tap a reader, just inside / outside each door, seats in each room,
// hang-out spots in the courtyard and the guard's patrol route.
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.AI;

public class CampusLife : MonoBehaviour
{
    public Transform player;
    public TMP_FontAsset font;
    public static CampusLife Instance;

    public class Room
    {
        public string name, key;
        public ReaderStation reader; public SlidingDoor door;
        public Bounds area;                     // where people stand / sit inside
        public Vector3 facing;                  // which way the class faces (front of the room)
        public Vector3 readerStand, outside, inside;
        public readonly List<Vector3> seats = new List<Vector3>();
        public readonly HashSet<int> taken = new HashSet<int>();
        public bool attendance;
    }
    public class Station { public string name; public Vector3 stand, look; }

    public readonly List<Room> rooms = new List<Room>();
    public readonly List<Vector3> yard = new List<Vector3>();
    public readonly List<Vector3> patrol = new List<Vector3>();
    public readonly List<Station> hubStations = new List<Station>();
    public readonly List<Vector3> stage = new List<Vector3>();
    public Vector3 gate, reception, receptionLook;
    public bool Ready { get; private set; }

    static readonly Bounds YardArea = new Bounds(new Vector3(-2f, 0f, 6f), new Vector3(44f, 20f, 92f));

    void Awake()
    {
        Instance = this;
        if (!player) { var p = GameObject.Find("Player"); if (p) player = p.transform; }
    }

    void Start() { Build(); }

    public static bool Snap(Vector3 p, out Vector3 q, float r = 1.5f)
    {
        if (NavMesh.SamplePosition(p, out var hit, r, NavMesh.AllAreas)) { q = hit.position; return true; }
        q = p; return false;
    }

    public static bool Reachable(Vector3 a, Vector3 b)
    {
        var path = new NavMeshPath();
        return NavMesh.CalculatePath(a, b, NavMesh.AllAreas, path) && path.status == NavMeshPathStatus.PathComplete;
    }

    static Bounds? BoundsOf(string name)
    {
        var go = GameObject.Find(name); if (!go) return null;
        var rs = go.GetComponentsInChildren<Renderer>(); if (rs.Length == 0) return null;
        var b = rs[0].bounds; foreach (var r in rs) b.Encapsulate(r.bounds); return b;
    }

    public void Build()
    {
        if (Ready) return;
        // ---------------- gate + courtyard
        Snap(new Vector3(0f, 0.2f, 46f), out gate, 4f);
        var buildings = new List<Bounds>();
        foreach (var n in new[] { "BLD_Lecture", "BLD_Lab", "BLD_Theatre", "BLD_Hub", "BLD_Curvy", "BLD_Portal", "BLD_Right" })
        { var b = BoundsOf(n); if (b.HasValue) { var e = b.Value; e.Expand(new Vector3(1.2f, 0f, 1.2f)); buildings.Add(e); } }
        var rnd = new System.Random(2040);
        for (int i = 0; i < 400 && yard.Count < 60; i++)
        {
            var p = new Vector3(YardArea.min.x + (float)rnd.NextDouble() * YardArea.size.x, 1f, YardArea.min.z + (float)rnd.NextDouble() * YardArea.size.z);
            bool inB = false; foreach (var b in buildings) if (b.Contains(new Vector3(p.x, b.center.y, p.z))) { inB = true; break; }
            if (inB || !Snap(p, out var q, 1.0f) || q.y > 2.5f) continue;
            if (!Reachable(gate, q)) continue;
            bool close = false; foreach (var y in yard) if ((y - q).sqrMagnitude < 4f) { close = true; break; }
            if (!close) yard.Add(q);
        }

        // ---------------- rooms from the card readers
        foreach (var rs in FindObjectsByType<ReaderStation>(FindObjectsSortMode.None))
        {
            if (!rs.doors) continue;
            var r = new Room { name = rs.roomName, reader = rs, door = rs.doors, attendance = rs.attendance };
            string n = rs.name;
            Bounds area; Vector3 face;
            if (n.EndsWith("_Lab")) { r.key = "Lab"; area = BoundsOf("LAB_Interior") ?? new Bounds(); area.Expand(new Vector3(-3f, 0, -2f)); face = Vector3.left; }
            else if (n.EndsWith("_Theatre"))
            {   // raked seating: the tiers themselves are not walkable, people stand on the flat front floor and the stair aisle
                r.key = "Theatre"; var tb = BoundsOf("THEATRE_Interior") ?? new Bounds();
                area = new Bounds(new Vector3((tb.max.x - 5.5f + tb.min.x + 4f) * 0.5f, tb.center.y, tb.center.z), new Vector3(tb.size.x - 9.5f, tb.size.y, tb.size.z - 2.5f));
                face = Vector3.right;
            }
            else if (n.EndsWith("_Hub")) { r.key = "Hub"; area = BoundsOf("HUB_Interior") ?? new Bounds(); area.Expand(new Vector3(-4f, 0, -4f)); face = Vector3.zero; }
            else { r.key = "Lecture"; area = BoundsOf("HALL_Desks") ?? new Bounds(); area.Expand(new Vector3(3f, 0, 3f)); face = Vector3.left; }
            r.area = area; r.facing = face;
            Vector3 mid = r.door.Mid, o = r.door.OutsideDir;
            if (Snap(mid, out var mg, 2.5f)) mid.y = mg.y + 0.1f; else mid.y -= 1.2f;     // floor level in the door gap
            // just inside / outside the doors: step in from 2 m until the point is on the walkable side that connects
            // (some doors open onto a narrow walkway, e.g. the theatre beside the Portal building)
            r.inside = mid - o * 2f;
            foreach (var d in new[] { 2.0f, 1.6f, 1.2f, 0.9f })
                if (Snap(mid - o * d, out var qi, 0.6f)) { r.inside = qi; break; }
            r.outside = mid + o * 1.8f;
            foreach (var d in new[] { 1.8f, 1.4f, 1.1f, 0.8f, 0.6f })
                if (Snap(mid + o * d, out var qo, 0.4f) && Reachable(qo, r.inside) && Reachable(gate, qo)) { r.outside = qo; break; }
            r.readerStand = r.outside;
            foreach (var d in new[] { 0.65f, 0.5f, 0.4f })
                if (Snap(new Vector3(rs.transform.position.x, mid.y, rs.transform.position.z) + o * d, out var qs, 0.4f) && Reachable(qs, r.inside)) { r.readerStand = qs; break; }
            for (int i = 0; i < 300 && r.seats.Count < 28; i++)
            {
                var p = new Vector3(area.min.x + (float)rnd.NextDouble() * area.size.x, mid.y, area.min.z + (float)rnd.NextDouble() * area.size.z);
                Vector3 q = p; bool found = false;
                for (float up = 0f; up <= 6f && !found; up += 0.75f)            // floors, steps and aisles at any height
                    found = Snap(p + Vector3.up * up, out q, 0.5f);
                if (!found || !area.Contains(new Vector3(q.x, area.center.y, q.z))) continue;
                if (!Reachable(r.inside, q)) continue;
                bool close = false; foreach (var s in r.seats) if ((s - q).sqrMagnitude < 1.4f) { close = true; break; }
                if (!close) r.seats.Add(q);
            }
            rooms.Add(r);
        }

        // ---------------- Hub: work stations + reception
        var hub = Get("Hub");
        foreach (var n in new[] { "PROP_HubRepair", "PROP_HubDiagnostic", "PROP_HubArm1", "PROP_HubArm2", "PROP_HubArm3", "SCREEN_Hub_Holo1", "SCREEN_Hub_Holo2", "SCREEN_Hub_Holo3", "SCREEN_Hub_Holo4" })
        {
            var b = BoundsOf(n); if (!b.HasValue) continue;
            var c = b.Value.center; float reach = Mathf.Max(b.Value.extents.x, b.Value.extents.z) + 0.55f;
            float floor = hub != null ? hub.inside.y : 0f;
            // try the four sides at floor level, keep the reachable one closest to the station
            Vector3 best = Vector3.zero; float bd = float.MaxValue;
            foreach (var d in new[] { Vector3.forward, Vector3.back, Vector3.left, Vector3.right })
            {
                var p = c + d * reach; p.y = floor + 0.1f;
                if (!Snap(p, out var q, 1.0f) || q.y > floor + 0.5f) continue;
                if (hub != null && !Reachable(hub.inside, q)) continue;
                float dd = (new Vector3(q.x, c.y, q.z) - c).sqrMagnitude;
                if (dd < bd) { bd = dd; best = q; }
            }
            if (bd < float.MaxValue) hubStations.Add(new Station { name = n, stand = best, look = c });
        }
        if (hub != null)
        {
            Vector3 side = Vector3.Cross(Vector3.up, hub.door.OutsideDir);
            if (!Snap(hub.door.Mid - hub.door.OutsideDir * 4.5f + side * 3f, out reception, 2f)) reception = hub.inside;
            receptionLook = hub.door.Mid;
        }

        // ---------------- theatre stage (lecturer), between the lectern and the whiteboard
        var th = Get("Theatre");
        foreach (var z in new[] { -35f, -37f, -39.5f, -41.5f })
        {
            if (Snap(new Vector3(-29.6f, 0.2f, z), out var q, 1.2f) && (th == null || Reachable(th.inside, q))) stage.Add(q);
        }
        if (stage.Count == 0 && th != null && th.seats.Count > 0) stage.Add(th.seats[0]);

        // ---------------- guard patrol: gate -> lecture entrance -> courtyard -> lab -> theatre -> hub -> courtyard -> gate
        patrol.Add(gate);
        foreach (var k in new[] { "Lecture", "Lab", "Theatre", "Hub" })
        {
            var r = Get(k); if (r == null) continue;
            if (yard.Count > 0) patrol.Add(NearestYard(r.outside + Vector3.right * 6f));
            patrol.Add(r.outside);
        }
        if (yard.Count > 0) patrol.Add(NearestYard(new Vector3(0f, 0f, 10f)));
        Ready = true;
    }

    public Room Get(string key) { foreach (var r in rooms) if (r.key == key) return r; return null; }

    public Vector3 NearestYard(Vector3 p)
    {
        Vector3 best = gate; float bd = float.MaxValue;
        foreach (var y in yard) { float d = (y - p).sqrMagnitude; if (d < bd) { bd = d; best = y; } }
        return best;
    }

    public Vector3 RandomYard(System.Random rnd) => yard.Count > 0 ? yard[rnd.Next(yard.Count)] : gate;

    public int TakeSeat(Room r, System.Random rnd, out Vector3 seat)
    {
        seat = r.inside;
        if (r.seats.Count == 0) return -1;
        for (int i = 0; i < 20; i++)
        {
            int k = rnd.Next(r.seats.Count);
            if (r.taken.Add(k)) { seat = r.seats[k]; return k; }
        }
        seat = r.seats[rnd.Next(r.seats.Count)]; return -1;
    }

    public void FreeSeat(Room r, int k) { if (r != null && k >= 0) r.taken.Remove(k); }

    void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.green; foreach (var y in yard) Gizmos.DrawWireSphere(y, 0.3f);
        foreach (var r in rooms)
        {
            Gizmos.color = Color.cyan; foreach (var s in r.seats) Gizmos.DrawWireSphere(s, 0.25f);
            Gizmos.color = Color.yellow; Gizmos.DrawSphere(r.readerStand, 0.2f); Gizmos.DrawSphere(r.inside, 0.2f); Gizmos.DrawSphere(r.outside, 0.2f);
        }
        Gizmos.color = Color.magenta; foreach (var s in hubStations) Gizmos.DrawLine(s.stand, s.look);
        Gizmos.color = Color.red; for (int i = 0; i + 1 < patrol.Count; i++) Gizmos.DrawLine(patrol[i] + Vector3.up * 0.2f, patrol[i + 1] + Vector3.up * 0.2f);
    }
}
