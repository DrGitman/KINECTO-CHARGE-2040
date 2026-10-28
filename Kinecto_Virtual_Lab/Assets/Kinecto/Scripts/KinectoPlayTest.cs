// Kinecto Virtual Lab: automated play-test. Drives the real controller through LabInput's test hooks (same code path
// as the keyboard) and checks walk / run / jump / gravity / collision / door scan + attendance / walk in / doors close /
// exit sensor / fall-through recovery. Results go to the console and Temp/kinecto_playtest.txt; screenshots to
// Assets/Screenshots/PlayTest_*.png. Start it from the menu Kinecto > Run Play-Test (enters Play mode), or add the
// component to any object while playing.
using System.Collections;
using System.Text;
using UnityEngine;

public class KinectoPlayTest : MonoBehaviour
{
    public static string Report = "";
    public static bool Done;
    StringBuilder sb = new StringBuilder();
    KinectoLabController lab; CharacterController cc; Kinecto.KinectoCamera cam;
    int pass, fail;

    void Check(string name, bool ok, string detail)
    {
        if (ok) pass++; else fail++;
        sb.AppendLine((ok ? "PASS  " : "FAIL  ") + name + "  —  " + detail);
    }

    void Shot(string n) { System.IO.Directory.CreateDirectory("Assets/Screenshots"); ScreenCapture.CaptureScreenshot("Assets/Screenshots/PlayTest_" + n + ".png"); }

    Vector2 AxisFor(Vector3 worldDir)
    {
        Transform c = lab.cameraPivot ? lab.cameraPivot : Camera.main.transform;
        Vector3 f = c.forward; f.y = 0; f.Normalize(); Vector3 r = c.right; r.y = 0; r.Normalize();
        worldDir.y = 0; worldDir.Normalize();
        return new Vector2(Vector3.Dot(worldDir, r), Vector3.Dot(worldDir, f));
    }

    IEnumerator Hold(Vector3 worldDir, float seconds, bool run = false)
    {
        LabInput.SimRun = run;
        for (float t = 0; t < seconds; t += Time.deltaTime) { LabInput.SimAxis = AxisFor(worldDir); yield return null; }
        LabInput.SimAxis = Vector2.zero; LabInput.SimRun = false;
    }

    IEnumerator WalkTo(Vector3 target, float maxSeconds)
    {
        for (float t = 0; t < maxSeconds; t += Time.deltaTime)
        {
            Vector3 d = target - cc.transform.position; d.y = 0;
            if (d.magnitude < 0.25f) break;
            LabInput.SimAxis = AxisFor(d) * Mathf.Clamp01(d.magnitude * 2f);
            yield return null;
        }
        LabInput.SimAxis = Vector2.zero;
    }

    void Place(Vector3 p, Vector3 face)
    {
        cc.enabled = false; cc.transform.position = p; face.y = 0; cc.transform.rotation = Quaternion.LookRotation(face.normalized); cc.enabled = true;
    }

    string State()
    {
        var s = lab.avatar.GetCurrentAnimatorStateInfo(0);
        foreach (var n in new[] { "Locomotion", "Scan", "JumpUp", "Fall", "Land" }) if (s.IsName(n)) return n;
        return "?";
    }

    IEnumerator Start()
    {
        Done = false;
        yield return new WaitForSeconds(1.0f);
        lab = FindFirstObjectByType<KinectoLabController>(); cc = lab.mover; cam = FindFirstObjectByType<Kinecto.KinectoCamera>();
        if (cam) cam.lookLocked = true;                                   // the real mouse must not steer the test
        sb.AppendLine("Kinecto play-test  " + System.DateTime.Now);
        CampusNpc.Paused = true;                                          // nobody else walks through the test doors

        // 0) gravity: spawned standing on the ground
        yield return new WaitForSeconds(0.5f);
        Check("Gravity / spawn on ground", lab.Grounded && Mathf.Abs(cc.transform.position.y) < 0.3f, $"grounded={lab.Grounded} y={cc.transform.position.y:0.00}");

        // open courtyard test lane (east of the lecture building, walking +x)
        Vector3 lane = new Vector3(-12f, 0.1f, 25f);
        Place(lane, Vector3.right); yield return new WaitForSeconds(0.4f);
        Check("Idle animation", State() == "Locomotion" && lab.avatar.GetFloat("Speed") < 0.1f, $"state={State()} speed={lab.avatar.GetFloat("Speed"):0.00}");

        // 1) walk
        Vector3 a = cc.transform.position; yield return Hold(Vector3.right, 0.6f);
        a = cc.transform.position; float t0 = Time.time;
        yield return Hold(Vector3.right, 1.5f);
        float walkV = Vector3.Distance(Flat(a), Flat(cc.transform.position)) / (Time.time - t0);
        Shot("1_walk");
        Check("Walk speed ~1.4 m/s", Mathf.Abs(walkV - 1.4f) < 0.25f, $"{walkV:0.00} m/s, anim Speed={lab.avatar.GetFloat("Speed"):0.00}, activity={lab.CurrentActivity}");
        yield return new WaitForSeconds(0.8f);
        Check("Smooth stop back to idle", lab.LiveSpeed < 0.1f, $"speed after release={lab.LiveSpeed:0.00}");

        // 2) run
        Place(lane, Vector3.right); yield return new WaitForSeconds(0.3f);
        yield return Hold(Vector3.right, 0.8f, true);
        a = cc.transform.position; t0 = Time.time;
        LabInput.SimRun = true;
        for (float t = 0; t < 1.2f; t += Time.deltaTime) { LabInput.SimAxis = AxisFor(Vector3.right); LabInput.SimRun = true; yield return null; }
        float runV = Vector3.Distance(Flat(a), Flat(cc.transform.position)) / (Time.time - t0);
        Shot("2_run");
        LabInput.SimAxis = Vector2.zero; LabInput.SimRun = false;
        Check("Run speed ~3.2 m/s", Mathf.Abs(runV - 3.2f) < 0.4f, $"{runV:0.00} m/s, activity={lab.CurrentActivity}");
        yield return new WaitForSeconds(1.0f);

        // 3) jump
        Place(lane, Vector3.right); yield return new WaitForSeconds(0.5f);
        float y0 = cc.transform.position.y, ymax = y0; bool sawUp = false, sawFall = false, sawLand = false;
        double jumpJ0 = lab.gait.SourceJ[5];
        LabInput.SimJump();
        bool shotTaken = false;
        for (float t = 0; t < 1.6f; t += Time.deltaTime)
        {
            ymax = Mathf.Max(ymax, cc.transform.position.y);
            var s = State(); sawUp |= s == "JumpUp"; sawFall |= s == "Fall"; sawLand |= s == "Land";
            if (!shotTaken && cc.transform.position.y - y0 > 0.4f) { Shot("3_jump"); shotTaken = true; }
            yield return null;
        }
        Check("Jump height ~0.55 m", Mathf.Abs((ymax - y0) - 0.55f) < 0.12f, $"apex {ymax - y0:0.00} m");
        Check("Jump animations (take-off, air, landing)", sawUp && (sawFall || sawLand) && sawLand, $"JumpUp={sawUp} Fall={sawFall} Land={sawLand}");
        Check("Lands back on the ground", lab.Grounded && Mathf.Abs(cc.transform.position.y - y0) < 0.1f, $"grounded={lab.Grounded} y={cc.transform.position.y:0.00}");
        Check("Jump makes energy", lab.gait.SourceJ[5] > jumpJ0, $"+{(lab.gait.SourceJ[5] - jumpJ0) * 1e6:0.00} µJ jump impact");
        yield return new WaitForSeconds(0.6f);

        // 4) collision with the lecture-hall glass facade (and doors closed)
        var door = GameObject.Find("Doors_Entrance").GetComponent<SlidingDoor>();
        Vector3 mid = (door.left.position + door.right.position) * 0.5f; mid.y = 0.1f;
        Vector3 along = door.left.position - door.right.position; along.y = 0; along.Normalize();
        Vector3 n = Vector3.Cross(along, Vector3.up); if (Vector3.Dot(door.reader.position - mid, n) < 0) n = -n;   // n -> outside
        Place(mid + n * 2.5f + along * 3.5f, -n); yield return new WaitForSeconds(0.3f);
        Vector3 before = cc.transform.position;
        yield return Hold(-n, 3f);
        float pen = Vector3.Dot(cc.transform.position - mid, -n);
        Check("Glass wall blocks the player", pen < 0f, $"stopped {-pen:0.00} m outside the facade (walked {Vector3.Distance(Flat(before), Flat(cc.transform.position)):0.0} m)");
        Place(mid + n * 2.0f, -n); yield return new WaitForSeconds(0.3f);
        yield return Hold(-n, 2f);
        Check("Closed door blocks the player", Vector3.Dot(cc.transform.position - mid, -n) < 0f && !door.IsOpen, $"door open={door.IsOpen}");

        // 5) scan at the reader -> attendance + doors open
        var reader = door.reader.GetComponent<CuffTapReader>();
        int logs = reader.log.Count;
        Vector3 rp = door.reader.position; rp.y = 0.1f;
        Place(rp + n * 0.9f, -n); yield return new WaitForSeconds(0.4f);
        LabInput.SimTap();
        bool sawScan = false; float openAt = -1f;
        for (float t = 0; t < 2.5f; t += Time.deltaTime) { sawScan |= State() == "Scan"; if (openAt < 0 && door.IsOpen) { openAt = t; Shot("5_scan_doors_open"); } yield return null; }
        string last = reader.log.Count > logs ? reader.log[reader.log.Count - 1] : "(none)";
        Check("Cuff scan logs attendance", reader.log.Count > logs, last);
        Check("Scan animation plays", sawScan, "state Scan seen");
        Check("Doors slide open after the scan", openAt >= 0, $"open after {openAt:0.0} s");

        // 6) walk in through the doorway
        yield return WalkTo(mid + n * 0.6f, 3f);
        yield return Hold(-n, 1.8f);
        float inside = Vector3.Dot(cc.transform.position - mid, -n);
        Shot("6_inside");
        Check("Walk in through the open doors", inside > 0.8f, $"{inside:0.00} m inside");
        yield return Hold(-n, 1.5f);
        yield return new WaitForSeconds(3.5f);
        Check("Doors close behind you", !door.IsOpen, $"door open={door.IsOpen} ({Vector3.Distance(Flat(cc.transform.position), Flat(mid)):0.0} m away)");

        // 7) leaving: no free exit sensor in classrooms - walking up to the doors from inside keeps them shut,
        //    tapping out at the station inside logs OUT and opens them
        yield return WalkTo(mid - n * 1.0f, 4f);
        yield return Hold(n, 1.2f);
        Check("No free exit: doors stay shut from inside", !door.IsOpen && Vector3.Dot(cc.transform.position - mid, n) < 0f, $"door open={door.IsOpen}");
        ReaderStation outSt = null;
        foreach (var s2 in FindObjectsByType<ReaderStation>(FindObjectsSortMode.None)) if (s2.IsTapOut && s2.doors == door) outSt = s2;
        if (outSt)
        {
            var outReader = outSt.reader; int ol = outReader.log.Count;
            Vector3 sp = outSt.transform.position; sp.y = 0.1f;
            Place(sp - n * 0.9f, n); yield return new WaitForSeconds(0.4f);
            Check("Tap-out station inside the classroom", ReaderStation.Nearest == outSt, ReaderStation.Nearest ? ReaderStation.Nearest.name + " · " + ReaderStation.Nearest.Prompt : "no station in reach");
            LabInput.SimTap();
            float oAt = -1f;
            for (float t = 0; t < 2.5f; t += Time.deltaTime) { if (oAt < 0 && door.IsOpen) { oAt = t; Shot("7_tap_out"); } yield return null; }
            string outLast = outReader.log.Count > ol ? outReader.log[outReader.log.Count - 1] : "(none)";
            Check("Tap out logs OUT (after the tap-in)", outReader.log.Count > ol && outLast.Contains(" OUT") && !outLast.Contains("no tap-in"), outLast);
            Check("Doors slide open after the tap-out", oAt >= 0, $"open after {oAt:0.0} s");
            yield return WalkTo(mid - n * 0.6f, 3f);
            for (float t = 0; t < 3f && Vector3.Dot(cc.transform.position - mid, n) < 1.2f; t += Time.deltaTime) { LabInput.SimAxis = AxisFor(n); yield return null; }
            LabInput.SimAxis = Vector2.zero;
            Check("Walk out after tapping out", Vector3.Dot(cc.transform.position - mid, n) > 0.5f, $"now {Vector3.Dot(cc.transform.position - mid, n):0.00} m outside");
        }
        else Check("Tap-out station inside the classroom", false, "missing");
        yield return Hold(n, 1.2f);
        yield return new WaitForSeconds(3f);
        Check("Doors close after walking out", !door.IsOpen, $"door open={door.IsOpen}");

        // 8) fall-through safety
        Place(lane, Vector3.right); yield return new WaitForSeconds(0.5f);
        cc.enabled = false; cc.transform.position = new Vector3(lane.x, -30f, lane.z); cc.enabled = true;
        yield return new WaitForSeconds(0.5f);
        Check("Recovers if it ever falls below the world", cc.transform.position.y > -1f, $"y={cc.transform.position.y:0.00}");

        // 9) HUD alive
        var hud = FindFirstObjectByType<LabHud>();
        Check("HUD running", hud && hud.isActiveAndEnabled, "LabHud active");
        Check("Energy counting", lab.harvest.harvestedJ > 0, $"{lab.harvest.harvestedJ * 1e3:0.000} mJ today");

        // 10) campus NPCs + traffic (the NPCs were frozen for the door checks above)
        CampusNpc.Paused = false;
        Place(lane, Vector3.right);
        var npcs = FindObjectsByType<CampusNpc>(FindObjectsSortMode.None);
        int onNav = 0; foreach (var n2 in npcs) if (n2.GetComponent<UnityEngine.AI.NavMeshAgent>().isOnNavMesh) onNav++;
        Check("NPCs on the NavMesh", npcs.Length >= 20 && onNav == npcs.Length, $"{onNav}/{npcs.Length} agents on the NavMesh");
        var npcStart = new Vector3[npcs.Length]; for (int k = 0; k < npcs.Length; k++) npcStart[k] = npcs[k].transform.position;
        yield return new WaitForSeconds(8f);
        int movedN = 0; for (int k = 0; k < npcs.Length; k++) if (Vector3.Distance(npcStart[k], npcs[k].transform.position) > 1f) movedN++;
        Check("NPCs walk around campus", movedN >= 5, $"{movedN} of {npcs.Length} moved more than 1 m in 8 s");
        string roles = ""; bool lect = false, guard = false, tech = false, cls = false;
        foreach (var n2 in npcs)
        {
            if (n2.role == CampusNpc.Role.Lecturer) { lect = n2.State == "teaching" || n2.State.Contains("Theatre") || n2.State == "break"; roles += "lecturer " + n2.State + "; "; }
            if (n2.role == CampusNpc.Role.Guard) { guard = n2.State == "patrol"; roles += "guard " + n2.State + "; "; }
            if (n2.role == CampusNpc.Role.HubTech && n2.State.StartsWith("working")) tech = true;
            if (n2.role == CampusNpc.Role.Student && (n2.State.StartsWith("in ") || n2.State.StartsWith("tap") || n2.State.StartsWith("to ") || n2.State.StartsWith("leaving"))) cls = true;
        }
        Check("Campus roles (lecturer, guard, Hub staff, students in class)", lect && guard && tech && cls, roles + $"hub working={tech}, class={cls}");
        bool said = false; string who = "";
        foreach (var n2 in npcs)
        {
            if (said) break;
            if (n2.role != CampusNpc.Role.Student || n2.State != "courtyard") continue;
            Vector3 gp = n2.transform.position + n2.transform.forward * 1.6f;
            if (UnityEngine.AI.NavMesh.SamplePosition(gp, out var gh, 1f, UnityEngine.AI.NavMesh.AllAreas)) gp = gh.position;
            Place(gp + Vector3.up * 0.05f, n2.transform.position - gp);
            for (float t = 0; t < 1.5f && !said; t += Time.deltaTime) { said |= n2.Speaking; yield return null; }
            who = n2.name;
        }
        Check("NPC greets the player", said, who);
        var ts = FindFirstObjectByType<TrafficSystem>();
        if (ts)
        {
            var p0 = new Vector3[ts.cars.Count]; for (int k = 0; k < p0.Length; k++) p0[k] = ts.cars[k].transform.position;
            yield return new WaitForSeconds(3f);
            float sum = 0f; for (int k = 0; k < p0.Length; k++) sum += Vector3.Distance(p0[k], ts.cars[k].transform.position) / 3f;
            float mean = p0.Length > 0 ? sum / p0.Length : 0f;
            Check("Traffic drives on the roads", ts.cars.Count >= 30 && mean > 3f, $"{ts.cars.Count} cars, mean speed {mean:0.0} m/s");
            // stand in a lane: the car coming towards you stops in front of you
            bool stopped = false; string det = "no car";
            for (int tries = 0; tries < 5 && !stopped; tries++)
            {
                TrafficCar car = null;
                foreach (var c in ts.cars) if (!c.InTurn && c.s < 20f) { car = c; break; }
                if (!car) { yield return new WaitForSeconds(1f); continue; }
                Vector3 f = car.transform.forward; f.y = 0f; f.Normalize();
                Vector3 spot = car.transform.position + f * 24f; spot.y = car.transform.position.y + 0.1f;
                Place(spot, -f);
                yield return new WaitForSeconds(4f);
                Vector3 c0 = car.transform.position; yield return new WaitForSeconds(1f);
                float dv = Vector3.Distance(c0, car.transform.position);
                float gap = Vector3.Distance(Flat(car.transform.position), Flat(cc.transform.position));
                det = $"{car.name}: moved {dv:0.00} m in 1 s, {gap:0.0} m from you";
                stopped = dv < 0.3f && gap > 2f && gap < 22f;
            }
            Check("Cars stop for a person on the road", stopped, det);
            Place(lane, Vector3.right); yield return new WaitForSeconds(0.5f);
        }

        if (cam) cam.lookLocked = false;
        sb.AppendLine($"\n{pass} passed, {fail} failed");
        Report = sb.ToString(); Done = true;
        Debug.Log(Report);
        System.IO.File.WriteAllText("Temp/kinecto_playtest.txt", Report);
    }

    void OnDestroy() { CampusNpc.Paused = false; }

    static Vector3 Flat(Vector3 v) => new Vector3(v.x, 0, v.z);
}
