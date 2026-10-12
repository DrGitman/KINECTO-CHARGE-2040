// Kinecto Virtual Lab: the computer lab's video wall shows the jacket live (same numbers as the HUD).
// World-space canvas in the HUD style, placed on SCREEN_Lab_VideoWall by the scene builder.
using System.Linq;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class LabScreen : MonoBehaviour
{
    public KinectoLabController lab;
    public HarvestModel harvest;
    public ThermalModel thermal;
    public FaultInjector faults;
    public AmplifierCharge amp;
    public CuffTapReader[] readers;
    public TMP_FontAsset fSemi, fExtra;
    public Sprite rounded;
    public Vector2 sizeMeters = new Vector2(12f, 4.8f);

    TextMeshProUGUI clock, energy, power, cuff, inside, outside, mode, faultText, tapText, charge;
    Image cuffFill, faultDot;
    const float W = 1200f, H = 480f;

    void Start() => Build();

    TextMeshProUGUI T(Transform p, string s, TMP_FontAsset f, float size, Color c, float x, float y, float w, TextAlignmentOptions a = TextAlignmentOptions.TopLeft)
    {
        var go = new GameObject("t", typeof(RectTransform)); go.transform.SetParent(p, false);
        var r = (RectTransform)go.transform; r.anchorMin = r.anchorMax = r.pivot = new Vector2(0, 1); r.anchoredPosition = new Vector2(x, -y); r.sizeDelta = new Vector2(w, size * 1.4f);
        var t = go.AddComponent<TextMeshProUGUI>(); t.font = f; t.fontSize = size; t.color = c; t.alignment = a; t.text = s; t.textWrappingMode = TextWrappingModes.NoWrap; t.raycastTarget = false; return t;
    }
    Image Box(Transform p, Color c, float x, float y, float w, float h, float radius)
    {
        var go = new GameObject("b", typeof(RectTransform)); go.transform.SetParent(p, false);
        var r = (RectTransform)go.transform; r.anchorMin = r.anchorMax = r.pivot = new Vector2(0, 1); r.anchoredPosition = new Vector2(x, -y); r.sizeDelta = new Vector2(w, h);
        var im = go.AddComponent<Image>(); im.color = c; im.raycastTarget = false;
        if (radius > 0) { im.sprite = rounded; im.type = Image.Type.Sliced; im.pixelsPerUnitMultiplier = 32f / radius; }
        return im;
    }

    void Build()
    {
        var go = new GameObject("VideoWallCanvas", typeof(RectTransform)); go.transform.SetParent(transform, false);
        var c = go.AddComponent<Canvas>(); c.renderMode = RenderMode.WorldSpace;
        var rt = (RectTransform)go.transform; rt.sizeDelta = new Vector2(W, H); rt.localScale = new Vector3(sizeMeters.x / W, sizeMeters.y / H, 1f);
        var root = go.transform;
        Box(root, LabHud.Navy, 0, 0, W, H, 0);
        Box(root, new Color(0.07f, 0.1f, 0.13f), 0, 0, W, 64, 0);
        T(root, "Kinecto Virtual Lab · live jacket", fExtra, 30, LabHud.TextC, 28, 14, 700);
        clock = T(root, "", fExtra, 30, LabHud.TextC, W - 330, 14, 300, TextAlignmentOptions.TopRight);
        T(root, "SIMULATED", fExtra, 18, LabHud.Gold, W - 160, 22, 140, TextAlignmentOptions.TopRight);
        // tiles
        Color tile = new Color(0.07f, 0.1f, 0.13f, 1f);
        Box(root, tile, 24, 88, 372, 368, 22); Box(root, tile, 414, 88, 372, 368, 22); Box(root, tile, 804, 88, 372, 368, 22);
        T(root, "Energy made today", fSemi, 22, LabHud.Text2, 52, 112, 320);
        energy = T(root, "", fExtra, 84, LabHud.TextC, 50, 140, 330);
        power = T(root, "", fSemi, 22, LabHud.Gold, 52, 250, 330);
        T(root, "Cuff light", fSemi, 22, LabHud.TextC, 52, 300, 200);
        cuff = T(root, "", fExtra, 22, LabHud.Gold, 200, 300, 168, TextAlignmentOptions.TopRight);
        Box(root, LabHud.Track, 52, 338, 316, 18, 9); cuffFill = Box(root, LabHud.Gold, 52, 338, 18, 18, 9);
        charge = T(root, "", fSemi, 19, LabHud.Teal, 52, 380, 330);
        T(root, "Inside the jacket", fSemi, 22, LabHud.Text2, 442, 112, 170);
        T(root, "Outside", fSemi, 22, LabHud.Text2, 620, 112, 150);
        inside = T(root, "", fExtra, 84, LabHud.TextC, 440, 140, 180);
        outside = T(root, "", fExtra, 84, LabHud.Red, 618, 140, 170);
        mode = T(root, "", fSemi, 22, LabHud.Blue, 442, 260, 330);
        T(root, "Jacket health", fSemi, 22, LabHud.Text2, 832, 112, 320);
        faultDot = Box(root, LabHud.Green, 832, 156, 18, 18, 9);
        faultText = T(root, "", fExtra, 26, LabHud.TextC, 862, 150, 300);
        faultText.textWrappingMode = TextWrappingModes.Normal; faultText.rectTransform.sizeDelta = new Vector2(300, 140);
        T(root, "Last cuff tap", fSemi, 22, LabHud.Text2, 832, 300, 320);
        tapText = T(root, "", fSemi, 20, LabHud.TextC, 832, 334, 320);
        tapText.textWrappingMode = TextWrappingModes.Normal; tapText.rectTransform.sizeDelta = new Vector2(320, 100);
    }

    void Update()
    {
        if (!clock || !lab) return;
        clock.text = lab.ClockText + (lab.ScheduleRunning ? $"  ×{lab.TimeSpeed:0.#}" : "");
        energy.text = $"{harvest.harvestedJ * 1e3:0.00}<size=36> mJ</size>";
        power.text = $"{lab.CurrentActivity} · about {lab.PowerMicroW:0.0} µW";
        float pct = Mathf.Clamp01(harvest.BufferVoltage / 4f);
        cuff.text = harvest.statusLightOn ? "ON" : $"{pct * 100f:0}%";
        cuffFill.rectTransform.sizeDelta = new Vector2(Mathf.Max(18f, 316f * pct), 18f); cuffFill.enabled = pct > 0.001f;
        charge.text = amp ? $"Amplifier 2040 · {amp.PowerW:0.0} W → {amp.Destination}" + (amp.device != ChargeDevice.Nothing ? $" {amp.percent:0}%" : "") : "";
        inside.text = thermal.sensorFault ? "--°" : $"{thermal.insideC:0}°";
        outside.text = $"{thermal.ambientC:0}°";
        outside.color = thermal.ambientC >= 30f ? LabHud.Red : thermal.ambientC <= 12f ? LabHud.Blue : LabHud.TextC;
        mode.text = $"{thermal.mode} · " + (thermal.heaterOn ? "heater on" : thermal.blowerOn ? "fan on" : "idle") + $" · battery {thermal.BatteryLeftPct:0}%";
        mode.color = thermal.heaterOn ? LabHud.Red : thermal.blowerOn ? LabHud.Blue : LabHud.Text2;
        var f = faults.ActiveFlags.ToList();
        faultDot.color = f.Count == 0 ? LabHud.Green : LabHud.Red;
        faultText.text = f.Count == 0 ? "All systems OK" : string.Join("\n", f.Select(HubStation.FaultName));
        string last = null;
        if (readers != null) foreach (var r in readers) if (r && r.log.Count > 0) last = r.log[r.log.Count - 1];
        tapText.text = last ?? "No taps yet · tap your cuff at a classroom door";
    }
}
