# Live sync setup: Unity lab ↔ Kinecto Care ↔ Attendance

One Supabase project connects all three parts. Each part talks only to Supabase, never directly to the others:

```text
 Unity Virtual Lab ──(Edge Functions, device keys)──►  Supabase  ◄──(Realtime + REST, publishable key)── Kinecto Care app
   jacket-ingest  : telemetry + fault flags   ◄── reply: comfort settings          comfort settings, faults, jacket status
   attendance-ingest : cuff taps                                                  ◄──(Realtime + REST)── Attendance website
                                                                                      sessions, taps (record_tap)
```

| You do this… | …and this happens |
| --- | --- |
| Change mode or thresholds in **Kinecto Care → Comfort** and save | Unity applies them on its next send (about 2 s) |
| Press the mode key / dashboard mode in **Unity** | The Care app's Comfort screen updates live |
| Inject a fault in **Unity** (e.g. *Inside sensor offline*) | Care app shows a *Jacket fault* pop-up and the fault appears in **Faults** |
| *Clear all* faults in **Unity** | The faults turn *Fixed* in the Care app |
| Lecturer clicks **Open session** on the website | Unity's door reader can now record taps for that session |
| Tap the cuff at the **Unity** E201 reader | The tap appears on the website's Today / Register at once, in every open browser |
| Tap before the session is open | Unity's reader goes red and its log shows `cloud: No open session…` |

Everything here uses **mock IDs only** (`KC-SIM-0001`, `MOCK-0187`, …). See [Security](#security-before-real-data).

---

## Why Supabase alone (not Render + Neon)

- The Unity bridge was already written against Supabase Edge Functions.
- **Realtime is built in.** Neon is only a database; with Render you would have to build and host your own WebSocket server for live updates.
- Render's free web services sleep after about 15 minutes idle and take up to a minute to wake, which breaks a live demo.
- One dashboard, one set of keys, free tier is enough for this project.

Add Render later only if you want the Python `services/fault_engine` running 24/7. It can write to the same `faults` table with `source = 'kinecto_check'`.

---

## 1. Create the Supabase project (once, one team member)

1. Sign in at <https://supabase.com> → **New project**. Name it `kinecto-charge-2040`, choose the closest region offered, and save the database password in your password manager.
2. When it is ready, open **Project Settings → API Keys** and note:
   - **Project URL**, e.g. `https://abcdefgh.supabase.co`
   - **Publishable key** (`sb_publishable_…`, or the legacy **anon** key). This one is safe in apps and web pages.
   - Never copy the **secret / service_role** key into any app, Unity file or web page.
3. Note the **project ref**, the `abcdefgh` part of the URL.

## 2. Push the database and Edge Functions

You need Node.js (already used by the team). From the repository root, in PowerShell:

```powershell
npx supabase login
npx supabase link --project-ref abcdefgh
npx supabase db push
npx supabase functions deploy
```

- `db push` runs `supabase/migrations/…_kinecto_live_sync.sql`. It creates the tables, the `record_tap` rules, Realtime, and the mock seed data.
- `functions deploy` deploys `jacket-ingest`, `jacket-config` and `attendance-ingest`. `supabase/config.toml` turns off JWT checks for them because the devices use their own keys.

**No CLI?** You can paste the migration file into **SQL Editor → New query → Run** instead of `db push`. The Edge Functions still need the CLI.

## 3. Create the device keys

Unity proves who it is with two keys: one for the virtual jacket and one for the E201 door reader. Supabase stores only their sha256 hash.

1. Make two random keys in PowerShell (run it twice):
   ```powershell
   [guid]::NewGuid().ToString('N')
   ```
2. In **SQL Editor**, run (paste your two keys):
   ```sql
   insert into public.devices (id, kind, key_hash, label) values
     ('KC-SIM-0001', 'jacket', encode(extensions.digest('PASTE-JACKET-KEY', 'sha256'), 'hex'), 'Unity virtual jacket'),
     ('E201-SIM',    'reader', encode(extensions.digest('PASTE-READER-KEY', 'sha256'), 'hex'), 'Unity E201 door reader');
   ```
3. Share the two plain keys with the team privately (not in Git, not in the group chat history).

## 4. Unity Virtual Lab

1. Copy `Kinecto_Virtual_Lab/Assets/StreamingAssets/lab_connection.example.json` to `lab_connection.json` in the same folder. It is gitignored.
2. Fill it in:
   ```json
   {
     "functions_url": "https://abcdefgh.supabase.co/functions/v1",
     "jacket_id": "KC-SIM-0001",
     "device_key": "PASTE-JACKET-KEY",
     "send_every_s": 2,
     "enabled": true,
     "reader_id": "E201-SIM",
     "reader_key": "PASTE-READER-KEY"
   }
   ```
3. Open `KinectoVirtualLab.unity` and press Play. The scene already has `SupabaseBridge` wired. The HUD chip should read **App link · sent N · KC-SIM-0001** and keep counting.

## 5. Kinecto Care app (Flutter)

1. Copy `app/supabase.example.json` to `app/supabase.json` (gitignored) and fill in the URL and publishable key.
2. Run:
   ```powershell
   cd app
   flutter pub get
   flutter run --dart-define-from-file=supabase.json
   ```
3. Without `--dart-define-from-file`, the app still runs on its mock data, so `flutter test` keeps working offline.

## 6. Attendance website

1. Fill in `attendance/supabase-config.js`:
   ```js
   window.KINECTO_SUPABASE = {
     url: 'https://abcdefgh.supabase.co',
     anonKey: 'sb_publishable_...'
   };
   ```
2. Open `attendance/index.html` with Live Server. A badge at the bottom right shows **Shared register · Live**.
3. In cloud mode the website shows the shared Supabase register instead of the browser's old local demo records. Leave the config empty to go back to the local demo.
4. Keep **Settings → Unity attendance integration** (API polling) switched off; live sync replaces it.

---

## 7. Demo check (all three running)

1. **App → Unity:** Care app → Comfort → mode *Cool*, warm-below 20 °C → Save. Within about 2 s the Unity HUD shows Cool and the range *20 – 26 °C · set in phone app*.
2. **Unity → App:** press the mode key in Unity. The Care app's Comfort screen changes mode by itself.
3. **Fault alert:** in Unity, inject *Inside sensor offline*. The Care app shows **Jacket fault: Inside sensor offline**; tap **View**. In Unity, *Clear all*. The fault becomes *Fixed* in the app.
4. **Attendance:** website → sign in as Dr. Mark → Today → *EPH810S Lecture* → **Open session**. In Unity, walk to the E201 door reader and hold the cuff there. The tap appears under *Live taps*. Open the site in a second browser to see both update together.
5. **Rejection path:** close the session on the website, tap again in Unity. The reader light goes red and its log says the session is not open.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Unity HUD: `offline: no lab_connection.json` | The file is missing or misnamed in `StreamingAssets`. |
| Unity: `send failed: HTTP/1.1 401` | The device key does not match the hash in `devices`, or `jacket_id`/`reader_id` differ. Redo step 3. |
| Unity: `send failed: … 404` | The functions are not deployed or `functions_url` is wrong (it must end in `/functions/v1`). |
| Website badge: **Offline: …** | Wrong URL or key in `supabase-config.js`, or no internet. |
| Changes only show after refresh | **Database → Publications → supabase_realtime** must list the five tables; re-run the migration's `alter publication` line. |
| Everything stopped after a quiet week | Free projects pause after 7 days without activity. Dashboard → **Restore project**. |
| Unity reader: `cloud: No open session at this reader…` | Open the session on the website first. The Unity student `MOCK-0187` is in EPH810S, which uses reader `E201-SIM`. |

## Security before real data

This setup is a prototype with mock IDs. The database policies let anyone with the publishable key read the data, change comfort settings, open sessions and record taps through `record_tap`. Before any real student or wearer data:

- Add Supabase Auth (NUST sign-in) and replace the `demo` policies with per-user and per-role rules (wearer owns their jacket; lecturer manages their own module's sessions).
- Keep device keys out of Git, and rotate them if one leaks: update the hash in `devices`.
- Get the institutional approvals described in the project README.
