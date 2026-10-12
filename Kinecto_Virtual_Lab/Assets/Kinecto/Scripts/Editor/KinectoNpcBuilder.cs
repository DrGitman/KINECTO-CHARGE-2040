// Kinecto Virtual Lab: adds the campus NPCs and the Windhoek traffic to the scene.
//   Kinecto > Add NPCs + Traffic   (also called at the end of Kinecto > Build Virtual Lab Scene)
// 1) NPC FBXs (Assets/Kinecto/NPC/Models, Mixamo skeleton, built in Blender) -> Humanoid avatars, URP Lit materials
//    from their stitched textures (Assets/Kinecto/NPC/Textures).
// 2) NavMesh over the campus (NavMeshSurface, physics colliders; sliding door panels and trigger zones ignored so the
//    door gaps stay walkable, the NPCs only walk through once the doors are open).
// 3) 23 NPCs with NavMeshAgent + CampusNpc brain, the student's Animator controller, solid capsule; CampusLife director.
// 4) Traffic: TrafficSystem with the 7 low-poly cars (Assets/Kinecto/Vehicles).
// Base mesh credit: "Low-Poly Male Body" by Ethan Cragun, CC-BY-4.0 (Assets/Kinecto/NPC/CREDITS.txt).
using System.Collections.Generic;
using System.IO;
using System.Linq;
using TMPro;
using Unity.AI.Navigation;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.AI;

public static class KinectoNpcBuilder
{
    const string Dir = "Assets/Kinecto/NPC/";
    const string Veh = "Assets/Kinecto/Vehicles/";
    const string NavPath = "Assets/Kinecto/Scenes/KinectoVirtualLab_NavMesh.asset";

    // name, role, start room (students), station (hub techs), walk speed
    static readonly (string n, CampusNpc.Role r, string room, int st, float v)[] Cast =
    {
        ("NPC_Guard", CampusNpc.Role.Guard, "", 0, 1.2f),
        ("NPC_Lecturer", CampusNpc.Role.Lecturer, "", 0, 1.15f),
        ("NPC_HubDesk", CampusNpc.Role.HubDesk, "", 0, 1.2f),
        ("NPC_HubTech1", CampusNpc.Role.HubTech, "", 0, 1.3f),
        ("NPC_HubTech2", CampusNpc.Role.HubTech, "", 1, 1.3f),
        ("NPC_HubTech3", CampusNpc.Role.HubTech, "", 3, 1.3f),
        ("NPC_S01", CampusNpc.Role.Student, "", 0, 1.45f),
        ("NPC_S02", CampusNpc.Role.Student, "Lecture", 0, 1.35f),
        ("NPC_S04", CampusNpc.Role.Student, "", 0, 1.3f),
        ("NPC_S05", CampusNpc.Role.Student, "Lab", 0, 1.4f),
        ("NPC_S06", CampusNpc.Role.Student, "", 0, 1.5f),
        ("NPC_S07", CampusNpc.Role.Student, "Theatre", 0, 1.25f),
        ("NPC_S08", CampusNpc.Role.Student, "", 0, 1.4f),
        ("NPC_S09", CampusNpc.Role.Student, "Lecture", 0, 1.3f),
        ("NPC_S10", CampusNpc.Role.Student, "", 0, 1.3f),
        ("NPC_S11", CampusNpc.Role.Student, "Lab", 0, 1.35f),
        ("NPC_S12", CampusNpc.Role.Student, "Theatre", 0, 1.25f),
        ("NPC_S13", CampusNpc.Role.Student, "", 0, 1.4f),
        ("NPC_S14", CampusNpc.Role.Student, "Lecture", 0, 1.35f),
        ("NPC_S15", CampusNpc.Role.Student, "", 0, 1.3f),
        ("NPC_S16", CampusNpc.Role.Student, "Theatre", 0, 1.3f),
        ("NPC_S17", CampusNpc.Role.Student, "", 0, 1.3f),
        ("NPC_S18", CampusNpc.Role.Student, "Lab", 0, 1.4f),
    };

    [MenuItem("Kinecto/Add NPCs + Traffic")]
    public static void Menu()
    {
        Debug.Log("[NPC] " + AddToScene());
        var sc = EditorSceneManager.GetActiveScene();
        EditorSceneManager.MarkSceneDirty(sc); EditorSceneManager.SaveScene(sc);
    }

    public static string AddToScene()
    {
        foreach (var n in new[] { "NPCs", "Traffic", "CampusNavMesh" })
        { var g = GameObject.Find(n); if (g) Object.DestroyImmediate(g); }
        string rep = ImportNpcs();
        rep += BakeNavMesh();
        rep += SpawnNpcs();
        rep += BuildTraffic();
        return rep;
    }

    // ------------------------------------------------------------------ 1) import
    public static string ImportNpcs()
    {
        Directory.CreateDirectory(Dir + "Materials");
        int n = 0;
        foreach (var c in Cast)
        {
            string fbx = Dir + "Models/" + c.n + ".fbx";
            var im = AssetImporter.GetAtPath(fbx) as ModelImporter;
            if (!im) continue;
            if (im.animationType != ModelImporterAnimationType.Human || im.materialImportMode != ModelImporterMaterialImportMode.None)
            {
                im.animationType = ModelImporterAnimationType.Human;
                im.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
                im.importAnimation = false; im.importCameras = false; im.importLights = false;
                im.materialImportMode = ModelImporterMaterialImportMode.None;
                im.SaveAndReimport();
            }
            string tex = Dir + "Textures/" + c.n + "_tex.png";
            if (AssetImporter.GetAtPath(tex) is TextureImporter ti && (ti.wrapMode != TextureWrapMode.Clamp || ti.maxTextureSize != 1024))
            {
                ti.sRGBTexture = true; ti.mipmapEnabled = true; ti.wrapMode = TextureWrapMode.Clamp; ti.maxTextureSize = 1024;
                ti.textureCompression = TextureImporterCompression.CompressedHQ; ti.SaveAndReimport();
            }
            Mat(c.n);
            n++;
        }
        foreach (var f in Directory.GetFiles(Veh, "*.fbx"))
        {
            var im = AssetImporter.GetAtPath(f.Replace('\\', '/')) as ModelImporter;
            if (im && (im.importCameras || im.importLights || im.importAnimation)) { im.importCameras = false; im.importLights = false; im.importAnimation = false; im.SaveAndReimport(); }
        }
        return $"{n} NPC models imported; ";
    }

    static Material Mat(string name)
    {
        string p = Dir + "Materials/M_" + name + ".mat";
        var m = AssetDatabase.LoadAssetAtPath<Material>(p);
        if (!m) { m = new Material(Shader.Find("Universal Render Pipeline/Lit")); AssetDatabase.CreateAsset(m, p); }
        m.shader = Shader.Find("Universal Render Pipeline/Lit");
        m.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Dir + "Textures/" + name + "_tex.png"));
        m.SetColor("_BaseColor", Color.white);
        m.SetFloat("_Smoothness", 0.12f); m.SetFloat("_Metallic", 0f);
        EditorUtility.SetDirty(m);
        return m;
    }

    // ------------------------------------------------------------------ 2) NavMesh
    public static string BakeNavMesh()
    {
        // humanoid agent: slimmer than Unity's 0.5 m default so people fit between desks and through door gaps
        var settings = AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/NavMeshAreas.asset").FirstOrDefault();
        if (settings)
        {
            var so = new SerializedObject(settings);
            var r = so.FindProperty("m_Settings.Array.data[0].agentRadius"); if (r != null) r.floatValue = 0.3f;
            var h = so.FindProperty("m_Settings.Array.data[0].agentHeight"); if (h != null) h.floatValue = 1.8f;
            var c = so.FindProperty("m_Settings.Array.data[0].agentClimb"); if (c != null) c.floatValue = 0.35f;
            var s = so.FindProperty("m_Settings.Array.data[0].agentSlope"); if (s != null) s.floatValue = 40f;
            so.ApplyModifiedPropertiesWithoutUndo();
        }
        // door panels, trigger zones and the player must not carve the floor
        int ign = 0;
        foreach (var col in Object.FindObjectsByType<Collider>(FindObjectsInactive.Include, FindObjectsSortMode.None))
        {
            bool ignore = col.isTrigger || col.name.StartsWith("DOOR_") || col is CharacterController || col.GetComponentInParent<CampusNpc>();
            if (!ignore) continue;
            var m = col.GetComponent<NavMeshModifier>(); if (!m) m = col.gameObject.AddComponent<NavMeshModifier>();
            m.ignoreFromBuild = true; m.applyToChildren = col is CharacterController; ign++;
        }
        var go = new GameObject("CampusNavMesh");
        var surf = go.AddComponent<NavMeshSurface>();
        surf.agentTypeID = 0;
        surf.collectObjects = CollectObjects.Volume;
        surf.center = new Vector3(-12f, 8f, -18f); surf.size = new Vector3(215f, 30f, 175f);
        surf.useGeometry = NavMeshCollectGeometry.PhysicsColliders;
        surf.layerMask = ~0;
        surf.BuildNavMesh();
        if (surf.navMeshData)
        {
            AssetDatabase.DeleteAsset(NavPath);
            AssetDatabase.CreateAsset(surf.navMeshData, NavPath);
            AssetDatabase.SaveAssets();
        }
        var tri = NavMesh.CalculateTriangulation();
        return $"navmesh {tri.indices.Length / 3} tris ({ign} colliders ignored); ";
    }

    // ------------------------------------------------------------------ 3) NPCs
    public static string SpawnNpcs()
    {
        var root = new GameObject("NPCs");
        var life = root.AddComponent<CampusLife>();
        var player = GameObject.Find("Player");
        life.player = player ? player.transform : null;
        life.font = AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/Kinecto/UI/Fonts/PlusJakartaSans-Bold SDF.asset");
        // the player is a moving obstacle for the NPCs' local avoidance
        if (player && !player.GetComponent<NavMeshObstacle>())
        {
            var ob = player.AddComponent<NavMeshObstacle>(); ob.shape = NavMeshObstacleShape.Capsule; ob.radius = 0.35f; ob.height = 1.8f;
            ob.center = new Vector3(0f, 0.9f, 0f); ob.carving = false;
        }
        var ctrl = AssetDatabase.LoadAssetAtPath<RuntimeAnimatorController>(KinectoMixamoSetup.ControllerPath);
        int i = 0, made = 0;
        foreach (var c in Cast)
        {
            var asset = AssetDatabase.LoadAssetAtPath<GameObject>(Dir + "Models/" + c.n + ".fbx");
            if (!asset) continue;
            var go = (GameObject)PrefabUtility.InstantiatePrefab(asset, root.transform);
            go.name = c.n;
            // placeholder spot in the courtyard; CampusNpc warps each NPC to its real start at Play
            Vector3 p = new Vector3(-12f + (i % 6) * 4.5f, 0.05f, 30f - (i / 6) * 6f);
            if (NavMesh.SamplePosition(p, out var hit, 4f, NavMesh.AllAreas)) p = hit.position;
            go.transform.position = p; go.transform.rotation = Quaternion.Euler(0f, 180f, 0f);
            var mat = Mat(c.n);
            foreach (var r in go.GetComponentsInChildren<SkinnedMeshRenderer>())
            {
                r.sharedMaterial = mat; r.updateWhenOffscreen = false;
                r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            }
            var anim = go.GetComponent<Animator>(); if (!anim) anim = go.AddComponent<Animator>();
            anim.runtimeAnimatorController = ctrl; anim.applyRootMotion = false;
            anim.cullingMode = AnimatorCullingMode.CullUpdateTransforms;
            var ag = go.AddComponent<NavMeshAgent>();
            ag.radius = 0.28f; ag.height = 1.8f; ag.baseOffset = 0f; ag.speed = c.v;
            var cap = go.AddComponent<CapsuleCollider>(); cap.center = new Vector3(0f, 0.9f, 0f); cap.height = 1.8f; cap.radius = 0.26f;
            var rb = go.AddComponent<Rigidbody>(); rb.isKinematic = true; rb.useGravity = false;
            var npc = go.AddComponent<CampusNpc>();
            npc.role = c.r; npc.startRoom = c.room; npc.station = c.st; npc.walkSpeed = c.v;
            npc.displayName = c.n.Replace("NPC_", "");
            i++; made++;
        }
        return $"{made} NPCs; ";
    }

    // ------------------------------------------------------------------ 4) traffic
    public static string BuildTraffic()
    {
        var cars = Directory.GetFiles(Veh, "*.fbx").Select(f => AssetDatabase.LoadAssetAtPath<GameObject>(f.Replace('\\', '/'))).Where(g => g).ToArray();
        if (cars.Length == 0) return "no cars; ";
        var go = new GameObject("Traffic");
        var ts = go.AddComponent<TrafficSystem>();
        ts.carPrefabs = cars;
        var player = GameObject.Find("Player"); ts.player = player ? player.transform : null;
        var cols = new List<Collider>();
        foreach (var n in new[] { "BG_Roads", "ENV_Ground" })
        { var g = GameObject.Find(n); if (g) cols.AddRange(g.GetComponentsInChildren<Collider>()); }
        ts.groundColliders = cols.ToArray();
        ts.carCount = 40; ts.cruise = 11f;
        return $"traffic with {cars.Length} car models; ";
    }
}
