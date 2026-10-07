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

The README describes the intended project areas. These directories may be added as implementation progresses; the current repository root contains the project documentation and configuration scaffold.

```text
Kinecto Charge Project/
├─ simulation/          MATLAB movement, energy, and power-budget models (planned)
├─ unity_environment/   Interactive 3D scene and visualizers (planned)
├─ hardware/            Bill of materials and power-routing details (planned)
├─ cad/                 FreeCAD design and STL files for the removable pod (planned)
├─ firmware/            ESP32-C3 sensor and load-control code (planned)
├─ docs/                HCI research, consent flows, and team contracts (planned)
├─ env.example          Example local configuration values
├─ CONTRIBUTING.md      Branching and collaboration guidelines
└─ README.md
```

---

## Getting started

### Prerequisites

- Git
- MATLAB, for the energy and power-budget simulations
- Unity Hub and a Unity Editor version compatible with the project, once the Unity project is added
- FreeCAD, if working on the electronics enclosure
- PlatformIO-compatible tooling, if working on the planned ESP32-C3 firmware

### 1. Get the repository

Clone the repository using the URL provided by the project team, then move into the project directory:

```bash
git clone <repository-url>
cd "Kinecto Charge Project"
```

### 2. Configure local environment values

The repository includes [`env.example`](./env.example) with development and mock-hardware settings. Copy it to `.env` only if your local tools use these variables, then replace example values with the appropriate local configuration:

```bash
cp env.example .env
```

On Windows Command Prompt, use `copy env.example .env`; in PowerShell, use `Copy-Item env.example .env`.

Never commit real credentials, student identifiers, passwords, or live network keys. The attendance station URL and API key in the example are placeholders for mock development.

### 3. Open the project components

The current scaffold does not yet include runnable MATLAB scripts, a Unity project, CAD files, or firmware. Once those components are added, use the relevant application to open and run them; component-specific commands and tested versions should be documented here.

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
