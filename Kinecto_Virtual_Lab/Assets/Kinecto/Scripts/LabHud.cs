// Kinecto Virtual Lab HUD (design "Virtual Lab HUD", screens 01-05). Screen Space Overlay, 1920x1080 reference,
// match 0.5, Plus Jakarta Sans. Builds its own UI so it matches the design pixel for pixel, then reads the sim
// every frame. Wiring follows the handoff table:
//   Tab -> TogglePanel, tabs -> ShowTab(0/1/2), energy = harvest.harvestedJ x 1000, cuff light = BufferVoltage / 4 V,
//   Phone/Earbuds/Watch/Nothing -> AmplifierCharge (SPECULATIVE), inside/outside = thermal.insideC / ambientC,
//   weather / mode / play / speed -> KinectoLabController, faults -> FaultInjector, toast <- CuffTapReader.onLog.
using System.Collections.Generic;
using System.Linq;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class LabHud : MonoBehaviour
{
    [Header("Simulation")]
    public KinectoLabController lab;
    public HarvestModel harvest;
    public ThermalModel thermal;
    public FaultInjector faults;
    public SupabaseBridge bridge;
    public AmplifierCharge amp;
    public GaitHarvestFallback gait;
    public Kinecto.KinectoCamera cameraRig;
    public Camera cam;
    public Transform player;
    public Transform elbow;                       // left elbow PVDF zone (callout anchor)
    public Transform hubTarget;                   // Kinecto Hub entrance (repair marker)
    public Transform shoulder, backPanel, pocket;  // other energy-source anchors on the jacket
    public string jacketId = "KC-SIM-0001";

    [Header("Look (assigned by the scene builder)")]
    public Sprite rounded;                        // white 9-sliced, 32 px corners
    public Sprite dotSprite, logo, ring22, ring14, ring11;
    public TMP_FontAsset fMedium, fSemi, fBold, fExtra;

    [Header("State")]
    public bool panelVisible;
    public int tab;

    // ------------------------------------------------------------------ colours (design tokens)
    static Color Hex(string h, float a = 1f) { ColorUtility.TryParseHtmlString("#" + h, out var c); c.a = a; return c; }
    public static readonly Color PanelC = Hex("121A21"), ButtonC = Hex("1E2830"), LineC = Hex("27333D"), TextC = Hex("EEF2F6"),
        Text2 = Hex("9AA8B5"), Text3 = Hex("6B7884"), Gold = Hex("F2A900"), Teal = Hex("58C4B5"), Red = Hex("E5484D"),
        Blue = Hex("4EA8DE"), Green = Hex("3FB950"), Navy = Hex("0B2545"), ChipNavy = Hex("16355E"), TabBarC = Hex("0D1318"),
        Track = Hex("2A3742"), BannerBg = Hex("3A1416"), CapFill = Hex("26323C"), CapLine = Hex("3A4752"), Subtitle = Hex("B7C4D6"),
        StatusBlue = Hex("122635"), StatusRed = Hex("3A1416"), StatusGreen = Hex("12301E"), StatusGrey = Hex("1E2830"), White = Color.white;

    public static LabHud Instance { get; private set; }

    // ------------------------------------------------------------------ built references
    class Btn { public Image border, fill; public TextMeshProUGUI title, sub; public Button button; }
    class Chip { public RectTransform root; public Image bg, dot; public TextMeshProUGUI text; }
    RectTransform canvasRT, panel, tabPill, playerLabelRT, calloutRT, calloutLine, calloutDot, banner;
    readonly RectTransform[] pages = new RectTransform[3];
    readonly TextMeshProUGUI[] tabText = new TextMeshProUGUI[3];
    static readonly float[] PageHeight = { 572f, 513f, 571f };
    TextMeshProUGUI clock, energyBig, energyUnit, energyNow, cuffPct, cuffHint, devLabel, devPct, devHint, footnote,
        insideBig, outsideBig, statusText, rangeText, batteryText, playText, bannerTitle, bannerSub, keyHideLabel, calloutText;
    Image cuffFill, devFill, statusBg, statusDot;
    RectTransform devBarRT;
    Chip liveChip, weatherChip, appChip, miniChip, toastChip, playerLabel, hubMarker, ampChip;
    Btn[] devBtns, weatherBtns, modeBtns, speedBtns, faultBtns; Btn playBtn, fixAllBtn, bannerFix;
    readonly Dictionary<string, float> faultSince = new Dictionary<string, float>();
    float toastUntil = -1f;

    static readonly string[] FaultIds = { "body_sensor_offline", "heater_over_limit", "blower_current_spike", "buffer_not_charging", "cuff_tag_unreadable", "battery_hot" };
    static readonly string[] FaultTitle = { "Sensor stops", "Heater too hot", "Fan blocked", "Not charging", "Cuff not reading", "Battery hot" };
    static readonly string[] FaultSub = { "body sensor", "over limit", "current spike", "buffer", "NFC tag", "over 45 °C" };
    static readonly string[] FaultBanner = {
        "Body sensor stopped · heating switched off for safety",
        "Heater too hot · switched off at the safety limit",
        "Fan blocked · current spike on the blower",
        "Not charging · the energy buffer stopped filling",
        "Cuff not reading · the NFC tag can't be read",
        "Battery hot · over 45 °C, charging paused" };

    // ================================================================== lifecycle
    void Awake()
    {
        Instance = this;
        if (!cam) cam = Camera.main;
        if (Application.isPlaying) Build();
    }

    void Start()
    {
        string path = System.IO.Path.Combine(Application.streamingAssetsPath, "lab_connection.json");
        if (System.IO.File.Exists(path))
        {
            var m = System.Text.RegularExpressions.Regex.Match(System.IO.File.ReadAllText(path), "\"jacket_id\"\\s*:\\s*\"([^\"]+)\"");
            if (m.Success) jacketId = m.Groups[1].Value;
        }
        ApplyPanel();
        ShowTab(tab);
    }

    // ================================================================== public API (handoff)
    public void TogglePanel() { panelVisible = !panelVisible; ApplyPanel(); }

    public void ShowTab(int i)
    {
        tab = Mathf.Clamp(i, 0, 2);
        for (int k = 0; k < 3; k++) { pages[k].gameObject.SetActive(k == tab); tabText[k].color = k == tab ? Navy : Text2; tabText[k].font = k == tab ? fBold : fSemi; }
        tabPill.anchoredPosition = new Vector2(4f + tab * (380f / 3f), -4f);
        panel.sizeDelta = new Vector2(420f, PageHeight[tab]);
    }

    public void ShowToast(string text, Color dot)
    {
        toastChip.text.text = text; toastChip.dot.color = dot;
        toastUntil = Time.time + 4f;
    }

    void ApplyPanel()
    {
        panel.gameObject.SetActive(panelVisible);
        keyHideLabel.text = panelVisible ? "Hide panels" : "Show panels";
        Kinecto.KinectoCamera.SetCursor(!panelVisible);
        if (cameraRig) cameraRig.lookLocked = panelVisible;
    }

    // ================================================================== build
    [ContextMenu("Build HUD")]
    public void Build()
    {
        var old = transform.Find("LabHudCanvas");
        if (old) { if (Application.isPlaying) Destroy(old.gameObject); else DestroyImmediate(old.gameObject); }

        var root = Node("LabHudCanvas", transform);
        var canvas = root.gameObject.AddComponent<Canvas>(); canvas.renderMode = RenderMode.ScreenSpaceOverlay; canvas.sortingOrder = 10;
        var scaler = root.gameObject.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize; scaler.referenceResolution = new Vector2(1920, 1080);
        scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight; scaler.matchWidthOrHeight = 0.5f; scaler.referencePixelsPerUnit = 100;
        root.gameObject.AddComponent<GraphicRaycaster>();
        canvasRT = root;

        BuildWorldLabels();
        BuildTopBar();
        miniChip = MakeChip("MiniChip", canvasRT, PanelC.WithA(0.9f), 32, 14, 14, 8, 8, fSemi, 13, TextC, true);
        TL(miniChip.root, 24, 84, 206, 32); miniChip.dot.color = Gold;
        toastChip = MakeChip("Toast", canvasRT, PanelC.WithA(0.9f), 32, 14, 14, 8, 8, fSemi, 13, TextC, true);
        TL(toastChip.root, 24, 84, 231, 32); toastChip.dot.color = Green; toastChip.root.gameObject.SetActive(false);
        BuildBanner();
        BuildPanel();
        BuildKeyBar();
        if (Application.isPlaying) Wire();
    }

    void BuildTopBar()
    {
        var bar = Node("TopBar", canvasRT);
        bar.anchorMin = new Vector2(0, 1); bar.anchorMax = new Vector2(1, 1); bar.pivot = new Vector2(0.5f, 1);
        bar.anchoredPosition = Vector2.zero; bar.sizeDelta = new Vector2(0, 64);
        Fill(bar, Navy, 0);
        var lg = Node("Logo", bar); TL(lg, 24, 13, 38, 38); var li = lg.gameObject.AddComponent<Image>(); li.sprite = logo; li.preserveAspect = true; li.raycastTarget = false;
        TxtAt("Title", bar, "Kinecto Virtual Lab", fExtra, 19, TextC, 76, 16, 400);
        TxtAt("Subtitle", bar, "NUST Kinecto Smart Jacket 2040 · energy · comfort · cuff tap", fMedium, 12, Subtitle, 77, 38.5f, 500);
        var badge = Node("SimBadge", bar); TL(badge, 520, 18, 87, 28); Ring(badge, Gold, 14);
        var bt = Txt("Text", badge, "SIMULATED", fExtra, 11, Gold, TextAlignmentOptions.Capline); Stretch(bt.rectTransform);

        // clock + live chip, centred on the screen
        var mid = Node("ClockGroup", bar);
        mid.anchorMin = mid.anchorMax = new Vector2(0.5f, 1); mid.pivot = new Vector2(0.5f, 1); mid.anchoredPosition = new Vector2(3.5f, -18); mid.sizeDelta = new Vector2(207, 28);
        var hl = mid.gameObject.AddComponent<HorizontalLayoutGroup>(); hl.spacing = 15; hl.childAlignment = TextAnchor.MiddleCenter;
        hl.childControlWidth = true; hl.childControlHeight = false; hl.childForceExpandWidth = false; hl.childForceExpandHeight = false;
        var fit = mid.gameObject.AddComponent<ContentSizeFitter>(); fit.horizontalFit = ContentSizeFitter.FitMode.PreferredSize;
        clock = Txt("Clock", mid, "10:42", fExtra, 26, TextC, TextAlignmentOptions.CaplineLeft); clock.rectTransform.sizeDelta = new Vector2(71, 28); clock.margin = new Vector4(0, 0, 0, 4.4f);
        liveChip = MakeChip("LiveChip", mid, ChipNavy, 28, 12, 12, 6, 8, fSemi, 12.5f, TextC, false); liveChip.dot.color = Green;

        // weather + app link, right side
        var right = Node("RightGroup", bar);
        right.anchorMin = right.anchorMax = new Vector2(1, 1); right.pivot = new Vector2(1, 1); right.anchoredPosition = new Vector2(-114, -18); right.sizeDelta = new Vector2(430, 28);
        var hr = right.gameObject.AddComponent<HorizontalLayoutGroup>(); hr.spacing = 29; hr.childAlignment = TextAnchor.MiddleRight;
        hr.childControlWidth = true; hr.childControlHeight = false; hr.childForceExpandWidth = false; hr.childForceExpandHeight = false;
        weatherChip = MakeChip("WeatherChip", right, ChipNavy, 28, 12, 12, 6, 8, fSemi, 12.5f, TextC, false); weatherChip.dot.color = Red;
        appChip = MakeChip("AppLinkChip", right, ChipNavy, 28, 12, 12, 6, 8, fSemi, 12.5f, TextC, false); appChip.dot.color = Green;
    }

    void BuildWorldLabels()
    {
        // energy callout (dot on the elbow, leader line, gold pill)
        calloutRT = Node("ElbowCallout", canvasRT); calloutRT.anchorMin = calloutRT.anchorMax = new Vector2(0, 0); calloutRT.pivot = new Vector2(0, 0.5f); calloutRT.sizeDelta = new Vector2(152, 28);
        Fill(calloutRT, Gold, 14);
        var cf = calloutRT.gameObject.AddComponent<HorizontalLayoutGroup>(); cf.padding = new RectOffset(12, 12, 0, 0); cf.childAlignment = TextAnchor.MiddleCenter;
        cf.childControlWidth = true; cf.childControlHeight = false; cf.childForceExpandWidth = false;
        var cfit = calloutRT.gameObject.AddComponent<ContentSizeFitter>(); cfit.horizontalFit = ContentSizeFitter.FitMode.PreferredSize;
        calloutText = Txt("Text", calloutRT, "+0.15 µJ elbow bend", fExtra, 13, Navy, TextAlignmentOptions.Capline); calloutText.rectTransform.sizeDelta = new Vector2(10, 28);
        calloutLine = Node("ElbowLine", canvasRT); calloutLine.anchorMin = calloutLine.anchorMax = Vector2.zero; calloutLine.pivot = new Vector2(0, 0.5f); Fill(calloutLine, Gold, 0);
        calloutDot = Node("ElbowDot", canvasRT); calloutDot.anchorMin = calloutDot.anchorMax = Vector2.zero; calloutDot.pivot = new Vector2(0.5f, 0.5f); calloutDot.sizeDelta = new Vector2(8, 8);
        var di = calloutDot.gameObject.AddComponent<Image>(); di.sprite = dotSprite; di.color = Gold; di.raycastTarget = false;

        playerLabel = MakeChip("PlayerLabel", canvasRT, PanelC.WithA(0.92f), 28, 12, 12, 6, 8, fSemi, 13.5f, TextC, true);
        playerLabelRT = playerLabel.root; playerLabelRT.anchorMin = playerLabelRT.anchorMax = Vector2.zero; playerLabelRT.pivot = new Vector2(0.5f, 0f);
        playerLabel.dot.color = Green;

        hubMarker = MakeChip("HubMarker", canvasRT, Gold, 28, 12, 12, 6, 8, fExtra, 13, Navy, true);
        hubMarker.root.anchorMin = hubMarker.root.anchorMax = Vector2.zero; hubMarker.root.pivot = new Vector2(0.5f, 0f);
        hubMarker.dot.color = Navy; hubMarker.root.gameObject.SetActive(false);

        ampChip = MakeChip("AmplifierChip", canvasRT, Teal, 28, 12, 12, 6, 8, fExtra, 13, Navy, true);
        ampChip.root.anchorMin = ampChip.root.anchorMax = Vector2.zero; ampChip.root.pivot = new Vector2(1f, 0.5f);
        ampChip.dot.color = Navy; ampChip.root.gameObject.SetActive(false);
    }

    void BuildBanner()
    {
        banner = Node("FaultBanner", canvasRT);
        banner.anchorMin = banner.anchorMax = new Vector2(0.5f, 1); banner.pivot = new Vector2(0.5f, 1); banner.anchoredPosition = new Vector2(0, -84); banner.sizeDelta = new Vector2(796, 56);
        Fill(banner, BannerBg, 14); var rr = Node("Border", banner); Stretch(rr); Ring(rr, Red, 14);
        var d = Node("Dot", banner); TL(d, 15, 24, 8, 8); var di = d.gameObject.AddComponent<Image>(); di.sprite = dotSprite; di.color = Red; di.raycastTarget = false;
        bannerTitle = TxtAt("Title", banner, "", fExtra, 15, TextC, 40, 13, 640);
        bannerSub = TxtAt("Sub", banner, "", fMedium, 12, Text2, 40, 33, 640);
        bannerFix = new Btn(); var fx = Node("Fix", banner); TL(fx, 706, 12, 76, 32);
        bannerFix.fill = Fill(fx, Red, 16); bannerFix.fill.raycastTarget = true; bannerFix.button = MakeButton(fx.gameObject, bannerFix.fill);
        var ft = Txt("Text", fx, "Fix", fExtra, 14, White, TextAlignmentOptions.Capline); Stretch(ft.rectTransform); bannerFix.title = ft;
        banner.gameObject.SetActive(false);
    }

    void BuildPanel()
    {
        panel = Node("Panel", canvasRT);
        panel.anchorMin = panel.anchorMax = new Vector2(1, 1); panel.pivot = new Vector2(1, 1); panel.anchoredPosition = new Vector2(-24, -84); panel.sizeDelta = new Vector2(420, 558);
        var bg = Fill(panel, PanelC.WithA(0.94f), 22); bg.raycastTarget = true;     // clicks on the panel don't fall through
        var border = Node("Border", panel); Stretch(border); Ring(border, LineC, 22);

        // tabs
        var tb = Node("TabBar", panel); TL(tb, 16, 16, 388, 44); Fill(tb, TabBarC, 22);
        tabPill = Node("ActivePill", tb); TL(tabPill, 4, 4, 380f / 3f, 36); Fill(tabPill, White, 18);
        string[] names = { "Energy", "Comfort", "Simulation" }; Color[] dots = { Gold, Red, Teal };
        for (int i = 0; i < 3; i++)
        {
            var t = Node("Tab" + i, tb); TL(t, 4 + i * 380f / 3f, 4, 380f / 3f, 36);
            var hit = t.gameObject.AddComponent<Image>(); hit.color = new Color(0, 0, 0, 0); hit.raycastTarget = true;
            var b = t.gameObject.AddComponent<Button>(); b.transition = Selectable.Transition.None; b.navigation = new Navigation { mode = Navigation.Mode.None };
            int k = i; if (Application.isPlaying) b.onClick.AddListener(() => ShowTab(k));
            var g = Node("Label", t); Stretch(g);
            var hl = g.gameObject.AddComponent<HorizontalLayoutGroup>(); hl.spacing = 8; hl.childAlignment = TextAnchor.MiddleCenter;
            hl.childControlWidth = true; hl.childControlHeight = false; hl.childForceExpandWidth = false;
            var d = Node("Dot", g); d.sizeDelta = new Vector2(7, 7); var di = d.gameObject.AddComponent<Image>(); di.sprite = dotSprite; di.color = dots[i]; di.raycastTarget = false;
            d.gameObject.AddComponent<LayoutElement>().preferredWidth = 7;
            tabText[i] = Txt("Text", g, names[i], fSemi, 14.5f, Text2, TextAlignmentOptions.CaplineLeft); tabText[i].rectTransform.sizeDelta = new Vector2(10, 36);
        }

        // ---------------- page 0: Energy
        var p = pages[0] = Page("PageEnergy");
        TxtAt("Label", p, "Energy made today", fSemi, 13, Text2, 24, 87, 300);
        energyBig = TxtAt("Big", p, "0.00", fExtra, 60, TextC, 24, 119, 300); energyBig.characterSpacing = -2f;
        energyUnit = TxtAt("Unit", p, "mJ", fBold, 24, Text2, 177, 146, 80);
        energyNow = TxtAt("Now", p, "", fBold, 14, Gold, 24, 186, 372);
        Box("Sep", p, 24, 220, 372, 1, LineC, 0);
        TxtAt("CuffLabel", p, "Cuff light", fSemi, 14, TextC, 24, 242, 200);
        cuffPct = TxtAt("CuffPct", p, "0%", fExtra, 14, Gold, 196, 242, 200, TextAlignmentOptions.CaplineRight);
        Box("CuffTrack", p, 24, 264, 372, 14, Track, 7);
        cuffFill = Box("CuffFill", p, 24, 264, 14, 14, Gold, 7);
        cuffHint = TxtAt("CuffHint", p, "Keep moving: it lights up at 100%", fMedium, 12, Text3, 24, 289, 372);
        TxtAt("ChargeLabel", p, "What are you charging?", fSemi, 14, TextC, 24, 326, 240);
        var sb = Node("SpecBadge", p); TL(sb, 264, 320, 132, 22); Ring(sb, Teal, 11);
        var sbt = Txt("Text", sb, "2040 · SPECULATIVE", fExtra, 11.5f, Teal, TextAlignmentOptions.Capline); Stretch(sbt.rectTransform);
        string[] dt = { "Phone", "Earbuds", "Watch", "Nothing" }, ds = { "in pocket", "case", "band", "light only" };
        devBtns = new Btn[4];
        for (int i = 0; i < 4; i++) devBtns[i] = MakeBtn("Dev" + dt[i], p, 24 + i * 95, 350, 87, 60, dt[i], ds[i], 17, 35, 14, 11);
        devLabel = TxtAt("DevLabel", p, "Earbuds", fSemi, 14, TextC, 24, 432, 200);
        devPct = TxtAt("DevPct", p, "0%", fExtra, 14, Teal, 196, 432, 200, TextAlignmentOptions.CaplineRight);
        devBarRT = Box("DevTrack", p, 24, 454, 372, 14, Track, 7).rectTransform;
        devFill = Box("DevFill", p, 24, 454, 14, 14, Teal, 7);
        devHint = TxtAt("DevHint", p, "", fMedium, 12, Text3, 24, 479, 372);
        footnote = Txt("Footnote", p, "Charging uses the speculative 2040 Kinecto Amplifier. Today's real jacket only lights the cuff.", fMedium, 11, Text3, TextAlignmentOptions.TopLeft);
        footnote.textWrappingMode = TextWrappingModes.Normal; TL(footnote.rectTransform, 24, 515 - 0.293f * 11, 372, 40);

        // ---------------- page 1: Comfort
        p = pages[1] = Page("PageComfort");
        TxtAt("InsideLabel", p, "Inside the jacket", fSemi, 13, Text2, 24, 87, 190);
        TxtAt("OutsideLabel", p, "Outside", fSemi, 13, Text2, 221, 87, 170);
        insideBig = TxtAt("InsideBig", p, "--°", fExtra, 56, TextC, 24, 117, 190); insideBig.characterSpacing = -2f;
        outsideBig = TxtAt("OutsideBig", p, "--°", fExtra, 56, Red, 221, 117, 175); outsideBig.characterSpacing = -2f;
        statusBg = Box("Status", p, 24, 178, 372, 40, StatusBlue, 12);
        var sd = Node("Dot", statusBg.transform); TL(sd, 16, 16, 8, 8); statusDot = sd.gameObject.AddComponent<Image>(); statusDot.sprite = dotSprite; statusDot.color = Blue; statusDot.raycastTarget = false;
        statusText = TxtAt("Text", statusBg.transform, "", fSemi, 15, Blue, 32, 14.5f, 340);
        TxtAt("WeatherLabel", p, "What is the weather like?", fSemi, 14, TextC, 24, 242, 372);
        string[] wt = { "Cold", "Mild", "Hot", "Real day" }, ws = { "6 °C", "21 °C", "35 °C", "follows clock" };
        weatherBtns = new Btn[4];
        for (int i = 0; i < 4; i++) weatherBtns[i] = MakeBtn("Weather" + i, p, 24 + i * 95, 262, 87, 56, wt[i], ws[i], 15, 33, 14, 10.5f);
        TxtAt("ModeLabel", p, "What should the jacket do?", fSemi, 14, TextC, 24, 342, 372);
        string[] mt = { "Auto", "Cool", "Warm", "Off" }, ms = { "comfy", "fan on", "heater on", "nothing" };
        modeBtns = new Btn[4];
        for (int i = 0; i < 4; i++) modeBtns[i] = MakeBtn("Mode" + mt[i], p, 24 + i * 95, 362, 87, 56, mt[i], ms[i], 15, 33, 14, 10.5f);
        Box("Sep", p, 24, 438, 372, 1, LineC, 0);
        TxtAt("RangeLabel", p, "Your comfort range", fSemi, 12, Text2, 24, 455, 250);
        TxtAt("BatteryLabel", p, "Battery", fSemi, 12, Text2, 246, 455, 150, TextAlignmentOptions.CaplineRight);
        rangeText = TxtAt("Range", p, "", fSemi, 14, TextC, 24, 472, 300);
        batteryText = TxtAt("Battery", p, "", fExtra, 14, Green, 246, 472, 150, TextAlignmentOptions.CaplineRight);

        // ---------------- page 2: Simulation
        p = pages[2] = Page("PageSimulation");
        TxtAt("PlayLabel", p, "Play a whole school day", fSemi, 14, TextC, 24, 88, 372);
        playBtn = new Btn(); var pb = Node("Play", p); TL(pb, 24, 108, 372, 56);
        playBtn.fill = Fill(pb, Gold, 14); playBtn.fill.raycastTarget = true; playBtn.button = MakeButton(pb.gameObject, playBtn.fill);
        playText = Txt("Text", pb, "", fExtra, 16.5f, Navy, TextAlignmentOptions.Capline); Stretch(playText.rectTransform);
        speedBtns = new[] { MakeBtn("SpeedFast", p, 24, 172, 182, 52, "Fast", "about 20 min", 13, 31, 14, 11),
                            MakeBtn("SpeedVeryFast", p, 214, 172, 182, 52, "Very fast", "about 5 min", 13, 31, 14, 11) };
        TxtAt("SpeedHint", p, "Walk with W A S D any time to take over again", fMedium, 12, Text3, 24, 237, 372);
        Box("Sep", p, 24, 266, 372, 1, LineC, 0);
        TxtAt("FaultLabel", p, "Test a fault", fSemi, 14, TextC, 24, 286, 200);
        var ab = Node("AlertBadge", p); TL(ab, 243, 280, 153, 22); Ring(ab, Red, 11);
        var abt = Txt("Text", ab, "ALERT GOES TO THE APP", fExtra, 11, Red, TextAlignmentOptions.Capline); Stretch(abt.rectTransform);
        faultBtns = new Btn[6];
        for (int i = 0; i < 6; i++) faultBtns[i] = MakeBtn("Fault" + i, p, 24 + (i % 2) * 190, 310 + (i / 2) * 60, 182, 52, FaultTitle[i], FaultSub[i], 13, 31, 14, 11);
        fixAllBtn = new Btn(); var fa = Node("FixEverything", p); TL(fa, 24, 504, 372, 44);
        fixAllBtn.fill = Fill(fa, new Color(1, 1, 1, 0.001f), 14); fixAllBtn.fill.raycastTarget = true;
        var far = Node("Border", fa); Stretch(far); Ring(far, LineC, 14);
        fixAllBtn.button = MakeButton(fa.gameObject, fixAllBtn.fill);
        var fat = Txt("Text", fa, "Fix everything", fBold, 14, TextC, TextAlignmentOptions.Capline); Stretch(fat.rectTransform);
    }

    void BuildKeyBar()
    {
        var kb = Node("KeyBar", canvasRT);
        kb.anchorMin = kb.anchorMax = new Vector2(0.5f, 0); kb.pivot = new Vector2(0.5f, 0); kb.anchoredPosition = new Vector2(0, 24); kb.sizeDelta = new Vector2(692, 44);
        Fill(kb, PanelC.WithA(0.9f), 22);
        var hl = kb.gameObject.AddComponent<HorizontalLayoutGroup>(); hl.padding = new RectOffset(14, 14, 0, 0); hl.spacing = 0; hl.childAlignment = TextAnchor.MiddleCenter;
        hl.childControlWidth = true; hl.childControlHeight = false; hl.childForceExpandWidth = false; hl.childForceExpandHeight = false;
        var fit = kb.gameObject.AddComponent<ContentSizeFitter>(); fit.horizontalFit = ContentSizeFitter.FitMode.PreferredSize;
        void Cap(string s, float w) { var c = Node("Key " + s, kb); c.sizeDelta = new Vector2(w, 28); c.gameObject.AddComponent<LayoutElement>().preferredWidth = w;
            Fill(c, CapLine, 6); var f = Node("Fill", c); Stretch(f, 1); Fill(f, CapFill, 5);
            var t = Txt("Text", c, s, fExtra, 11, TextC, TextAlignmentOptions.Capline); Stretch(t.rectTransform); }
        void Gap(float w) { var g = Node("Gap", kb); g.sizeDelta = new Vector2(w, 1); g.gameObject.AddComponent<LayoutElement>().preferredWidth = w; }
        TextMeshProUGUI Label(string s) { var t = Txt("Label " + s, kb, s, fSemi, 13, Text2, TextAlignmentOptions.CaplineLeft); t.rectTransform.sizeDelta = new Vector2(10, 28); return t; }
        Cap("W", 26); Gap(4); Cap("A", 26); Gap(4); Cap("S", 26); Gap(4); Cap("D", 26); Gap(9); Label("Move"); Gap(22);
        Cap("Shift", 46); Gap(9); Label("Run"); Gap(22);
        Cap("Space", 54); Gap(9); Label("Jump"); Gap(22);
        Cap("E", 26); Gap(9); Label("Tap cuff"); Gap(22);
        Cap("Q", 26); Gap(9); Label("Comfort mode"); Gap(22);
        Cap("Tab", 46); Gap(9); keyHideLabel = Label("Show panels");
    }

    // ================================================================== wiring
    void Wire()
    {
        devBtns[0].button.onClick.AddListener(() => amp.ChoosePhone());
        devBtns[1].button.onClick.AddListener(() => amp.ChooseEarbuds());
        devBtns[2].button.onClick.AddListener(() => amp.ChooseWatch());
        devBtns[3].button.onClick.AddListener(() => amp.ChooseNothing());
        weatherBtns[0].button.onClick.AddListener(lab.WeatherCold);
        weatherBtns[1].button.onClick.AddListener(lab.WeatherMild);
        weatherBtns[2].button.onClick.AddListener(lab.WeatherHot);
        weatherBtns[3].button.onClick.AddListener(lab.WeatherRealDay);
        modeBtns[0].button.onClick.AddListener(lab.ModeAuto);
        modeBtns[1].button.onClick.AddListener(lab.ModeCool);
        modeBtns[2].button.onClick.AddListener(lab.ModeWarm);
        modeBtns[3].button.onClick.AddListener(lab.ModeOff);
        playBtn.button.onClick.AddListener(() => { if (lab.ScheduleRunning) lab.StopSchoolDay(); else lab.PlaySchoolDay(); });
        speedBtns[0].button.onClick.AddListener(lab.SetSpeedFast);
        speedBtns[1].button.onClick.AddListener(lab.SetSpeedVeryFast);
        faultBtns[0].button.onClick.AddListener(faults.BodySensorOffline);
        faultBtns[1].button.onClick.AddListener(faults.HeaterOverLimit);
        faultBtns[2].button.onClick.AddListener(() => { faults.BlowerCurrentSpike(); if (!thermal.blowerOn) lab.ModeCool(); });
        faultBtns[3].button.onClick.AddListener(faults.BufferNotCharging);
        faultBtns[4].button.onClick.AddListener(faults.CuffTagUnreadable);
        faultBtns[5].button.onClick.AddListener(faults.BatteryHot);
        fixAllBtn.button.onClick.AddListener(FixEverything);
        bannerFix.button.onClick.AddListener(BookRepair);
    }

    /// Banner "Fix": book a repair at the Kinecto Hub (the alert already went to the phone app).
    public void BookRepair()
    {
        HubStation.RepairBooked = true;
        ShowToast("Fix booked · walk to the Kinecto Hub · follow the gold marker", Gold);
    }

    void FixEverything()
    {
        bool wasHeater = faults.ActiveFlags.Contains("heater_over_limit");
        faults.ClearAll();
        if (wasHeater) lab.ModeAuto();
    }

    // ================================================================== per frame
    void Update()
    {
        if (!lab || canvasRT == null) return;
        if (LabInput.PanelPressed) TogglePanel();

        // top bar
        clock.text = lab.ClockText;
        if (lab.ScheduleRunning) { liveChip.text.text = $"Day mode · ×{lab.TimeSpeed:0.#}"; liveChip.dot.color = Gold; }
        else { liveChip.text.text = "Live · real time"; liveChip.dot.color = Green; }
        float outside = lab.OutsideNowC;
        weatherChip.text.text = $"{outside:0} °C · {lab.WeatherLabel}";
        weatherChip.dot.color = TempColour(outside, Gold);
        UpdateAppChip();

        // mini chip / toast
        bool toast = Time.time < toastUntil;
        toastChip.root.gameObject.SetActive(toast);
        // panels hidden: today's energy + inside temperature; panels open: the last cuff tap (as in the design)
        bool showTap = panelVisible && !string.IsNullOrEmpty(ReaderStation.LastTapText);
        miniChip.root.gameObject.SetActive(!toast && (!panelVisible || showTap));
        miniChip.text.text = showTap ? ReaderStation.LastTapText
                                     : $"{harvest.harvestedJ * 1e3:0.00} mJ today · {(thermal.sensorFault ? "--" : thermal.insideC.ToString("0"))}° inside";
        miniChip.dot.color = showTap ? Green : Gold;

        UpdateBanner();
        UpdateWorldLabels();
        if (panelVisible)
        {
            if (tab == 0) UpdateEnergy(); else if (tab == 1) UpdateComfort(); else UpdateSimulation();
        }
    }

    static Color TempColour(float c, Color mid) => c >= 30f ? Red : c <= 12f ? Blue : mid;

    void UpdateAppChip()
    {
        if (!bridge) { appChip.text.text = $"App link · off · {jacketId}"; appChip.dot.color = Text2; return; }
        string s = bridge.lastStatus ?? "";
        if (s.StartsWith("sent") || s.StartsWith("tap")) { appChip.text.text = $"App link · sent {bridge.sent} · {jacketId}"; appChip.dot.color = Green; }
        else if (s.StartsWith("offline") || s.StartsWith("not connected")) { appChip.text.text = $"App link · offline · {jacketId}"; appChip.dot.color = Text2; }
        else { appChip.text.text = $"App link · retrying · {jacketId}"; appChip.dot.color = Red; }
    }

    void UpdateBanner()
    {
        var active = faults.ActiveFlags;
        foreach (var f in active) if (!faultSince.ContainsKey(f)) faultSince[f] = Time.time;
        foreach (var k in faultSince.Keys.ToList()) if (!active.Contains(k)) faultSince.Remove(k);
        bool show = faultSince.Count > 0;
        banner.gameObject.SetActive(show);
        if (!show) return;
        var first = faultSince.OrderBy(kv => kv.Value).First();
        int idx = System.Array.IndexOf(FaultIds, first.Key);
        bannerTitle.text = idx >= 0 ? FaultBanner[idx] : first.Key;
        int secs = Mathf.Max(0, Mathf.FloorToInt(Time.time - first.Value));
        bool linked = bridge && bridge.sent > 0 && !(bridge.lastStatus ?? "").StartsWith("offline");
        bannerSub.text = HubStation.RepairBooked ? "Repair booked at the Kinecto Hub · follow the gold marker"
                       : linked ? $"Alert sent to the phone app {secs} s ago · book a fix there"
                                : $"Alert raised {secs} s ago · goes to the phone app when the app link is on";
        bannerFix.title?.SetText(HubStation.RepairBooked ? "Booked" : "Fix");
    }

    void UpdateWorldLabels()
    {
        bool vis = cam && player;
        Vector2 head = Vector2.zero;
        if (vis) vis = ToCanvas(player.position + Vector3.up * 1.95f, out head);
        playerLabelRT.gameObject.SetActive(vis);
        if (vis)
        {
            var near = ReaderStation.Nearest; var hubSt = HubStation.Nearest;
            if (hubSt) { playerLabel.text.text = hubSt.kind == HubStation.Kind.Repair ? $"{hubSt.label} · press E to repair your jacket" : $"{hubSt.label} · press E to scan your jacket"; playerLabel.dot.color = Teal; }
            else if (near) { playerLabel.text.text = $"{near.roomName} · {near.Prompt}"; playerLabel.dot.color = Gold; }
            else
            {
                string act = lab.CurrentActivity;
                string word = act == "walk" ? "walking" : act == "run" ? "running" : act == "brisk" ? "walking fast" : act == "seated" ? "sitting" : "standing";
                playerLabel.text.text = lab.LiveSpeed > 0.1f ? $"You · {word} · {lab.LiveSpeed:0.0} m/s" : $"You · {word}";
                if (lab.ScheduleRunning) playerLabel.text.text += " · day mode";
                playerLabel.dot.color = Green;
            }
            float canvasH = canvasRT.rect.height;
            float minTop = banner.gameObject.activeSelf ? 156f : 76f;            // stay under the top bar / fault banner
            float y = Mathf.Min(head.y, canvasH - minTop - 28f);
            playerLabelRT.anchoredPosition = new Vector2(head.x, y);
        }

        UpdateHubMarker();

        // amplifier (2040, speculative): the harvested movement, amplified and used
        Vector2 hip = Vector2.zero, bodyC = Vector2.zero;
        bool ampOn = vis && amp && amp.PowerW > 0.01f && ToCanvas((pocket ? pocket.position : player.position + Vector3.up * 0.95f), out hip) && ToCanvas(player.position + Vector3.up * 1.2f, out bodyC);
        ampChip.root.gameObject.SetActive(ampOn);
        if (ampOn)
        {
            ampChip.text.text = $"Amplifier 2040 · {amp.PowerW:0.0} W → {amp.Destination}";
            // opposite side of the energy callout, kept fully on screen
            float cs = (gait && elbow && ToCanvas(elbow.position, out var el)) ? Mathf.Sign(el.x - bodyC.x) : 1f;
            float aside = -cs; float wChip = ampChip.root.rect.width;
            ampChip.root.pivot = new Vector2(aside < 0 ? 1f : 0f, 0.5f);
            float x = bodyC.x + aside * 60f;
            x = aside < 0 ? Mathf.Clamp(x, wChip + 16f, canvasRT.rect.width - 16f) : Mathf.Clamp(x, 16f, canvasRT.rect.width - wChip - 16f);
            ampChip.root.anchoredPosition = new Vector2(x, Mathf.Clamp(hip.y - 10f, 90f, canvasRT.rect.height - 160f));
        }

        // energy callout: the jacket zone that just made electricity
        bool show = vis && gait && Time.time - gait.LastBendTime < 1.4f;
        Transform src = !gait ? elbow : gait.LastSource == 1 ? (shoulder ? shoulder : elbow) : gait.LastSource == 2 || gait.LastSource == 3 || gait.LastSource == 5 ? (backPanel ? backPanel : elbow) : elbow;
        Vector2 e = Vector2.zero, body = Vector2.zero;
        if (show) show = src && ToCanvas(src.position, out e) && ToCanvas(player.position + Vector3.up * 1.2f, out body);
        calloutRT.gameObject.SetActive(show); calloutLine.gameObject.SetActive(show); calloutDot.gameObject.SetActive(show);
        if (!show) return;
        double uj = gait.LastBendJ * 1e6;
        calloutText.text = $"+{uj.ToString(uj >= 1 ? "0.0" : "0.00")} µJ {GaitHarvestFallback.Sources[gait.LastSource]}";
        float side = e.x >= body.x ? 1f : -1f;
        calloutDot.anchoredPosition = e;
        Vector2 pillAnchor = e + new Vector2(45f * side, 30f);
        calloutRT.pivot = new Vector2(side > 0 ? 0f : 1f, 0.5f);
        float cw = calloutRT.rect.width;
        pillAnchor.x = side > 0 ? Mathf.Min(pillAnchor.x, canvasRT.rect.width - cw - 16f) : Mathf.Max(pillAnchor.x, cw + 16f);
        calloutRT.anchoredPosition = pillAnchor;
        Vector2 d = pillAnchor - e;
        calloutLine.anchoredPosition = e; calloutLine.sizeDelta = new Vector2(d.magnitude, 2f);
        calloutLine.localRotation = Quaternion.Euler(0, 0, Mathf.Atan2(d.y, d.x) * Mathf.Rad2Deg);
    }

    void UpdateHubMarker()
    {
        bool on = HubStation.RepairBooked && hubTarget && cam && player && faults.ActiveFlags.Count > 0;
        if (!on && HubStation.RepairBooked && faults.ActiveFlags.Count == 0) HubStation.RepairBooked = false;
        hubMarker.root.gameObject.SetActive(on);
        if (!on) return;
        float dist = Vector3.Distance(player.position, hubTarget.position);
        hubMarker.text.text = dist < 6f ? "Kinecto Hub · go inside to the repair bench" : $"Kinecto Hub · {dist:0} m";
        Vector3 s = cam.WorldToScreenPoint(hubTarget.position + Vector3.up * 4f);
        float kx = canvasRT.rect.width / Mathf.Max(1, Screen.width), ky = canvasRT.rect.height / Mathf.Max(1, Screen.height);
        Vector2 p = new Vector2(s.x * kx, s.y * ky);
        if (s.z < 0f) p = new Vector2(canvasRT.rect.width - p.x, 0f);                 // behind: pin to the bottom edge
        float w = hubMarker.root.rect.width * 0.5f + 16f;
        p.x = Mathf.Clamp(p.x, w, canvasRT.rect.width - w);
        p.y = Mathf.Clamp(p.y, 96f, canvasRT.rect.height - 150f);
        hubMarker.root.anchoredPosition = p;
    }

    bool ToCanvas(Vector3 world, out Vector2 p)
    {
        Vector3 s = cam.WorldToScreenPoint(world);
        p = Vector2.zero;
        if (s.z <= 0.05f) return false;
        float k = canvasRT.rect.width / Mathf.Max(1, Screen.width);
        p = new Vector2(s.x * k, s.y * (canvasRT.rect.height / Mathf.Max(1, Screen.height)));
        return true;
    }

    void UpdateEnergy()
    {
        energyBig.text = (harvest.harvestedJ * 1e3).ToString("0.00");
        var eu = energyUnit.rectTransform; eu.anchoredPosition = new Vector2(24f + energyBig.preferredWidth + 13f, eu.anchoredPosition.y);
        string act = lab.CurrentActivity;
        string verb = act == "walk" ? "Walking" : act == "run" ? "Running" : act == "brisk" ? "Walking fast" : act == "seated" ? "Sitting" : "Standing";
        energyNow.text = $"{verb} now · about {lab.PowerMicroW:0.0} µW";
        float pct = Mathf.Clamp01(harvest.BufferVoltage / 4.0f);
        SetBar(cuffFill, pct);
        if (harvest.statusLightOn) { cuffPct.text = "ON"; cuffHint.text = $"The cuff light is on · {harvest.lightSeconds / 60.0:0.0} min today"; }
        else { cuffPct.text = $"{pct * 100f:0}%"; cuffHint.text = "Keep moving: it lights up at 100%"; }
        if (faults.ActiveFlags.Contains("buffer_not_charging")) cuffHint.text = "Not charging · the buffer is not filling";

        for (int i = 0; i < 4; i++) Style(devBtns[i], (int)amp.device == i, Teal, Navy, Navy);
        bool none = amp.device == ChargeDevice.Nothing;
        devLabel.text = none ? "Nothing plugged in" : amp.DeviceName;
        devPct.text = none ? "" : $"{amp.percent:0}%";
        devBarRT.gameObject.SetActive(!none); devFill.gameObject.SetActive(!none);
        if (!none) SetBar(devFill, amp.percent / 100f);
        devHint.text = amp.HintText;
        var sj = gait ? gait.SourceJ : new double[6];
        footnote.text = $"Made from: elbows {sj[0] * 1e3:0.00} · shoulders {sj[1] * 1e3:0.00} · back {sj[2] * 1e3:0.00} · twists {(sj[3] + sj[4]) * 1e3:0.00} · jumps {sj[5] * 1e3:0.00} mJ. " +
                        $"Amplified (speculative 2040 Kinecto Amplifier) {amp.PowerW:0.0} W → {amp.Destination}; today's real jacket only lights the cuff.";
    }

    void UpdateComfort()
    {
        insideBig.text = thermal.sensorFault ? "--°" : $"{thermal.insideC:0}°";
        outsideBig.text = $"{thermal.ambientC:0}°";
        outsideBig.color = TempColour(thermal.ambientC, TextC);
        if (thermal.sensorFault) SetStatus("Body sensor stopped · heating off for safety", Red, StatusRed);
        else if (thermal.heaterOn) SetStatus(faults.ActiveFlags.Contains("heater_over_limit") ? "Heater over the limit · switching off" : "Warming you up · heater on", Red, StatusRed);
        else if (thermal.blowerOn) SetStatus(faults.ActiveFlags.Contains("blower_current_spike") ? "Fan blocked · current spike" : "Cooling you down · fan on", Blue, StatusBlue);
        else if (thermal.mode == ComfortMode.Off) SetStatus("Jacket off · nothing running", Text2, StatusGrey);
        else SetStatus("Comfy · nothing needs to run", Green, StatusGreen);

        int w = (int)lab.Weather;
        for (int i = 0; i < 4; i++)
        {
            Color sel = i == 0 ? Blue : i == 2 ? Red : White;
            Color txt = i == 0 || i == 2 ? White : Navy;
            Style(weatherBtns[i], w == i, sel, txt, txt);
        }
        for (int i = 0; i < 4; i++) Style(modeBtns[i], (int)thermal.mode == i, White, Navy, Navy);
        rangeText.text = $"{lab.warmBelowC:0} – {lab.coolAboveC:0} °C · set in phone app";
        float bat = thermal.BatteryLeftPct;
        batteryText.text = $"{bat:0}%";
        batteryText.color = bat > 40f ? Green : bat > 15f ? Gold : Red;
    }

    void UpdateSimulation()
    {
        playText.text = lab.ScheduleRunning ? $"<size=12>■</size>  Stop · day mode {lab.ClockText}" : "<size=15>▶</size>  Play 07:30 – 17:00";
        Style(speedBtns[0], lab.SpeedChoice == 0, White, Navy, Navy);
        Style(speedBtns[1], lab.SpeedChoice == 1, White, Navy, Navy);
        for (int i = 0; i < 6; i++) Style(faultBtns[i], faults.ActiveFlags.Contains(FaultIds[i]), Red, White, Text2);
    }

    void SetStatus(string text, Color fg, Color bg) { statusText.text = text; statusText.color = fg; statusDot.color = fg; statusBg.color = bg; }

    static void SetBar(Image fill, float pct)
    {
        var r = fill.rectTransform;
        r.sizeDelta = new Vector2(Mathf.Lerp(0f, 372f, Mathf.Clamp01(pct)), 14f);
        fill.enabled = pct > 0.001f;
        if (r.sizeDelta.x < 14f && fill.enabled) r.sizeDelta = new Vector2(14f, 14f);
    }

    static void Style(Btn b, bool selected, Color selFill, Color selTitle, Color selSub)
    {
        b.fill.color = selected ? selFill : ButtonC;
        b.border.color = selected ? selFill : LineC;
        b.title.color = selected ? selTitle : TextC;
        b.sub.color = selected ? selSub : Text2;
    }

    // ================================================================== UI helpers
    static RectTransform Node(string name, Transform parent)
    {
        var go = new GameObject(name, typeof(RectTransform)); go.layer = 5;
        go.transform.SetParent(parent, false); return (RectTransform)go.transform;
    }
    static void TL(RectTransform r, float x, float y, float w, float h)
    {
        r.anchorMin = r.anchorMax = new Vector2(0, 1); r.pivot = new Vector2(0, 1);
        r.anchoredPosition = new Vector2(x, -y); r.sizeDelta = new Vector2(w, h);
    }
    static void Stretch(RectTransform r, float inset = 0f)
    {
        r.anchorMin = Vector2.zero; r.anchorMax = Vector2.one; r.pivot = new Vector2(0.5f, 0.5f);
        r.offsetMin = new Vector2(inset, inset); r.offsetMax = new Vector2(-inset, -inset);
    }
    RectTransform Page(string name) { var p = Node(name, panel); Stretch(p); return p; }

    Image Fill(RectTransform r, Color c, float radius)
    {
        var im = r.gameObject.AddComponent<Image>(); im.color = c; im.raycastTarget = false;
        if (radius > 0f) { im.sprite = rounded; im.type = Image.Type.Sliced; im.pixelsPerUnitMultiplier = 32f / radius; }
        return im;
    }
    Image Ring(RectTransform r, Color c, float radius)
    {
        var im = r.gameObject.AddComponent<Image>(); im.color = c; im.raycastTarget = false;
        im.sprite = radius >= 20 ? ring22 : radius >= 13 ? ring14 : ring11; im.type = Image.Type.Sliced; im.fillCenter = true; im.pixelsPerUnitMultiplier = 1f;
        return im;
    }
    Image Box(string name, Transform p, float x, float y, float w, float h, Color c, float radius) { var r = Node(name, p); TL(r, x, y, w, h); return Fill(r, c, radius); }

    TextMeshProUGUI Txt(string name, Transform p, string s, TMP_FontAsset f, float size, Color c, TextAlignmentOptions a)
    {
        var r = Node(name, p); var t = r.gameObject.AddComponent<TextMeshProUGUI>();
        t.font = f; t.fontSize = size; t.color = c; t.alignment = a; t.textWrappingMode = TextWrappingModes.NoWrap;
        t.overflowMode = TextOverflowModes.Overflow; t.raycastTarget = false; t.richText = true; t.text = s; return t;
    }
    /// Text whose capital letters start at capTop (design measurements are cap tops).
    TextMeshProUGUI TxtAt(string name, Transform p, string s, TMP_FontAsset f, float size, Color c, float x, float capTop, float w, TextAlignmentOptions a = TextAlignmentOptions.CaplineLeft)
    {
        var t = Txt(name, p, s, f, size, c, a); float h = Mathf.Ceil(size * 1.6f);
        TL(t.rectTransform, x, capTop + 0.3725f * size - h / 2f, w, h); return t;
    }

    Chip MakeChip(string name, Transform parent, Color bg, float h, int padL, int padR, float gap, float dot, TMP_FontAsset f, float size, Color tc, bool fit)
    {
        var c = new Chip { root = Node(name, parent) };
        c.root.sizeDelta = new Vector2(100, h);
        c.bg = Fill(c.root, bg, h / 2f);
        var hl = c.root.gameObject.AddComponent<HorizontalLayoutGroup>(); hl.padding = new RectOffset(padL, padR, 0, 0); hl.spacing = gap;
        hl.childAlignment = TextAnchor.MiddleLeft; hl.childControlWidth = true; hl.childControlHeight = false; hl.childForceExpandWidth = false; hl.childForceExpandHeight = false;
        if (fit) { var csf = c.root.gameObject.AddComponent<ContentSizeFitter>(); csf.horizontalFit = ContentSizeFitter.FitMode.PreferredSize; }
        var d = Node("Dot", c.root); d.sizeDelta = new Vector2(dot, dot); c.dot = d.gameObject.AddComponent<Image>(); c.dot.sprite = dotSprite; c.dot.raycastTarget = false;
        d.gameObject.AddComponent<LayoutElement>().preferredWidth = dot;
        c.text = Txt("Text", c.root, "", f, size, tc, TextAlignmentOptions.CaplineLeft); c.text.rectTransform.sizeDelta = new Vector2(10, h);
        return c;
    }

    Btn MakeBtn(string name, Transform p, float x, float y, float w, float h, string title, string sub, float titleCap, float subCap, float titleSize, float subSize)
    {
        var b = new Btn(); var r = Node(name, p); TL(r, x, y, w, h);
        b.border = Fill(r, LineC, 14);
        var f = Node("Fill", r); Stretch(f, 1); b.fill = Fill(f, ButtonC, 13); b.fill.raycastTarget = true;
        b.button = MakeButton(r.gameObject, b.fill);
        b.title = TxtAt("Title", r, title, fExtra, titleSize, TextC, 0, titleCap, w, TextAlignmentOptions.Capline);
        b.sub = TxtAt("Sub", r, sub, fMedium, subSize, Text2, 0, subCap, w, TextAlignmentOptions.Capline);
        return b;
    }

    static Button MakeButton(GameObject go, Graphic target)
    {
        var b = go.AddComponent<Button>(); b.targetGraphic = target; b.navigation = new Navigation { mode = Navigation.Mode.None };
        var cb = b.colors; cb.normalColor = Color.white; cb.highlightedColor = new Color(0.9f, 0.9f, 0.9f); cb.pressedColor = new Color(0.75f, 0.75f, 0.75f);
        cb.selectedColor = Color.white; cb.fadeDuration = 0.08f; b.colors = cb; return b;
    }
}

static class LabHudColorExt { public static Color WithA(this Color c, float a) { c.a = a; return c; } }
