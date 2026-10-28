# NUST Kinecto Smart Jacket 2040

**A modular, energy-harvesting smart jacket concept for a regenerative NUST Windhoek campus.**

Kinecto explores how wearable technology could support student attendance and thermal comfort while respecting privacy, enabling local repair, and using movement to harvest small amounts of energy. The project uses MATLAB and Unity simulations to investigate the design and future  artefact.

---

## Features

**For students**

- **MOVE — energy harvesting:** Textile zones at the elbows, sides, and shoulders capture small pulses of energy from walking and arm movement to power a jacket status bar.
- **TAP — attendance:** A passive, batteryless NFC chip in the wrist cuff is intentionally tapped at a classroom reader. The design does not use continuous location tracking.
- **SENSE — thermal comfort:** Temperature sensors monitor conditions inside and outside the jacket. A control system can activate a fan when the wearer is too warm or a heating pad when they are cold.
- **Manual control:** An app lets the wearer turn the thermal system off or override its automatic behavior.

**For maintenance and sustainability**

- Electronics are housed in a removable pod secured with screws rather than glue.
- The electronics pod can be removed before washing the jacket and designed for component replacement at the NUST FabLab.
- The modular design aims to support local repair and reduce electronic waste.

---

## Human-centred design principles

| Principle | How the design applies it |
| --- | --- |
| Privacy | Attendance is recorded only when the wearer intentionally taps the cuff at a reader; there is no continuous location tracking. |
| Autonomy | The wearer can manually switch off or override thermal controls. |
| Repairability | A removable, screw-fastened electronics pod makes the electronics easier to access and replace. |
| Sustainability | The concept explores harvesting energy from ordinary movement and keeping components repairable. |
| Safety | Thermal control is designed around a stated 42 °C cutoff threshold; this value is a configuration default, not a validated safety certification. |

---

## Simulation and technology

| Area | Technology or design |
| --- | --- |
| Movement and energy model | MATLAB simulations of walking, arm swinging, and elbow bending, alongside energy-capture estimates and thermal-system power budgets |
| Interactive environment | Unity scene for student movement, classroom-door attendance interactions, and thermal microclimate visualization |
| Thermal-control prototype | ESP32-C3, dual temperature sensors, and MOSFET-controlled loads (planned firmware) |
| Attendance concept | Passive NFC tag in the jacket cuff and a classroom reader |
| Removable enclosure | FreeCAD design and STL files for a 3D-printed electronics pod |

The simulations are intended to help evaluate design choices. They do not, by themselves, establish the performance or safety of a physical garment.

---

## Repository structure

```text
KINECTO-CHARGE-2040/
├─ Kinecto_Virtual_Lab/  Unity Virtual Lab: campus, student avatar, virtual jacket, door readers
├─ app/                  Kinecto Care companion app (Flutter)
├─ attendance/           Attendance website (HTML, CSS, JavaScript)
├─ supabase/             Shared backend: database, live sync and device Edge Functions
├─ firmware/             ESP32-C3 thermal firmware and Wokwi simulation
├─ services/             Python fault engine
├─ jacket-designs/       Jacket concept renders and Blender models (Git LFS)
├─ docs/                 HCI research, contracts and the live-sync setup guide
├─ env.example           Example local configuration values
├─ CONTRIBUTING.md       Branching and collaboration guidelines
└─ README.md
```

---

## Running the live demo

The Unity lab, the Kinecto Care app and the Attendance website share one Supabase project, so what happens in one shows up in the others within a few seconds. The connection settings are already in the repository: no accounts, keys or backend setup are needed to run the demo.

### What you need

| For | Install |
| --- | --- |
| Everything | [Git](https://git-scm.com) and [Git LFS](https://git-lfs.com) (run `git lfs install` once) |
| Unity lab | [Unity Hub](https://unity.com/download) with Unity Editor **6000.0.73f1** |
| Kinecto Care app | [Flutter](https://docs.flutter.dev/get-started/install) and an Android emulator (Android Studio) or an Android phone with USB debugging on |
| Attendance website | [VS Code](https://code.visualstudio.com) with the **Live Server** extension |

All three need an internet connection.

### 1. Get the code

```powershell
git clone https://github.com/DrGitman/KINECTO-CHARGE-2040.git
cd KINECTO-CHARGE-2040
```

### 2. Unity lab (the virtual jacket)

1. Unity Hub → **Add → Add project from disk** → choose the `Kinecto_Virtual_Lab` folder. Open it with **6000.0.73f1** (the first import takes a few minutes).
2. Open the scene `Assets/Kinecto/Scenes/KinectoVirtualLab.unity` and press **Play**.
3. The HUD shows **App link · sent N** with N counting up: the lab is connected.

Controls: **W A S D** move · **Shift** run · **Space** jump · **Q** change comfort mode · **E** tap the cuff at a reader · **Tab** show the panels (weather, comfort, fault buttons).

### 3. Kinecto Care app (phone)

Start an Android emulator or plug in your phone, then:

```powershell
cd app
flutter pub get
flutter run --dart-define-from-file=supabase.json
```

Tap **Sign in** (mock NUST account). Home shows the live jacket, **Comfort** changes its settings, **Faults** lists jacket faults. Without `--dart-define-from-file=supabase.json` the app runs on built-in sample data instead.

### 4. Attendance website

1. Open the repository folder in VS Code.
2. Right-click `attendance/index.html` → **Open with Live Server**.
3. The badge at the bottom right says **Shared register · Live**.
4. Choose **Lecturer · Dr. Mark** and sign in.

### 5. Try it together

| Do this | See this |
| --- | --- |
| App → Comfort → choose *Cool*, change a threshold, **Save** | Within about 2 s the Unity HUD shows the new mode and range |
| Press **Q** in Unity | The app's Comfort screen changes mode by itself |
| Unity → **Tab** → a fault button (e.g. *Inside sensor offline*) | The app pops up **Jacket fault** and lists it under Faults |
| Unity → clear all faults | The fault turns *Fixed* in the app |
| Website → Today → **Open session** (EPH810S lecture), then walk to the E201 door reader in Unity and tap the cuff | The tap appears on the website's Today page straight away, in every open browser |
| Tap in Unity while the session is closed | The reader turns red and its log says the session is not open |

Only **one person at a time** should run the Unity lab: everyone shares the same virtual jacket (`KC-SIM-0001`).

### Troubleshooting

| Problem | Fix |
| --- | --- |
| Unity HUD says `offline` or `send failed` | Check the internet connection. A `401` means `Assets/StreamingAssets/lab_connection.json` was changed. |
| Website badge says **Offline** | Check the internet connection and that the page was opened with Live Server, not by double-clicking the file. |
| App shows sample data, not live data | Run it with `--dart-define-from-file=supabase.json`. |
| Images or `.blend` files will not open | Git LFS was missing when you cloned: run `git lfs install` then `git lfs pull`. |
| Nothing updates after a quiet week | The free Supabase project pauses after 7 days without use; the project owner restores it in the Supabase dashboard. |

Backend details, device keys and how to set up a new Supabase project: [docs/live-sync-setup.md](docs/live-sync-setup.md).

### Other local settings

[`env.example`](./env.example) holds development and mock-hardware settings for tools that read a `.env` file (`Copy-Item env.example .env` in PowerShell). Never commit real student identifiers or passwords.

---

## Working on this repository

The team uses short-lived task branches and pull requests into `main`. Direct pushes to `main` are not allowed; pull requests require at least one review and are squash-merged. Read [`CONTRIBUTING.md`](./CONTRIBUTING.md) before starting work.

| Workstream | Branch prefix | Focus |
| --- | --- | --- |
| Attendance | `attendance-dev/` | NFC attendance interactions, reader configuration, and privacy flows |
| Energy and simulation | `energy-dev/` | MATLAB energy models and power-budget visualization |
| Jacket and CAD | `jacket-dev/` | Removable pod design, wire routing, and wearability |
| Thermal and firmware | `thermal-dev/` | ESP32-C3 sensors, load controls, and safety protocols |
| Shared documentation | `docs-dev/` | Project-wide documentation |

---

## Team

| Role | Responsibility |
| --- | --- |
| Member A | Attendance: passive NFC tag integration, classroom reader configuration, and privacy flows |
| Member B | Energy: MATLAB kinetic/TENG source modeling and power-balance dashboard |
| Member C | Enclosure and jacket: printable pod design, wire routing, and wearability |
| Member D | Thermal comfort: ESP32-C3 dual-sensor firmware, MOSFET load controls, and safety protocols |

---

## Development roadmap

The README currently records project workstreams rather than dated milestones:

1. Build MATLAB models for movement-driven energy harvesting and subsystem power budgets.
2. Create the Unity environment for movement, attendance interactions, and thermal visualization.
3. Develop the removable electronics pod and document hardware and power routing.
4. Implement and test the ESP32-C3 thermal-control prototype, including manual overrides and safety behavior.
5. Document HCI research, consent flows, and project findings.

---

## Ethics, privacy, and safety

- Attendance is designed to require an intentional tap; do not add continuous location tracking.
- Use mock or otherwise approved test data during development. Do not commit real student or participant data.
- Treat the 42 °C setting in `env.example` as a development default only. Validate thermal thresholds and hardware behavior before any physical wear test.
- A simulation is not a substitute for physical safety testing or institutional approval.

---

## Acknowledgements

Developed as a student project exploring energy-harvesting wearables, thermal comfort, attendance, and repairable design for a future NUST Windhoek campus.

## License

No license is currently specified. Confirm the intended license with the project team before redistributing or reusing project materials.
