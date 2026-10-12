// Kinecto Virtual Lab: imports the Mixamo-rigged student and the Mixamo clips as one Humanoid set and builds the
// Animator controller (smooth Idle <-> Walk <-> Run blend on Speed, Scan cross-faded in/out on the Tap trigger).
// Files expected in Assets/Kinecto/Character/Mixamo/:
//   KinectoStudent_Mixamo.fbx  (character, T-pose, with skin)
//   Idle.fbx  Walk.fbx  Run.fbx  Scan.fbx   (Mixamo clips on the same rig, "without skin", 30 fps, keyframe reduction off)
//   JumpUp.fbx  Fall.fbx  Land.fbx         (Mixamo "Jumping Up / Falling Idle / Jumping Down" game-blend set; Space jumps)
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

public static class KinectoMixamoSetup
{
    public const string Dir = "Assets/Kinecto/Character/Mixamo/";
    public const string CharacterFbx = Dir + "KinectoStudent_Mixamo.fbx";
    public const string ControllerPath = "Assets/Kinecto/Character/KinectoStudent.controller";
    public const float WalkSpeed = 1.4f, RunSpeed = 3.2f;      // KinectoLabController walkSpeed / runSpeed
    static readonly string[] Loops = { "Idle", "Walk", "Run", "Fall" };
    static readonly string[] OneShots = { "Scan", "JumpUp", "Land" };

    public static bool Available => File.Exists(CharacterFbx) && File.Exists(Dir + "Walk.fbx");

    [MenuItem("Kinecto/Set up Mixamo character + Animator")]
    public static string Setup()
    {
        if (!File.Exists(CharacterFbx)) return "missing " + CharacterFbx;

        // 1) character: Humanoid avatar created from the Mixamo skeleton
        var ci = (ModelImporter)AssetImporter.GetAtPath(CharacterFbx);
        ci.animationType = ModelImporterAnimationType.Human;
        ci.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        ci.importAnimation = false; ci.importCameras = false; ci.importLights = false;
        ci.isReadable = true;
        ci.SaveAndReimport();
        // Mixamo writes centimetres: bring the student to real size (about 1.75 m)
        var probe = AssetDatabase.LoadAssetAtPath<GameObject>(CharacterFbx);
        float h = 0f; foreach (var s in probe.GetComponentsInChildren<SkinnedMeshRenderer>()) h = Mathf.Max(h, s.sharedMesh.bounds.size.y * s.transform.lossyScale.y, s.sharedMesh.bounds.size.z * s.transform.lossyScale.z);
        if (h > 10f) { ci.globalScale = ci.globalScale * 0.01f; ci.SaveAndReimport(); }
        // rebuild the avatar at the final scale (a stale cm avatar collapses every bone into one point at runtime)
        ci.animationType = ModelImporterAnimationType.Generic; ci.SaveAndReimport();
        ci.animationType = ModelImporterAnimationType.Human; ci.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel; ci.SaveAndReimport();
        var avatar = AssetDatabase.LoadAllAssetsAtPath(CharacterFbx).OfType<Avatar>().FirstOrDefault();
        if (!avatar || !avatar.isHuman) return "avatar not human - check the Mixamo FBX";

        // 2) clips: same avatar, looping where it matters, root rotation/height baked so nothing drifts or bobs
        string report = "avatar ok; ";
        foreach (var name in Loops.Concat(OneShots))
        {
            string path = Dir + name + ".fbx";
            if (!File.Exists(path)) { report += name + " missing; "; continue; }
            var im = (ModelImporter)AssetImporter.GetAtPath(path);
            im.animationType = ModelImporterAnimationType.Human;
            im.avatarSetup = ModelImporterAvatarSetup.CopyFromOther;
            im.sourceAvatar = avatar;
            im.globalScale = 1f;                                  // humanoid clips are scale-free (muscle space); keep Mixamo's own units
            im.importAnimation = true;
            im.resampleCurves = true;
            im.animationCompression = ModelImporterAnimationCompression.Optimal;
            var defs = im.defaultClipAnimations;
            if (defs.Length == 0) { im.SaveAndReimport(); defs = im.defaultClipAnimations; }
            var c = defs[0];
            bool loop = Loops.Contains(name);
            c.name = name;
            c.loopTime = loop; c.loopPose = loop && name != "Fall";                 // loop pose blends the last frame into the first: seamless cycles
            c.lockRootRotation = true; c.keepOriginalOrientation = true;
            c.lockRootHeightY = true; c.keepOriginalPositionY = false; c.heightFromFeet = true;   // feet stay on the ground
            c.lockRootPositionXZ = false;                         // forward motion stays on the root; applyRootMotion=false discards it
            c.mirror = false; c.cycleOffset = 0f;
            im.clipAnimations = new[] { c };
            im.SaveAndReimport();
        }

        // 3) controller
        AnimationClip Clip(string n) => AssetDatabase.LoadAllAssetsAtPath(Dir + n + ".fbx").OfType<AnimationClip>().FirstOrDefault(a => a.name == n);
        var idle = Clip("Idle"); var walk = Clip("Walk"); var run = Clip("Run"); var scan = Clip("Scan");
        if (!idle || !walk || !run) return report + "clips missing";
        float Ground(AnimationClip c) { float v = new Vector2(c.averageSpeed.x, c.averageSpeed.z).magnitude; while (v > 20f) v /= 100f; return v; }   // Mixamo clips report cm/s
        float walkV = Mathf.Max(0.8f, Ground(walk)), runV = Mathf.Max(walkV + 0.8f, Ground(run));
        report += $"walk {walkV:0.00} m/s, run {runV:0.00} m/s; ";

        AssetDatabase.DeleteAsset(ControllerPath);
        var ctrl = AnimatorController.CreateAnimatorControllerAtPath(ControllerPath);
        ctrl.AddParameter("Speed", AnimatorControllerParameterType.Float);
        ctrl.AddParameter("Tap", AnimatorControllerParameterType.Trigger);
        ctrl.AddParameter("Jump", AnimatorControllerParameterType.Trigger);
        ctrl.AddParameter(new AnimatorControllerParameter { name = "Grounded", type = AnimatorControllerParameterType.Bool, defaultBool = true });
        ctrl.AddParameter("VerticalSpeed", AnimatorControllerParameterType.Float);
        var sm = ctrl.layers[0].stateMachine;
        var loco = ctrl.CreateBlendTreeInController("Locomotion", out BlendTree bt, 0);
        bt.blendType = BlendTreeType.Simple1D; bt.blendParameter = "Speed"; bt.useAutomaticThresholds = false;
        // thresholds = the student's real walk / run speed; each clip is time-scaled so its stride covers exactly that
        // ground speed (no foot skating, no slow-motion legs)
        bt.AddChild(idle, 0f); bt.AddChild(walk, WalkSpeed); bt.AddChild(run, RunSpeed);
        var ch = bt.children;
        ch[1].timeScale = WalkSpeed / walkV; ch[2].timeScale = RunSpeed / runV;
        bt.children = ch;
        sm.defaultState = loco;
        if (scan)
        {
            var s = sm.AddState("Scan"); s.motion = scan; s.writeDefaultValues = true; s.speed = 1.5f;   // brisk tap, ~2 s
            var tin = sm.AddAnyStateTransition(s);
            tin.AddCondition(AnimatorConditionMode.If, 0, "Tap");
            tin.AddCondition(AnimatorConditionMode.If, 0, "Grounded");
            tin.hasExitTime = false; tin.duration = 0.18f; tin.canTransitionToSelf = false; tin.interruptionSource = TransitionInterruptionSource.None;
            var tout = s.AddTransition(loco);
            tout.hasExitTime = true; tout.exitTime = 0.82f; tout.duration = 0.3f;
            var tmove = s.AddTransition(loco);                    // walking off mid-scan blends straight back out
            tmove.AddCondition(AnimatorConditionMode.Greater, 0.6f, "Speed");
            tmove.hasExitTime = false; tmove.duration = 0.25f;
        }
        // jump: take-off -> air loop -> landing, all cross-faded; walking off a ledge also drops into the air loop
        var jumpUp = Clip("JumpUp"); var fall = Clip("Fall"); var land = Clip("Land");
        if (jumpUp && fall && land)
        {
            var sUp = sm.AddState("JumpUp"); sUp.motion = jumpUp;
            var sFall = sm.AddState("Fall"); sFall.motion = fall;
            var sLand = sm.AddState("Land"); sLand.motion = land;
            var j = sm.AddAnyStateTransition(sUp); j.AddCondition(AnimatorConditionMode.If, 0, "Jump");
            j.hasExitTime = false; j.duration = 0.08f; j.canTransitionToSelf = false;
            var upFall = sUp.AddTransition(sFall); upFall.hasExitTime = true; upFall.exitTime = 0.85f; upFall.duration = 0.12f;
            var upLand = sUp.AddTransition(sLand); upLand.AddCondition(AnimatorConditionMode.If, 0, "Grounded"); upLand.AddCondition(AnimatorConditionMode.Less, 0f, "VerticalSpeed");
            upLand.hasExitTime = false; upLand.duration = 0.08f;
            var drop = loco.AddTransition(sFall); drop.AddCondition(AnimatorConditionMode.IfNot, 0, "Grounded"); drop.hasExitTime = false; drop.duration = 0.2f;
            var fl = sFall.AddTransition(sLand); fl.AddCondition(AnimatorConditionMode.If, 0, "Grounded"); fl.hasExitTime = false; fl.duration = 0.08f;
            var back = sLand.AddTransition(loco); back.hasExitTime = true; back.exitTime = 0.6f; back.duration = 0.2f;
            var go = sLand.AddTransition(loco); go.AddCondition(AnimatorConditionMode.Greater, 0.6f, "Speed"); go.hasExitTime = true; go.exitTime = 0.25f; go.duration = 0.15f;
            report += "jump states ok; ";
        }
        EditorUtility.SetDirty(ctrl);
        AssetDatabase.SaveAssets();
        return report + "controller built";
    }
}
