// Kinecto Virtual Lab: one-click scene builder (menu Kinecto > Build Virtual Lab Scene).
// Makes the URP materials for the campus + character FBX, places the NUST campus with Windhoek around it, adds
// colliders, the player (character + cuff tag), the third-person camera, the sun on the lab clock, the three card
// readers with sliding doors, shade zones, the simulation modules and the HUD, then saves the scene.
using System.Collections.Generic;
using System.IO;
using System.Linq;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public static class KinectoSceneBuilder
{
    const string Env = "Assets/Kinecto/Environment/";
    const string Chr = "Assets/Kinecto/Character/";
    const string Mat = "Assets/Kinecto/Materials/";
    const string UI = "Assets/Kinecto/UI/";
    const string ScenePath = "Assets/Kinecto/Scenes/KinectoVirtualLab.unity";

    [MenuItem("Kinecto/Build Virtual Lab Scene")]
    public static void Build()
    {
        EnsureTag("CuffTag");
        Directory.CreateDirectory(Mat);
        SetupTextures();
        RemapCampusMaterials();
        bool mixamo = KinectoMixamoSetup.Available;
        if (mixamo) Debug.Log("Mixamo: " + KinectoMixamoSetup.Setup());
        RemapCharacterMaterials(Chr + "KinectoStudent_full_unrigged.fbx");
        if (mixamo) RemapCharacterMaterials(KinectoMixamoSetup.CharacterFbx);
        BuildScene();
    }

    // ------------------------------------------------------------------ textures + materials
    static void Tex(string path, bool srgb, FilterMode filter, bool alpha = false)
    {
        var ti = AssetImporter.GetAtPath(path) as TextureImporter;
        if (!ti) { Debug.LogWarning("missing " + path); return; }
        ti.sRGBTexture = srgb; ti.filterMode = filter; ti.mipmapEnabled = filter != FilterMode.Point;
        ti.textureCompression = TextureImporterCompression.Uncompressed; ti.alphaIsTransparency = alpha; ti.wrapMode = TextureWrapMode.Clamp;
        ti.SaveAndReimport();
    }

    static void SetupTextures()
    {
        Tex(Env + "tex/T_CampusPalette_BaseColor.png", true, FilterMode.Point);
        Tex(Env + "tex/T_CampusPalette_MaskMap.png", false, FilterMode.Point);
        Tex(Env + "tex/T_CampusPalette_Emission.png", true, FilterMode.Point);
        foreach (var f in Directory.GetFiles(Env + "tex", "*.png"))
        {
            string n = Path.GetFileNameWithoutExtension(f);
            if (!n.StartsWith("T_CampusPalette")) Tex(Env + "tex/" + n + ".png", true, FilterMode.Bilinear, true);
        }
        Tex(Chr + "T_StudentPalette.png", true, FilterMode.Point);
        Tex(Chr + "T_Decal_Chest.png", true, FilterMode.Bilinear, true);
        Tex(Chr + "T_Decal_Back.png", true, FilterMode.Bilinear, true);
    }

    static readonly string[] Decals = { "T_Banner_NUST", "T_CardSticker", "T_Clock", "T_Dashboard", "T_Logo_NUST", "T_Sign_NUST_Facade", "T_Sign_NUST_Navy", "T_Whiteboard" };

    static Material Lit(string name)
    {
        string p = Mat + name + ".mat";
        var m = AssetDatabase.LoadAssetAtPath<Material>(p);
        if (!m) { m = new Material(Shader.Find("Universal Render Pipeline/Lit")); AssetDatabase.CreateAsset(m, p); }
        m.shader = Shader.Find("Universal Render Pipeline/Lit");
        return m;
    }

    static void AlphaClip(Material m, bool on, bool twoSided)
    {
        m.SetFloat("_AlphaClip", on ? 1 : 0); m.SetFloat("_Cutoff", 0.5f);
        if (on) m.EnableKeyword("_ALPHATEST_ON"); else m.DisableKeyword("_ALPHATEST_ON");
        m.SetFloat("_Cull", twoSided ? 0 : 2);
        m.renderQueue = on ? (int)RenderQueue.AlphaTest : -1;
    }

    static Material PaletteMaterial()
    {
        var m = Lit("M_CampusPalette");
        m.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Env + "tex/T_CampusPalette_BaseColor.png"));
        m.SetColor("_BaseColor", Color.white);
        m.SetTexture("_MetallicGlossMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Env + "tex/T_CampusPalette_MaskMap.png"));
        m.EnableKeyword("_METALLICSPECGLOSSMAP");
        m.SetFloat("_Smoothness", 1f); m.SetFloat("_SmoothnessTextureChannel", 0);
        m.SetTexture("_EmissionMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Env + "tex/T_CampusPalette_Emission.png"));
        m.SetColor("_EmissionColor", Color.white); m.EnableKeyword("_EMISSION");
        m.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
        EditorUtility.SetDirty(m);
        return m;
    }

    static void RemapCampusMaterials()
    {
        string fbx = Env + "NUST_Campus.fbx";
        var imp = (ModelImporter)AssetImporter.GetAtPath(fbx);
        var pal = PaletteMaterial();
        foreach (var o in AssetDatabase.LoadAllAssetsAtPath(fbx))
        {
            if (!(o is Material src)) continue;
            Material dst = pal;
            if (src.name.StartsWith("M_T_"))
            {
                string tex = src.name.Substring(2);
                dst = Lit("M_Decal_" + tex.Substring(2));
                dst.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Env + "tex/" + tex + ".png"));
                dst.SetColor("_BaseColor", Color.white); dst.SetFloat("_Smoothness", 0.25f);
                bool solid = tex == "T_Dashboard" || tex == "T_Whiteboard";
                AlphaClip(dst, !solid, true);
                float glow = tex == "T_Dashboard" ? 0.9f : tex == "T_Holo" ? 1.6f : tex.StartsWith("T_Sign_KinectoHub") || tex.StartsWith("T_Sign_Hub") || tex == "T_Sign_Repair" || tex == "T_Sign_Diagnostic" ? 0.55f : 0f;
                if (glow > 0f) { dst.SetTexture("_EmissionMap", dst.GetTexture("_BaseMap")); dst.SetColor("_EmissionColor", Color.white * glow); dst.EnableKeyword("_EMISSION"); }
                else dst.DisableKeyword("_EMISSION");
                EditorUtility.SetDirty(dst);
            }
            imp.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), src.name), dst);
        }
        imp.materialImportMode = ModelImporterMaterialImportMode.ImportStandard;
        imp.isReadable = false; imp.importAnimation = false; imp.importCameras = false; imp.importLights = false;
        imp.SaveAndReimport();
    }

    static void RemapCharacterMaterials(string fbx)
    {
        var imp = (ModelImporter)AssetImporter.GetAtPath(fbx);
        var pal = Lit("M_StudentPalette");
        pal.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Chr + "T_StudentPalette.png")); pal.SetFloat("_Smoothness", 0.25f);
        Material Decal(string n, string tex) { var m = Lit(n); m.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Chr + tex)); m.SetFloat("_Smoothness", 0.25f); AlphaClip(m, true, true); return m; }
        Material Solid(string n, Color c, float smooth, Color emit)
        {
            var m = Lit(n); m.SetTexture("_BaseMap", null); m.SetColor("_BaseColor", c); m.SetFloat("_Smoothness", smooth);
            if (emit.maxColorComponent > 0) { m.SetColor("_EmissionColor", emit); m.EnableKeyword("_EMISSION"); } else m.DisableKeyword("_EMISSION");
            return m;
        }
        var map = new Dictionary<string, Material>
        {
            { "M_Palette", pal },
            { "M_Decal_Chest", Decal("M_Student_DecalChest", "T_Decal_Chest.png") },
            { "M_Decal_Back", Decal("M_Student_DecalBack", "T_Decal_Back.png") },
            { "M_Zone_PVDF", Solid("M_Zone_PVDF", new Color(0.95f, 0.66f, 0f), 0.45f, new Color(0.25f, 0.17f, 0f)) },
            { "M_Zone_TENG", Solid("M_Zone_TENG", new Color(0.35f, 0.77f, 0.71f), 0.45f, Color.black) },
            { "M_CuffTag", Solid("M_CuffTag", new Color(0.04f, 0.15f, 0.27f), 0.5f, Color.black) },
            { "M_Pod", Solid("M_Pod", new Color(0.17f, 0.18f, 0.2f), 0.4f, Color.black) },
            { "M_LED", Solid("M_LED", new Color(0.25f, 0.73f, 0.31f), 0.6f, new Color(0.25f, 0.9f, 0.35f) * 2f) },
        };
        foreach (var kv in map) { EditorUtility.SetDirty(kv.Value); imp.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), kv.Key), kv.Value); }
        // Mixamo may rename materials on the way back: map whatever came in by its closest original name
        foreach (var o in AssetDatabase.LoadAllAssetsAtPath(fbx))
            if (o is Material src && !map.ContainsKey(src.name))
                foreach (var kv in map) if (src.name.StartsWith(kv.Key) || src.name.Contains(kv.Key.Substring(2))) { imp.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), src.name), kv.Value); break; }
        imp.isReadable = true;                       // needed to lift the emblem decals onto the jacket surface
        imp.SaveAndReimport();
    }

    // ------------------------------------------------------------------ scene
    static T Add<T>(GameObject go) where T : Component { var c = go.GetComponent<T>(); return c ? c : go.AddComponent<T>(); }

    static void BuildScene()
    {
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        RenderSettings.skybox = AssetDatabase.GetBuiltinExtraResource<Material>("Default-Skybox.mat");
        RenderSettings.ambientMode = AmbientMode.Skybox; RenderSettings.ambientIntensity = 1.05f;
        RenderSettings.fog = true; RenderSettings.fogMode = FogMode.Linear; RenderSettings.fogStartDistance = 450; RenderSettings.fogEndDistance = 2600;
        RenderSettings.fogColor = new Color(0.78f, 0.82f, 0.86f);

        // sun
        var sunGo = new GameObject("Sun");
        var sun = sunGo.AddComponent<Light>(); sun.type = LightType.Directional; sun.intensity = 1.2f; sun.color = new Color(1f, 0.96f, 0.9f);
        sun.shadows = LightShadows.Soft; sun.shadowStrength = 0.85f;
        sunGo.transform.rotation = Quaternion.Euler(55, 150, 0);
        RenderSettings.sun = sun;

        // environment
        var envAsset = AssetDatabase.LoadAssetAtPath<GameObject>(Env + "NUST_Campus.fbx");
        var env = (GameObject)PrefabUtility.InstantiatePrefab(envAsset); env.name = "NUST_Campus_Windhoek";
        var doorParts = new Dictionary<string, Transform>();
        foreach (var r in env.GetComponentsInChildren<MeshRenderer>())
        {
            string n = r.name; var go = r.gameObject;
            r.shadowCastingMode = n.StartsWith("DECAL") || n.StartsWith("SCREEN") ? ShadowCastingMode.Off : ShadowCastingMode.On;
            if (n.StartsWith("DOOR_")) { doorParts[n] = r.transform; var bc = Add<BoxCollider>(go); var rb = Add<Rigidbody>(go); rb.isKinematic = true; continue; }
            if (n.StartsWith("PROP_CardReader")) continue;
            if (n.StartsWith("PROP_HubArm")) { var ab = Add<BoxCollider>(go); var arb = Add<Rigidbody>(go); arb.isKinematic = true; continue; }
            GameObjectUtility.SetStaticEditorFlags(go, StaticEditorFlags.BatchingStatic | StaticEditorFlags.OccluderStatic | StaticEditorFlags.OccludeeStatic);
            if (n.StartsWith("DECAL") || n.StartsWith("SCREEN") || n.StartsWith("BG_Clouds")) continue;   // flat signs / sky only - everything else is solid
            Add<MeshCollider>(go);
        }
        PlayerSettings.bakeCollisionMeshes = true;
        // invisible world boundary at the edge of the Windhoek terrain
        var bounds = new GameObject("WorldBoundary");
        foreach (var (c, sz) in new[] { (new Vector3(0, 25, -1530), new Vector3(2800, 60, 2)), (new Vector3(0, 25, 1230), new Vector3(2800, 60, 2)),
                                        (new Vector3(-1380, 25, -150), new Vector3(2, 60, 2800)), (new Vector3(1380, 25, -150), new Vector3(2, 60, 2800)) })
        { var w = new GameObject("Wall"); w.transform.SetParent(bounds.transform); w.transform.position = c; w.AddComponent<BoxCollider>().size = sz; }

        // simulation modules
        var labGo = new GameObject("KinectoLab");
        var harvest = labGo.AddComponent<HarvestModel>();
        var thermal = labGo.AddComponent<ThermalModel>();
        var faults = labGo.AddComponent<FaultInjector>(); faults.harvest = harvest; faults.thermal = thermal;
        var gait = labGo.AddComponent<GaitHarvestFallback>(); gait.harvest = harvest;
        var amp = labGo.AddComponent<AmplifierCharge>();
        var bridge = labGo.AddComponent<SupabaseBridge>(); bridge.harvest = harvest; bridge.thermal = thermal; bridge.faults = faults;
        var lab = labGo.AddComponent<KinectoLabController>();
        lab.harvest = harvest; lab.thermal = thermal; lab.faults = faults; lab.bridge = bridge; lab.gait = gait; lab.amplifier = amp;
        bridge.lab = lab;
        var ds = sunGo.AddComponent<DaySun>(); ds.lab = lab; ds.sun = sun; ds.northOffset = 180f;   // Windhoek: sunrise east, sunset west

        // player: Unity (x, y, z) = Blender (-x, z, -y); spawn in the courtyard in front of the lecture-hall doors
        var player = new GameObject("Player"); player.tag = "Player";
        player.transform.SetPositionAndRotation(new Vector3(-17.5f, 0.1f, 25f), Quaternion.Euler(0, -90, 0));
        var cc = player.AddComponent<CharacterController>(); cc.height = 1.75f; cc.radius = 0.3f; cc.center = new Vector3(0, 0.88f, 0); cc.stepOffset = 0.35f; cc.slopeLimit = 50f; cc.skinWidth = 0.04f;
        bool rigged = KinectoMixamoSetup.Available;
        var chrAsset = AssetDatabase.LoadAssetAtPath<GameObject>(rigged ? KinectoMixamoSetup.CharacterFbx : Chr + "KinectoStudent_full_unrigged.fbx");
        var model = (GameObject)PrefabUtility.InstantiatePrefab(chrAsset, player.transform); model.name = "KinectoStudent";
        model.transform.localPosition = Vector3.zero; model.transform.localRotation = Quaternion.identity;
        Animator anim = null;
        if (rigged)
        {
            anim = Add<Animator>(model);
            anim.runtimeAnimatorController = AssetDatabase.LoadAssetAtPath<RuntimeAnimatorController>(KinectoMixamoSetup.ControllerPath);
            anim.avatar = AssetDatabase.LoadAllAssetsAtPath(KinectoMixamoSetup.CharacterFbx).OfType<Avatar>().FirstOrDefault();
            anim.applyRootMotion = false;                              // the CharacterController moves the player; clips only animate the body
            anim.cullingMode = AnimatorCullingMode.AlwaysAnimate;
            anim.updateMode = AnimatorUpdateMode.Normal;
            foreach (var smr in model.GetComponentsInChildren<SkinnedMeshRenderer>()) { smr.updateWhenOffscreen = true; smr.quality = SkinQuality.Bone4; }
            lab.avatar = anim;
        }
        Renderer Part(string n) { foreach (var r in model.GetComponentsInChildren<Renderer>()) if (r.name == n || r.name == n + "_MX" || r.name.StartsWith(n + "_MX")) return r; return null; }
        Vector3 Center(string n) { var r = Part(n); return r ? player.transform.InverseTransformPoint(r.bounds.center) : Vector3.zero; }
        Transform Bone(HumanBodyBones b) => anim && anim.isHuman ? anim.GetBoneTransform(b) : null;
        void Follow(Transform t, HumanBodyBones b) { var bone = Bone(b); if (bone) t.SetParent(bone, true); }   // anchors ride the animated bones
        var cuff = new GameObject("CuffTag"); cuff.tag = "CuffTag"; cuff.transform.SetParent(player.transform, false); cuff.transform.localPosition = Center("Cuff_Tag_L");
        var sc = cuff.AddComponent<SphereCollider>(); sc.radius = 0.04f; sc.enabled = false;
        var crb = cuff.AddComponent<Rigidbody>(); crb.isKinematic = true; crb.useGravity = false;
        var elbow = new GameObject("ElbowAnchor_L"); elbow.transform.SetParent(player.transform, false); elbow.transform.localPosition = Center("Zone_PVDF_Elbow_L");
        Transform Anchor(string n, Vector3 local) { var a = new GameObject(n); a.transform.SetParent(player.transform, false); a.transform.localPosition = local; return a.transform; }
        var shoulderA = Anchor("ShoulderAnchor_L", Center("Zone_TENG_Shoulder_L"));
        var backA = Anchor("BackPanelAnchor", Center("Zone_TENG_Back"));
        var pocketA = Anchor("PocketAnchor", new Vector3(0.12f, 0.95f, 0.1f));
        Follow(cuff.transform, HumanBodyBones.LeftLowerArm); Follow(elbow.transform, HumanBodyBones.LeftLowerArm);
        Follow(shoulderA, HumanBodyBones.LeftUpperArm); Follow(backA, HumanBodyBones.Chest); Follow(pocketA, HumanBodyBones.Hips);
        // emblem decals: the unrigged stand-in still needs its decals lifted; the Mixamo upload already has them fixed in the mesh
        if (!rigged) foreach (var mf in model.GetComponentsInChildren<MeshFilter>()) if (mf.name == "Jacket_Standin") mf.sharedMesh = FixJacketDecals(mf.sharedMesh);
        var pvdfZ = new List<Renderer>(); var tengZ = new List<Renderer>();
        foreach (var r in model.GetComponentsInChildren<Renderer>())
        { if (r.name.StartsWith("Zone_PVDF")) pvdfZ.Add(r); else if (r.name.StartsWith("Zone_TENG")) tengZ.Add(r); }
        lab.mover = cc;
        gait.lab = lab; gait.body = player.transform; gait.pvdfZones = pvdfZ.ToArray(); gait.tengZones = tengZ.ToArray();
        amp.thermal = thermal; amp.lab = lab;

        // camera
        var camGo = new GameObject("Main Camera"); camGo.tag = "MainCamera";
        var cam = camGo.AddComponent<Camera>(); cam.nearClipPlane = 0.1f; cam.farClipPlane = 4000f; cam.fieldOfView = 55f;
        camGo.AddComponent<AudioListener>();
        var rig = camGo.AddComponent<Kinecto.KinectoCamera>(); rig.target = player.transform;
        camGo.transform.position = player.transform.position + new Vector3(3.6f, 1.9f, 0f);
        lab.cameraPivot = camGo.transform;

        // HUD
        var hudGo = new GameObject("LabHud");
        var hud = hudGo.AddComponent<LabHud>();
        hud.lab = lab; hud.harvest = harvest; hud.thermal = thermal; hud.faults = faults; hud.bridge = bridge; hud.amp = amp; hud.gait = gait;
        hud.cameraRig = rig; hud.cam = cam; hud.player = player.transform; hud.elbow = elbow.transform;
        hud.shoulder = shoulderA; hud.backPanel = backA; hud.pocket = pocketA;
        hud.rounded = AssetDatabase.LoadAssetAtPath<Sprite>(UI + "UI_Rounded32.png");
        hud.dotSprite = AssetDatabase.LoadAssetAtPath<Sprite>(UI + "UI_Dot.png");
        hud.logo = AssetDatabase.LoadAssetAtPath<Sprite>(UI + "UI_Logo.png");
        hud.ring22 = AssetDatabase.LoadAssetAtPath<Sprite>(UI + "UI_Ring22.png");
        hud.ring14 = AssetDatabase.LoadAssetAtPath<Sprite>(UI + "UI_Ring14.png");
        hud.ring11 = AssetDatabase.LoadAssetAtPath<Sprite>(UI + "UI_Ring11.png");
        TMP_FontAsset F(string w) => AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(UI + "Fonts/PlusJakartaSans-" + w + " SDF.asset");
        hud.fMedium = F("Medium"); hud.fSemi = F("SemiBold"); hud.fBold = F("Bold"); hud.fExtra = F("ExtraBold");

        // card readers + sliding doors
        var rooms = new[] { ("", "Entrance", "Room E201", "EPH810S"), ("_Lab", "Lab", "Computer Lab E105", "Lab"), ("_Theatre", "Theatre", "Lecture Theatre E110", "LT110"), ("_Hub", "Hub", "Kinecto Hub", "HUB") };
        var allReaders = new List<CuffTapReader>();
        CuffTapReader firstReader = null;
        foreach (var (suffix, door, room, session) in rooms)
        {
            var rd = env.GetComponentsInChildren<Transform>(true);
            Transform readerT = null; foreach (var t in rd) if (t.name == "PROP_CardReader" + suffix) readerT = t;
            if (!readerT) { Debug.LogWarning("no reader " + suffix); continue; }
            // tap-OUT station inside the classroom, back to back with the tap-IN reader: same height and offset from the
            // doors, on the inner face of the wall, turned to face into the room (the Hub door is access only: no station)
            Transform outT = null;
            if (suffix != "_Hub" && doorParts.TryGetValue("DOOR_" + door + "_L", out var dL) && doorParts.TryGetValue("DOOR_" + door + "_R", out var dR))
            {
                Physics.SyncTransforms();
                Vector3 dmid = (dL.position + dR.position) * 0.5f;
                Vector3 along = dL.position - dR.position; along.y = 0f; along.Normalize();
                Vector3 nOut = Vector3.Cross(along, Vector3.up); if (Vector3.Dot(readerT.position - dmid, nOut) < 0f) nOut = -nOut;
                Vector3 rc = readerT.GetComponent<Renderer>().bounds.center;
                Vector3 onPlane = dmid + along * Vector3.Dot(rc - dmid, along); onPlane.y = rc.y;
                float depth = -0.3f;                                             // fallback: 0.3 m inside the door line
                float bestD = float.MinValue;
                foreach (var h in Physics.RaycastAll(onPlane - nOut * 3f, nOut, 3.4f, ~0, QueryTriggerInteraction.Ignore))
                {
                    if (h.collider.name.StartsWith("DOOR_")) continue;
                    float dd = Vector3.Dot(h.point - dmid, nOut);
                    if (dd > -0.8f && dd < 0.2f && dd > bestD) bestD = dd;                // the wall's inner face
                }
                if (bestD > float.MinValue) depth = bestD - 0.035f;
                Vector3 target = onPlane + nOut * depth;
                var clone = Object.Instantiate(readerT.gameObject, readerT.parent);
                clone.name = "PROP_TapOut" + suffix;
                clone.transform.RotateAround((rc + target) * 0.5f, Vector3.up, 180f);   // mirrored through the wall
                outT = clone.transform;
                var sticker = env.GetComponentsInChildren<Transform>(true).FirstOrDefault(x => x.name == "DECAL_Card_Sticker" + suffix);
                if (sticker)
                {
                    var stc = sticker.GetComponent<Renderer>().bounds.center;
                    Vector3 rel = stc - rc;
                    Vector3 stT = target + along * Vector3.Dot(rel, along) + Vector3.up * rel.y - nOut * Vector3.Dot(rel, nOut);
                    var sclone = Object.Instantiate(sticker.gameObject, sticker.parent);
                    sclone.name = "DECAL_TapOut_Sticker" + suffix;
                    sclone.transform.RotateAround((stc + stT) * 0.5f, Vector3.up, 180f);
                }
            }
            var trig = Add<BoxCollider>(readerT.gameObject); trig.isTrigger = true;
            trig.center = readerT.InverseTransformPoint(readerT.GetComponent<Renderer>().bounds.center); trig.size = new Vector3(0.35f, 0.4f, 0.35f);
            var ctr = Add<CuffTapReader>(readerT.gameObject); ctr.sessionId = session; ctr.bridge = bridge; ctr.faults = faults;
            var lightGo = new GameObject("ReaderLight"); lightGo.transform.SetParent(readerT, false); lightGo.transform.position = readerT.GetComponent<Renderer>().bounds.center + Vector3.up * 0.1f;
            var rl = lightGo.AddComponent<Light>(); rl.type = LightType.Point; rl.range = 1.6f; rl.intensity = 2.5f; rl.color = Color.green; rl.enabled = false;
            ctr.readerLight = rl;
            if (!firstReader) firstReader = ctr;
            allReaders.Add(ctr);
            if (suffix == "_Hub") hud.hubTarget = readerT;

            var doorsGo = new GameObject("Doors_" + door);
            var sd = doorsGo.AddComponent<SlidingDoor>();
            doorParts.TryGetValue("DOOR_" + door + "_L", out sd.left); doorParts.TryGetValue("DOOR_" + door + "_R", out sd.right);
            sd.reader = readerT; sd.player = player.transform;
            if (!sd.left || !sd.right) Debug.LogWarning("doors missing for " + door);

            var st = Add<ReaderStation>(readerT.gameObject);
            st.reader = ctr; st.doors = sd; st.roomName = room; st.attendance = suffix != "_Hub"; if (suffix == "_Hub") ctr.bridge = null; st.player = player.transform; st.cuffTag = cuff.transform; st.hud = hud; st.lab = lab;
            // classrooms: tap IN outside, tap OUT inside, no free exit sensor -> every visit has an IN and an OUT
            ctr.direction = suffix == "_Hub" ? CuffTapReader.Direction.Toggle : CuffTapReader.Direction.In;
            sd.freeExit = suffix == "_Hub";
            if (outT)
            {
                var trig2 = Add<BoxCollider>(outT.gameObject); trig2.isTrigger = true;
                trig2.center = outT.InverseTransformPoint(outT.GetComponent<Renderer>().bounds.center); trig2.size = new Vector3(0.35f, 0.4f, 0.35f);
                var ctr2 = Add<CuffTapReader>(outT.gameObject); ctr2.sessionId = session; ctr2.bridge = bridge; ctr2.faults = faults;
                ctr2.direction = CuffTapReader.Direction.Out;
                var lg2 = new GameObject("ReaderLight"); lg2.transform.SetParent(outT, false); lg2.transform.position = outT.GetComponent<Renderer>().bounds.center + Vector3.up * 0.1f;
                var rl2 = lg2.AddComponent<Light>(); rl2.type = LightType.Point; rl2.range = 1.6f; rl2.intensity = 2.5f; rl2.color = Color.green; rl2.enabled = false;
                ctr2.readerLight = rl2; allReaders.Add(ctr2);
                var st2 = Add<ReaderStation>(outT.gameObject);
                st2.reader = ctr2; st2.doors = sd; st2.roomName = room; st2.attendance = true; st2.player = player.transform; st2.cuffTag = cuff.transform; st2.hud = hud; st2.lab = lab;
            }
        }
        faults.reader = firstReader;

        // shade / indoor zones (outside temperature the jacket feels)
        void Zone(string name, Vector3 c, Vector3 size, float off)
        {
            var z = new GameObject(name); z.transform.position = c;
            var b = z.AddComponent<BoxCollider>(); b.isTrigger = true; b.size = size;
            var sz = z.AddComponent<SunShadeZone>(); sz.lab = lab; sz.offsetC = off; sz.zoneName = name;
        }
        for (int k = 0; k < 4; k++) Zone("Shade_SolarCarport" + k, new Vector3(78f, 1.5f, 47.5f - 11f * k), new Vector3(46f, 3f, 5.6f), -3f);
        foreach (var n in new[] { "BLD_Lecture", "BLD_Lab", "BLD_Theatre", "BLD_Hub" })
            foreach (var r in env.GetComponentsInChildren<MeshRenderer>()) if (r.name == n)
                { var b = r.bounds; Zone("Indoors_" + n.Substring(4), b.center, new Vector3(b.size.x - 1f, 6f, b.size.z - 1f), -4f); }

        // Kinecto Hub: repair bench + diagnostic scanner, robot arms, hall lights
        Transform Find(string n) { foreach (var t in env.GetComponentsInChildren<Transform>(true)) if (t.name == n) return t; return null; }
        var arms = new List<Transform>(); foreach (var n in new[] { "PROP_HubArm1", "PROP_HubArm2", "PROP_HubArm3" }) { var a = Find(n); if (a) arms.Add(a); }
        foreach (var (n, kind, lbl) in new[] { ("PROP_HubRepair", HubStation.Kind.Repair, "Repair & Maintenance"), ("PROP_HubDiagnostic", HubStation.Kind.Diagnostic, "Diagnostic Bay") })
        {
            var t = Find(n); if (!t) { Debug.LogWarning("missing " + n); continue; }
            var hs = Add<HubStation>(t.gameObject); hs.kind = kind; hs.label = lbl; hs.lab = lab; hs.faults = faults; hs.harvest = harvest; hs.thermal = thermal;
            hs.hud = hud; hs.player = player.transform; hs.arms = arms.ToArray();
        }
        foreach (var p in new[] { new Vector2(78, 62), new Vector2(78, 76), new Vector2(92, 62), new Vector2(92, 76), new Vector2(100, 69), new Vector2(72, 57) })
        {
            var lg = new GameObject("HubLight"); lg.transform.position = new Vector3(-p.x, 9.6f, -p.y);
            var l = lg.AddComponent<Light>(); l.type = LightType.Point; l.range = 16f; l.intensity = 2.2f; l.color = new Color(0.93f, 0.97f, 1f); l.shadows = LightShadows.None;
        }

        // computer lab video wall: live jacket data
        var wall = Find("SCREEN_Lab_VideoWall"); var labInt = Find("LAB_Interior");
        if (wall)
        {
            var wr = wall.GetComponent<Renderer>(); var c = wr.bounds.center;
            Vector3 inward = labInt ? labInt.GetComponent<Renderer>().bounds.center - c : Vector3.right; inward.y = 0; inward = Mathf.Abs(inward.x) > Mathf.Abs(inward.z) ? new Vector3(Mathf.Sign(inward.x), 0, 0) : new Vector3(0, 0, Mathf.Sign(inward.z));
            var sgo = new GameObject("LabVideoWall"); sgo.transform.position = c + inward * 0.04f; sgo.transform.rotation = Quaternion.LookRotation(-inward, Vector3.up);
            var ls = sgo.AddComponent<LabScreen>(); ls.lab = lab; ls.harvest = harvest; ls.thermal = thermal; ls.faults = faults; ls.amp = amp; ls.readers = allReaders.ToArray();
            ls.fSemi = hud.fSemi; ls.fExtra = hud.fExtra; ls.rounded = hud.rounded;
            var sz = wr.bounds.size; ls.sizeMeters = new Vector2(Mathf.Max(sz.x, sz.z), sz.y);
        }

        // image quality: MSAA, shadows, tonemapping + bloom, post-processing on the camera
        var urp = GraphicsSettings.defaultRenderPipeline as UniversalRenderPipelineAsset;
        if (urp) { urp.msaaSampleCount = 4; urp.shadowDistance = 160f; urp.shadowCascadeCount = 4; urp.renderScale = 1f; EditorUtility.SetDirty(urp); }
        var camData = cam.GetUniversalAdditionalCameraData(); camData.renderPostProcessing = true; camData.antialiasing = AntialiasingMode.None;
        string profPath = Mat + "KinectoVolume.asset";
        var prof = AssetDatabase.LoadAssetAtPath<VolumeProfile>(profPath);
        if (!prof)
        {
            prof = ScriptableObject.CreateInstance<VolumeProfile>(); AssetDatabase.CreateAsset(prof, profPath);
            var tm = prof.Add<Tonemapping>(true); tm.mode.Override(TonemappingMode.Neutral);
            var bl = prof.Add<Bloom>(true); bl.threshold.Override(1.0f); bl.intensity.Override(0.55f); bl.scatter.Override(0.6f);
            var ca = prof.Add<ColorAdjustments>(true); ca.postExposure.Override(0.15f); ca.contrast.Override(8f); ca.saturation.Override(6f);
            foreach (var comp in prof.components) AssetDatabase.AddObjectToAsset(comp, prof);
            EditorUtility.SetDirty(prof);
        }
        var vol = new GameObject("PostProcessing").AddComponent<Volume>(); vol.isGlobal = true; vol.sharedProfile = prof;
        PlayerSettings.runInBackground = true;

        // UI event system (new Input System)
        var es = new GameObject("EventSystem"); es.AddComponent<EventSystem>().sendNavigationEvents = false; es.AddComponent<InputSystemUIInputModule>();

        hud.Build();   // edit-mode preview (rebuilt + wired at Play)
        try { Debug.Log("[NPC] " + KinectoNpcBuilder.AddToScene()); } catch (System.Exception e) { Debug.LogException(e); }   // campus NPCs + traffic

        Directory.CreateDirectory(Path.GetDirectoryName(ScenePath));
        EditorSceneManager.SaveScene(scene, ScenePath);
        var list = new List<EditorBuildSettingsScene>(EditorBuildSettings.scenes);
        if (!list.Exists(s => s.path == ScenePath)) list.Insert(0, new EditorBuildSettingsScene(ScenePath, true));
        EditorBuildSettings.scenes = list.ToArray();
        Debug.Log("[Kinecto] Virtual Lab scene built: " + ScenePath);
    }

    /// The chest + back emblem decals of Jacket_Standin were modelled a few mm UNDER the jacket surface, so they never
    /// showed. Project every decal vertex onto the jacket body (ray from outside along the decal's facing) + 6 mm.
    static Mesh FixJacketDecals(Mesh src)
    {
        string path = Chr + "Jacket_Standin_EmblemFix.asset";
        var mesh = Object.Instantiate(src); mesh.name = "Jacket_Standin_EmblemFix";
        var verts = mesh.vertices;
        var tmp = new Mesh { indexFormat = UnityEngine.Rendering.IndexFormat.UInt32, vertices = verts, triangles = mesh.GetTriangles(0) };
        var go = new GameObject("tmpJacketCollider"); var mc = go.AddComponent<MeshCollider>(); mc.sharedMesh = tmp;
        Physics.SyncTransforms();
        int moved = 0;
        for (int s = 1; s < mesh.subMeshCount; s++)
        {
            float side = Mathf.Sign(mesh.GetSubMesh(s).bounds.center.y);           // local +y = back, -y = chest
            var dir = new Vector3(0, side, 0);
            var idx = new HashSet<int>(mesh.GetTriangles(s));
            foreach (int i in idx)
            {
                var p = verts[i];
                if (mc.Raycast(new Ray(new Vector3(p.x, 0, p.z) + dir * 0.6f, -dir), out RaycastHit hit, 1.2f))
                { verts[i] = new Vector3(p.x, hit.point.y + side * 0.006f, p.z); moved++; }
            }
        }
        Object.DestroyImmediate(go);
        mesh.vertices = verts;
        // the back decal was wound facing INTO the body (culled, lit from inside): face every decal outwards
        var normals = mesh.normals;
        for (int s = 1; s < mesh.subMeshCount; s++)
        {
            float side = Mathf.Sign(mesh.GetSubMesh(s).bounds.center.y);
            var dir = new Vector3(0, side, 0);
            var tris = mesh.GetTriangles(s); Vector3 wind = Vector3.zero;
            for (int i = 0; i < tris.Length; i += 3) wind += Vector3.Cross(verts[tris[i + 1]] - verts[tris[i]], verts[tris[i + 2]] - verts[tris[i]]);
            if (Vector3.Dot(wind, dir) < 0f) { for (int i = 0; i < tris.Length; i += 3) { int t = tris[i + 1]; tris[i + 1] = tris[i + 2]; tris[i + 2] = t; } mesh.SetTriangles(tris, s); }
            foreach (int i in tris) normals[i] = dir;
        }
        mesh.normals = normals; mesh.RecalculateBounds();
        var old = AssetDatabase.LoadAssetAtPath<Mesh>(path); if (old) AssetDatabase.DeleteAsset(path);
        AssetDatabase.CreateAsset(mesh, path);
        Debug.Log("[Kinecto] emblem decal vertices lifted onto the jacket: " + moved);
        return mesh;
    }

    static void EnsureTag(string tag)
    {
        var tm = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/TagManager.asset")[0]);
        var tags = tm.FindProperty("tags");
        for (int i = 0; i < tags.arraySize; i++) if (tags.GetArrayElementAtIndex(i).stringValue == tag) return;
        tags.InsertArrayElementAtIndex(tags.arraySize); tags.GetArrayElementAtIndex(tags.arraySize - 1).stringValue = tag;
        tm.ApplyModifiedProperties();
    }
}
