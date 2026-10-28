// Kinecto Virtual Lab: one campus NPC with a simple "campus life" brain on a NavMeshAgent.
//   Student  : hangs out in the courtyard (faces friends, chats), then goes to a class: taps IN at the card reader,
//              the doors open, walks in, stands at a desk facing the front for a while (taps / types in the lab), taps
//              OUT at the station inside and goes back out.
//   Lecturer : teaches on the theatre stage (paces, gestures, talks to the class), now and then steps out and returns.
//   Guard    : patrols gate -> building entrances -> Hub -> courtyard, looks around at each stop.
//   HubDesk  : reception desk inside the Kinecto Hub, greets people at the door.
//   HubTech  : works at the Hub stations (repair bench, diagnostic bay, robot arms, holo screens).
// Everyone turns to greet the player when they walk up (speech bubble), steps aside (agent avoidance) and is solid.
// Uses the student's Animator controller (Speed blend Idle/Walk/Run, Tap = Mixamo button pushing).
using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.AI;

[RequireComponent(typeof(NavMeshAgent))]
public class CampusNpc : MonoBehaviour
{
    public enum Role { Student, Lecturer, Guard, HubDesk, HubTech }
    public Role role = Role.Student;
    public string displayName = "";
    [Tooltip("Student: start inside this room (Lecture / Lab / Theatre / Hub), empty = courtyard")] public string startRoom = "";
    [Tooltip("HubTech: home station index")] public int station;
    public float walkSpeed = 1.3f;

    public string State { get; private set; } = "start";
    public static readonly List<CampusNpc> All = new List<CampusNpc>();
    /// <summary>freeze every NPC in place (used by the automated play-test so nobody walks through the test door)</summary>
    public static bool Paused;
    public bool Speaking => bubble && bubble.gameObject.activeSelf;

    NavMeshAgent agent; Animator anim; CampusLife life;
    System.Random rnd;
    TextMeshPro bubble; float bubbleUntil, greetAgain, lookUntil;
    Transform lookAtT; Vector3? lookAtP;
    bool idle; float headY = 1.75f;

    static readonly string[] HiStudent = { "Hi!", "Hey!", "Howzit!", "Morning!", "Eita!", "Sharp sharp!", "Hey, nice jacket!", "See you in class" };
    static readonly string[] HiLecturer = { "Good day! Class starts soon.", "Don't forget to tap in at the door.", "Welcome to the theatre." };
    static readonly string[] HiGuard = { "Afternoon! Keep your cuff handy.", "Doors open with a cuff tap.", "All good on campus today." };
    static readonly string[] HiHub = { "Welcome to the Kinecto Hub!", "Need a repair? Use the bench.", "Diagnostic bay is free." };
    static readonly string[] Chat = { "Did you finish the lab?", "My jacket's buffer is full!", "Hub later?", "That lecture was long...", "Knee harvest is up today", "Walk, don't run - more energy!", "Lol", "Same here", "Let's go to class" };
    static readonly string[] Lecture = { "Today: energy harvesting at the knee.", "Who knows the buffer voltage?", "Every step charges the jacket.", "Elbow bends give us micro-joules.", "Remember: tap in for attendance." };

    void Awake()
    {
        agent = GetComponent<NavMeshAgent>();
        anim = GetComponentInChildren<Animator>();
        if (anim) anim.applyRootMotion = false;
    }

    void OnEnable() { All.Add(this); SlidingDoor.Agents.Add(transform); TrafficSystem.Pedestrians.Add(transform); }
    void OnDisable() { All.Remove(this); SlidingDoor.Agents.Remove(transform); TrafficSystem.Pedestrians.Remove(transform); }

    IEnumerator Start()
    {
        rnd = new System.Random(name.GetHashCode() ^ 2040);
        agent.speed = walkSpeed; agent.angularSpeed = 420f; agent.acceleration = 6f; agent.stoppingDistance = 0.15f;
        agent.autoBraking = true; agent.obstacleAvoidanceType = ObstacleAvoidanceType.MedQualityObstacleAvoidance;
        agent.avoidancePriority = role == Role.Student ? 40 + rnd.Next(20) : 30;
        var smr = GetComponentInChildren<SkinnedMeshRenderer>(); if (smr) headY = smr.bounds.max.y - transform.position.y;
        while (CampusLife.Instance == null || !CampusLife.Instance.Ready) yield return null;
        life = CampusLife.Instance;
        MakeBubble();
        yield return null;
        switch (role)
        {
            case Role.Student: StartCoroutine(StudentLoop()); break;
            case Role.Lecturer: StartCoroutine(LecturerLoop()); break;
            case Role.Guard: StartCoroutine(GuardLoop()); break;
            case Role.HubDesk: StartCoroutine(DeskLoop()); break;
            case Role.HubTech: StartCoroutine(TechLoop()); break;
        }
    }

    // ------------------------------------------------------------------ per-frame: animation, facing, greeting, bubble
    void Update()
    {
        if (anim) anim.SetFloat("Speed", agent.enabled ? agent.velocity.magnitude : 0f, 0.12f, Time.deltaTime);
        if (agent.isOnNavMesh && agent.isStopped != Paused) agent.isStopped = Paused;
        bool moving = agent.enabled && agent.velocity.sqrMagnitude > 0.04f;

        // greet the player when they walk up (cool-down per NPC)
        if (life && life.player && Time.time > greetAgain)
        {
            Vector3 d = life.player.position - transform.position; d.y = 0f;
            if (d.magnitude < 2.3f)
            {
                Say(Pick(role switch { Role.Lecturer => HiLecturer, Role.Guard => HiGuard, Role.HubDesk => HiHub, Role.HubTech => HiHub, _ => HiStudent }), 2.8f);
                greetAgain = Time.time + 25f + (float)rnd.NextDouble() * 15f;
                if (!moving) { lookAtT = life.player; lookUntil = Time.time + 3f; }
            }
        }

        // turn on the spot while standing (agent rotation only works while walking)
        Vector3? target = null;
        if (Time.time < lookUntil && lookAtT) target = lookAtT.position;
        else if (lookAtP.HasValue) target = lookAtP.Value;
        if (!moving && target.HasValue)
        {
            Vector3 f = target.Value - transform.position; f.y = 0f;
            if (f.sqrMagnitude > 0.01f)
                transform.rotation = Quaternion.RotateTowards(transform.rotation, Quaternion.LookRotation(f), 300f * Time.deltaTime);
        }
    }

    void LateUpdate()
    {
        if (!bubble) return;
        bool show = Time.time < bubbleUntil;
        var cam = Camera.main;
        if (show && cam && (cam.transform.position - transform.position).sqrMagnitude > 22f * 22f) show = false;
        if (bubble.gameObject.activeSelf != show) bubble.gameObject.SetActive(show);
        if (show && cam)
        {
            bubble.transform.position = transform.position + Vector3.up * (headY + 0.35f);
            bubble.transform.rotation = Quaternion.LookRotation(bubble.transform.position - cam.transform.position);
        }
    }

    void MakeBubble()
    {
        var go = new GameObject("Bubble");
        go.transform.SetParent(transform, false);
        bubble = go.AddComponent<TextMeshPro>();
        if (life && life.font) bubble.font = life.font;
        bubble.fontSize = 1.5f; bubble.alignment = TextAlignmentOptions.Center;
        bubble.rectTransform.sizeDelta = new Vector2(3.2f, 0.6f);
        bubble.color = Color.white; bubble.outlineWidth = 0.25f; bubble.outlineColor = new Color32(10, 25, 50, 255);
        bubble.textWrappingMode = TextWrappingModes.Normal;
        go.SetActive(false);
    }

    public void Say(string text, float seconds = 2.5f) { if (!bubble) return; bubble.text = text; bubbleUntil = Time.time + seconds; }
    string Pick(string[] a) => a[rnd.Next(a.Length)];
    float R(float a, float b) => a + (float)rnd.NextDouble() * (b - a);

    // ------------------------------------------------------------------ movement helpers
    IEnumerator GoTo(Vector3 p, float tol = 0.35f, float timeout = 90f)
    {
        lookAtP = null;
        if (!agent.isOnNavMesh) { if (CampusLife.Snap(transform.position, out var q, 3f)) agent.Warp(q); else yield break; }
        agent.isStopped = false;
        if (!agent.SetDestination(p)) yield break;
        float t0 = Time.time, check = Time.time + 1.5f; Vector3 last = transform.position; int stuck = 0;
        while (true)
        {
            if (!agent.pathPending)
            {
                if (agent.pathStatus == NavMeshPathStatus.PathInvalid) break;
                if (agent.remainingDistance <= Mathf.Max(tol, agent.stoppingDistance)) break;
            }
            if (Time.time > check)
            {
                check = Time.time + 1.5f;
                if ((transform.position - last).sqrMagnitude < 0.04f) { if (++stuck >= 4) break; agent.SetDestination(p); } else stuck = 0;
                last = transform.position;
            }
            if (Time.time - t0 > timeout) break;
            yield return null;
        }
        agent.ResetPath();
    }

    IEnumerator Face(Vector3 p, float seconds = 0.5f)
    {
        lookAtP = p;
        yield return new WaitForSeconds(seconds);
    }

    IEnumerator Idle(float seconds, Vector3? look = null)
    {
        State = "idle"; lookAtP = look;
        yield return new WaitForSeconds(seconds);
    }

    IEnumerator Tap(float hold = 1.6f)
    {
        if (anim) { anim.ResetTrigger("Tap"); anim.SetTrigger("Tap"); }
        yield return new WaitForSeconds(hold);
    }

    IEnumerator WaitOpen(SlidingDoor d, float max)
    {
        float t = 0f;
        while (d && !d.IsOpen && t < max) { t += Time.deltaTime; yield return null; }
    }

    /// <summary>tap the card reader, the doors slide open, walk in</summary>
    IEnumerator Enter(CampusLife.Room r)
    {
        State = "to " + r.key;
        yield return GoTo(r.readerStand, 0.3f);
        yield return Face(r.reader.transform.position, 0.35f);
        State = "tap " + r.key;
        if (anim) { anim.ResetTrigger("Tap"); anim.SetTrigger("Tap"); }
        yield return new WaitForSeconds(0.9f);
        while (Paused) yield return null;
        r.door.Open(6f);                         // NPC cards are simulated: no attendance row is written for them
        yield return WaitOpen(r.door, 2.5f);
        yield return new WaitForSeconds(0.4f);
        yield return GoTo(r.inside, 0.5f);
    }

    /// <summary>leave a room: tap out at the station inside (classrooms), the doors open, walk out.
    /// Rooms without a tap-out station (the Hub) use the exit sensor.</summary>
    IEnumerator Exit(CampusLife.Room r)
    {
        State = "leaving " + r.key;
        if (r.tapOut)
        {
            yield return GoTo(r.tapOutStand, 0.3f);
            yield return Face(r.tapOut.transform.position, 0.35f);
            State = "tap out " + r.key;
            if (anim) { anim.ResetTrigger("Tap"); anim.SetTrigger("Tap"); }
            yield return new WaitForSeconds(0.9f);
            while (Paused) yield return null;
            r.door.Open(6f);                     // simulated NPC tap-out: opens the doors, writes no attendance row
            yield return WaitOpen(r.door, 2.5f);
            State = "leaving " + r.key;
        }
        else
        {
            yield return GoTo(r.inside, 0.5f);
            yield return WaitOpen(r.door, 3f);
        }
        yield return GoTo(r.outside, 0.5f);
    }

    CampusNpc Friend(float within)
    {
        CampusNpc best = null; float bd = within * within;
        foreach (var o in All)
        {
            if (o == this || !o.idleInYard) continue;
            float d = (o.transform.position - transform.position).sqrMagnitude;
            if (d < bd) { bd = d; best = o; }
        }
        return best;
    }
    bool idleInYard;

    // ------------------------------------------------------------------ roles
    IEnumerator StudentLoop()
    {
        CampusLife.Room cur = string.IsNullOrEmpty(startRoom) ? null : life.Get(startRoom);
        if (cur != null)
        {
            int k = life.TakeSeat(cur, rnd, out var seat);
            agent.Warp(seat);
            yield return InClass(cur, k, R(15f, 70f));
        }
        else if (life.yard.Count > 0) agent.Warp(life.RandomYard(rnd));

        while (true)
        {
            int hangs = 1 + rnd.Next(3);
            for (int i = 0; i < hangs; i++)
            {
                State = "courtyard";
                // join a friend now and then, otherwise a random spot
                var f = rnd.NextDouble() < 0.45 ? Friend(25f) : null;
                Vector3 dest = f ? f.transform.position + (transform.position - f.transform.position).normalized * 1.3f : life.RandomYard(rnd);
                if (CampusLife.Snap(dest, out var q, 1.5f)) dest = q;
                yield return GoTo(dest, 0.4f);
                idleInYard = true;
                float stay = R(6f, 20f), t = 0f;
                while (t < stay)
                {
                    var fr = Friend(3.2f);
                    lookAtP = fr ? fr.transform.position : (Vector3?)null;
                    if (fr && rnd.NextDouble() < 0.25) Say(Pick(Chat), 2.5f);
                    float step = R(2.5f, 5f); t += step;
                    yield return new WaitForSeconds(step);
                }
                idleInYard = false;
            }
            // go to class: lecture hall 40 %, lab 30 %, theatre 25 %, Hub 5 %
            double x = rnd.NextDouble();
            var room = life.Get(x < 0.4 ? "Lecture" : x < 0.7 ? "Lab" : x < 0.95 ? "Theatre" : "Hub") ?? life.Get("Lecture");
            if (room == null) { yield return Idle(5f); continue; }
            yield return Enter(room);
            int seatK = life.TakeSeat(room, rnd, out var s);
            yield return GoTo(s, 0.3f);
            yield return InClass(room, seatK, R(30f, 90f));
        }
    }

    IEnumerator InClass(CampusLife.Room r, int seatK, float seconds)
    {
        State = "in " + r.key;
        Vector3 front = r.facing == Vector3.zero ? r.door.Mid : transform.position + r.facing * 5f;
        lookAtP = front;
        float t = 0f;
        while (t < seconds)
        {
            float step = R(4f, 9f); t += step;
            if (r.key == "Lab" && rnd.NextDouble() < 0.6) { yield return Tap(1.8f); step -= 1.8f; }   // typing / pressing buttons
            else if (rnd.NextDouble() < 0.12) Say(Pick(Chat), 2f);
            yield return new WaitForSeconds(Mathf.Max(0.5f, step));
        }
        life.FreeSeat(r, seatK);
        yield return Exit(r);
    }

    IEnumerator LecturerLoop()
    {
        var th = life.Get("Theatre");
        if (th == null || life.stage.Count == 0) { yield return GuardLoop(); yield break; }
        agent.Warp(life.stage[0]);
        float nextBreak = Time.time + R(150f, 240f);
        while (true)
        {
            State = "teaching";
            var spot = life.stage[rnd.Next(life.stage.Count)];
            yield return GoTo(spot, 0.25f);
            Vector3 audience = spot + Vector3.left * 6f;
            lookAtP = audience;
            float stay = R(5f, 11f);
            if (rnd.NextDouble() < 0.4) { yield return Tap(1.6f); stay -= 1.6f; }      // gesture at the board
            if (rnd.NextDouble() < 0.5) Say(Pick(Lecture), 3.2f);
            yield return new WaitForSeconds(Mathf.Max(1f, stay));
            if (Time.time > nextBreak)
            {
                // short break: walk out, stand in the courtyard, come back in through the reader
                yield return Exit(th);
                State = "break";
                yield return GoTo(life.NearestYard(th.outside + Vector3.right * 10f), 0.5f);
                yield return Idle(R(12f, 25f));
                yield return Enter(th);
                nextBreak = Time.time + R(150f, 240f);
            }
        }
    }

    IEnumerator GuardLoop()
    {
        if (life.patrol.Count == 0) { yield return Idle(9999f); yield break; }
        agent.Warp(life.patrol[0]);
        int i = 0;
        while (true)
        {
            State = "patrol";
            var p = life.patrol[i];
            yield return GoTo(p, 0.6f);
            bool atGate = i == 0;
            float stay = atGate ? R(10f, 18f) : R(3f, 7f), t = 0f;
            while (t < stay)
            {
                // look around
                float a = R(0f, 360f);
                lookAtP = transform.position + Quaternion.Euler(0f, a, 0f) * Vector3.forward * 4f;
                float step = R(1.8f, 3.5f); t += step;
                yield return new WaitForSeconds(step);
            }
            i = (i + 1) % life.patrol.Count;
        }
    }

    IEnumerator DeskLoop()
    {
        agent.Warp(life.reception);
        while (true)
        {
            State = "reception";
            yield return GoTo(life.reception, 0.25f);
            lookAtP = life.receptionLook;
            int n = 2 + rnd.Next(3);
            for (int k = 0; k < n; k++)
            {
                if (rnd.NextDouble() < 0.55) yield return Tap(1.8f);            // typing at the desk
                yield return new WaitForSeconds(R(3f, 7f));
            }
            if (life.hubStations.Count > 0 && rnd.NextDouble() < 0.35)
            {
                var s = life.hubStations[rnd.Next(life.hubStations.Count)];
                State = "checking " + s.name;
                yield return GoTo(s.stand, 0.3f);
                yield return Face(s.look, 0.4f);
                yield return Tap(1.8f);
                yield return Idle(R(2f, 5f), s.look);
            }
        }
    }

    IEnumerator TechLoop()
    {
        var st = life.hubStations;
        if (st.Count == 0) { yield return Idle(9999f); yield break; }
        int home = Mathf.Clamp(station, 0, st.Count - 1);
        agent.Warp(st[home].stand);
        while (true)
        {
            var s = rnd.NextDouble() < 0.65 ? st[home] : st[rnd.Next(st.Count)];
            State = "working " + s.name;
            yield return GoTo(s.stand, 0.3f);
            yield return Face(s.look, 0.4f);
            float work = R(10f, 24f), t = 0f;
            while (t < work)
            {
                yield return Tap(1.8f);                                       // pressing buttons / repairing
                float pause = R(1.5f, 4f); t += 1.8f + pause;
                lookAtP = s.look;
                yield return new WaitForSeconds(pause);
            }
            yield return Idle(R(2f, 5f), s.look);
        }
    }
}
