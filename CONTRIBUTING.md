# Contributing to Kinecto

This guide explains how the team can work on the Kinecto smart-jacket project in parallel while keeping changes easy to review. The repository is currently a scaffold: the workstream folders and their implementation-specific checks may be added as the project develops.

---

## 1. Branching model

- `main` is the shared integration branch. Keep it in a working state.
- Do not push directly to `main`; use a pull request for changes.
- Create a new short-lived branch for each task, using the prefix for its workstream.
- Aim to merge task branches within 1–2 days. Split larger tasks into smaller issues and pull requests.
- After a pull request is merged, delete the task branch.

| Workstream | Branch prefix | Intended area |
| --- | --- | --- |
| Attendance | `attendance-dev/` | NFC cuff tag, classroom reader interactions, and privacy |
| Energy and simulation | `energy-dev/` | MATLAB movement models, energy estimates, and power budgets |
| Jacket and CAD | `jacket-dev/` | Wearability, removable electronics pod, and wire routing |
| Thermal and firmware | `thermal-dev/` | ESP32-C3 sensors, load control, and safety behavior |
| Shared documentation | `docs-dev/` | Project-wide documentation and coordination |

### Branch names

Use this format:

```text
<prefix>/<issue-number>-<short-description>
```

Examples:

```text
energy-dev/12-walking-energy-model
jacket-dev/18-removable-pod-enclosure
thermal-dev/23-sensor-fault-shutoff
docs-dev/27-update-test-procedure
```

Use lowercase words separated by hyphens. If there is no issue number, use `<prefix>/<short-description>`.

---

## 2. Daily workflow

Start each task from the latest `main`:

```bash
git switch main
git pull
git switch -c energy-dev/12-walking-energy-model
```

Make small, focused commits as the work progresses:

```bash
git add path/to/changed-files
git commit -m "feat(simulation): model walking energy output"
```

Sync with `main` before opening the pull request, then push the task branch:

```bash
git pull --rebase origin main
git push -u origin HEAD
```

Open a pull request targeting `main`. After it is merged, update the local branch and remove the completed task branch:

```bash
git switch main
git pull
git branch -d energy-dev/12-walking-energy-model
```

If work is likely to exceed two days, break it down so each pull request has a clear, reviewable purpose.

---

## 3. Collaboration guidelines

1. **Coordinate edits across workstreams.** Keep changes focused on the task’s intended area. If a change needs another workstream’s files, discuss it with that owner before editing.
2. **Agree on shared data formats.** Coordinate MATLAB-to-Unity data, sensor readings, units, and configuration changes with every affected workstream before changing the format.
3. **Keep safety-relevant changes reviewable.** Changes to thermal cutoffs, heating/fan behavior, power routing, or failure handling should explain their assumptions and include a test or validation procedure.
4. **Protect the privacy goal.** Attendance must remain an intentional tap interaction; do not introduce continuous location tracking or store real student identifiers in test assets.
5. **Identify planned versus implemented behavior.** The README describes intended project areas. Do not describe a planned simulation, hardware feature, or test as implemented until it exists and has been verified.
6. **Track large binary assets deliberately.** Coordinate before adding Unity renders, CAD exports, `.STL`, or `.blend` files. Use Git LFS only after the repository has a shared `.gitattributes` policy for the relevant file types.

---

## 4. Commits

Use a consistent, concise format:

```text
<type>(<area>): <what changed>
```

| Type | Use for |
| --- | --- |
| `feat` | A new capability or model |
| `fix` | A bug or incorrect result |
| `docs` | Documentation-only changes |
| `test` | Adding or updating tests or validation |
| `refactor` | Restructuring without changing behavior |
| `chore` | Tooling, configuration, or maintenance |

Suggested areas include `attendance`, `simulation`, `unity`, `cad`, `firmware`, `safety`, and `docs`.

Examples:

```text
feat(simulation): estimate energy from elbow movement
fix(firmware): switch loads off when a sensor read fails
docs(safety): clarify thermal test procedure
```

Keep each commit focused. Do not include local credentials, generated build output, or unrelated formatting changes.

---

## 5. Working independently

The project is still establishing its component interfaces and development tooling. Before depending on another workstream:

- Agree on data shapes, units, and input/output expectations with the other contributor.
- Use clearly identified sample or mock inputs while the real component is unfinished.
- Document assumptions that affect compatibility, such as sample rate, temperature units, coordinate conventions, or energy units.
- Do not claim that a fake, feature flag, automated contract test, or integration path exists unless it has been added and verified in the repository.

When one component is not ready, use a small documented sample dataset or stub only when it helps unblock work. Keep it separate from production or real student data.

---

## 6. Pull requests

- Keep one task or closely related change per pull request.
- Target `main` and link the related issue when one exists.
- Explain what changed, why it changed, and how it was tested or inspected.
- Request review from a teammate familiar with the affected workstream. At least one other team member should review and approve before merge.
- Squash-merge approved pull requests and delete the branch after merging.

### Pull request checklist

- [ ] The change is scoped to the task and coordinated with affected workstreams.
- [ ] Assumptions, units, and interfaces are documented where relevant.
- [ ] Tests, simulation runs, or manual validation are described; no unrun checks are reported as passing.
- [ ] Safety-related behavior includes a validation procedure and failure behavior.
- [ ] Privacy requirements are preserved; no real student or participant data is included.
- [ ] No credentials, local `.env` files, or unnecessary generated/binary files are included.
- [ ] Documentation is updated if setup, behavior, or project structure changed.

---

## 7. Issues and labels

Use issues to describe discrete work, record design questions, and coordinate changes that cross workstream boundaries. Include the relevant workstream and priority in the issue title or labels if those labels are available in the repository.

Suggested label groups:

| Group | Suggested labels |
| --- | --- |
| Workstream | `Attendance`, `Energy`, `Jacket-CAD`, `Thermal-Firmware`, `Documentation` |
| Type | `Feature`, `Bug`, `Research`, `Safety`, `Privacy` |
| Priority | `Must`, `Should`, `Could` |

These are suggestions; only use labels that have been created in the repository.

---

## 8. Releases and large deliverables

No release schedule or automated release process is currently documented. Coordinate a release with the team before creating version tags or publishing build artifacts.

For source snapshots, use semantic version tags such as `v0.1.0` only after the team agrees on what that version represents:

```bash
git switch main
git pull
git tag -a v0.1.0 -m "Describe the project milestone"
git push origin v0.1.0
```

Do not assume that pushing a tag builds or publishes anything automatically.

---

## 9. Protecting `main`

Repository administrators should configure the `main` branch protection rules in GitHub to match the team workflow:

- Require pull requests before merging.
- Require at least one approval.
- Require status checks only once the repository has checks configured.
- Require conversation resolution.
- Block force pushes and branch deletion.

---

## 10. Secrets, data, and safety

- Never commit `.env`, credentials, API keys, passwords, live Wi-Fi details, or private tokens. Use [`env.example`](./env.example) for placeholders.
- Use mock or approved test data only. Keep real student or participant data out of Git, fixtures, screenshots, and issues.
- The attendance concept is based on an intentional NFC tap, not continuous tracking.
- Treat the 42 °C value in `env.example` as a development default, not a validated safety limit. Physical thermal behavior must be reviewed and tested before any wear test.
- Simulations and prototypes do not replace physical safety testing or required institutional approval.
