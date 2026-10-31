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
├─ app/                  Kinecto Care phone app for the jacket wearer (Flutter)
├─ attendance/           Kinecto Attendance website for lecturers and admins
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

There are three parts, and they all share one Supabase database:

| Part | Who uses it | What it does |
| --- | --- | --- |
| **Unity Virtual Lab** | The demo presenter | A 3D person wearing a virtual Kinecto jacket. It sends the jacket readings to Supabase about once a second, and sends at once when something changes. |
| **Kinecto Care app** | Students and staff who wear the jacket | Phone app for comfort, jacket health, energy, faults and notifications. |
| **Kinecto Attendance** | Lecturers and NUST admins | Website for class sessions, registers, reports, door readers and roles. |

Whatever you do in one part shows up in the others within about a second. Nothing on these screens is typed in by hand: every number comes from the database.

### What you need

| For | Install |
| --- | --- |
| Everything | [Git](https://git-scm.com) and [Git LFS](https://git-lfs.com). Run `git lfs install` once. |
| Unity lab | [Unity Hub](https://unity.com/download) with Unity Editor **6000.0.73f1** |
| Kinecto Care app | [Flutter](https://docs.flutter.dev/get-started/install) and an Android phone with USB debugging turned on (or an Android emulator) |
| Kinecto Attendance | [VS Code](https://code.visualstudio.com) with the **Live Server** extension |

All three need an internet connection.

### 1. Get the code

```powershell
git clone https://github.com/DrGitman/KINECTO-CHARGE-2040.git
cd KINECTO-CHARGE-2040
```

### 2. Set up the database (once)

Open the Supabase dashboard, go to **SQL Editor**, paste each file below and press **Run**. Do them in this order. Each one is safe to run again.

1. `supabase/migrations/20261030100000_attendance_desk.sql` adds rooms, readers, staff, courses and the timetable for the website.
2. `supabase/migrations/20261030120000_attendance_fixes.sql` gives the teaching assistant their courses.
3. `supabase/migrations/20261030130000_kinecto_care_live.sql` adds the wearer accounts, the jacket history for the app charts and the notification feed.
4. Optional: `supabase/seed/attendance_demo_history.sql` adds five earlier weeks of mock class taps so the attendance reports have something to show. Run it again to start over.

### 3. Unity lab (the virtual jacket)

1. In Unity Hub choose **Add**, then **Add project from disk**, and pick the `Kinecto_Virtual_Lab` folder. Open it with **6000.0.73f1**. The first import takes a few minutes.
2. Open the scene `Assets/Kinecto/Scenes/KinectoVirtualLab.unity` and press **Play**.
3. The HUD shows **App link · sent N** with N counting up. That means the lab is connected.

Controls: **W A S D** move, **Shift** run, **Space** jump, **Q** change comfort mode, **E** tap the cuff at a door reader, **Tab** show the panels (weather, comfort and fault buttons).

Only one person at a time should run the lab, because everyone shares the same virtual jacket (`KC-SIM-0001`).

### 4. Kinecto Care app (phone)

Plug in your phone, then run these from the repository folder:

```powershell
cd app
flutter pub get
flutter devices
flutter run -d <your phone id> --dart-define-from-file=supabase.json
```

`flutter devices` shows your phone id. If the phone is the only device, you can leave out `-d <your phone id>`.

**Sign in:** type `j.amupolo@nust.na` and press **Send my code**. Email sending is not connected in this prototype, so the six digit code is shown on the screen. Type it in and you are signed in. This student wears the Unity jacket. The app remembers you until you sign out.

What you will find in the app:

| Screen | What it shows |
| --- | --- |
| **Home** | Your name, jacket health, energy buffer, comfort mode, cuff tag and open faults. The bell turns red when there is something new. If the jacket sends nothing for two minutes, Home shows **Jacket not in range** with the last reading. |
| **Energy** | What your movement harvested, hour by hour for today, or day by day for the week or month. Also walking time and buffer voltage. |
| **Comfort** (tile on Home) | Inside and outside temperature today, how long the heater and fan ran, and the mode right now. **Change range** opens the comfort settings. |
| **Comfort settings** | Mode, the warm and cool limits and pre warm. **Save to jacket** sends them to the jacket. |
| **Cuff tag** | Whether the tag can be read, and your last tap at a classroom door. |
| **Pod & battery** | Battery level, comfort time left, battery temperature and the pod checks. |
| **Faults** | Every jacket fault by month, with what happened and what to do. |
| **Notifications** | Faults opened and fixed, comfort changes and your class taps. |
| **Profile** | Your name and NUST email from the database, theme, alerts and help. |

The Repairs tab is still a placeholder. That part belongs to the FabLab repair work.

### 5. Kinecto Attendance (website)

1. Open the repository folder in VS Code.
2. Right click `attendance/index.html` and choose **Open with Live Server**.
3. Sign in as `m.kandjii@nust.na` (lecturer), `tutor.eph@nust.na` (teaching assistant) or `p.shikongo@nust.na` (admin). The six digit code is shown on the page.
4. The sidebar says **Live · Supabase** when it is connected.

A small pop up appears every time a student taps in or out at one of your doors. In Settings you can turn the pop ups off, or allow desktop notifications so you still see taps while Unity is in front. More detail is in [`attendance/README.md`](attendance/README.md).

### 6. Try it together

| Do this | You will see |
| --- | --- |
| App: Comfort settings, choose *Cool*, change a limit, press **Save to jacket** | About a second later the Unity HUD shows the new mode and range |
| Press **Q** in Unity | The comfort mode changes in the app by itself |
| Walk or run in Unity | Energy and the activity on the app follow straight away, and the charts fill in during the day |
| Unity: press **Tab**, then a fault button such as *Inside sensor offline* | The app pops up **Jacket fault**, the bell turns red and the fault is listed under Faults |
| Unity: clear all faults | The fault turns *Fixed* in the app |
| Website: Today, open the EPH810S lecture (or wait, it opens by itself 5 minutes before 10:00). Then walk to the E201 door in Unity and press **E** | The tap pops up on the website, the counter goes up and the student shows on the register. The app shows the tap under Notifications and on the Cuff tag screen |
| Tap in Unity while no session is open | The reader turns red in Unity and the website shows the tap as **Rejected** |

Only the **E201 (EPH810S) classroom** doors are linked to the website: tap in at the reader outside the door and tap out at the station inside. The other doors work in Unity but are not sent to the website.

### If something does not work

| Problem | What to do |
| --- | --- |
| Unity HUD says `offline` or `send failed` | Check the internet connection. A `401` means `Assets/StreamingAssets/lab_connection.json` was changed. |
| Website says **Offline**, or asks you to apply a migration | Check the internet connection, open the page with Live Server (not by double clicking the file) and run the database files in step 2. |
| App says **Jacket not in range** | Press Play in Unity. The app goes back to live as soon as Unity sends again. |
| App says *No Kinecto jacket is registered to this email* | Run `20261030130000_kinecto_care_live.sql` from step 2, then use `j.amupolo@nust.na`. |
| App charts are empty | They fill in while Unity runs. History starts from the moment the step 2 files were run. |
| Images or `.blend` files do not open | Git LFS was missing when you cloned. Run `git lfs install`, then `git lfs pull`. |
| Nothing updates after a quiet week | The free Supabase project pauses after 7 days without use. The project owner restores it in the Supabase dashboard. |

How the backend, device keys and a new Supabase project are set up: [docs/live-sync-setup.md](docs/live-sync-setup.md).

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
