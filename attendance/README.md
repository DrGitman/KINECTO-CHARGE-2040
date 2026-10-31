# Kinecto Attendance

The attendance website for NUST lecturers and admins. Not to be confused with **Kinecto Care**, the phone app for the jacket's comfort, monitoring and faults (Figma: App Design, boards 08b and 08c). It reads and writes the shared Supabase project only, so a cuff tap in the Unity Virtual Lab shows up here within about a second, in every open browser. Nothing is kept in the browser except who is signed in on that tab.

## Run it

1. Apply the database migration once (see below).
2. Open the repository in VS Code, right-click `attendance/index.html` → **Open with Live Server**.
3. Sign in with a NUST email from the `staff` table, for example:
   - `m.kandjii@nust.na`: lecturer (EPH810S, EPH710S, EPH620S)
   - `p.shikongo@nust.na`: admin
   - `tutor.eph@nust.na`: assistant (can open and close sessions, cannot mark by hand)

   NUST email delivery is not connected in this prototype, so the 6-digit code is shown on the sign-in page.

The sidebar shows **Live · Supabase** when the Realtime connection is up.

## Database

`supabase/migrations/20261030100000_attendance_desk.sql` adds the tables this desk needs on top of the live-sync migration:

| Table | What it holds |
| --- | --- |
| `rooms`, `readers` | Teaching rooms and their door readers. `readers.last_seen` is set by every tap and, for the Unity reader, while the lab is running. A reader is shown online if it was seen in the last 2 minutes. |
| `staff`, `courses` | Who may use the desk (lecturer, assistant, admin) and who teaches which course |
| `sessions` (new columns) | Real `starts_at` / `ends_at`, late window, auto open / close |
| `attendance_corrections` | Students marked present by hand, with the reason and an undo |
| `tap_attempts` | Every tap, accepted or rejected, for the door-quality numbers |
| `audit_log` | Session open / close, hand marks, role and reader changes, exports. Written by database triggers. |

It also seeds rooms, readers, staff, courses, 18 more mock students and six weeks of timetable from the current week. The EPH810S lecture runs every weekday at 10:00 in E201, the room with the Unity door reader.

Apply it with **Supabase dashboard → SQL Editor → paste the file → Run**, or `npx supabase db push`.

Sessions open by themselves `open_before_min` minutes before the start and close at the end. pg_cron does this every minute when the project has it; otherwise any open desk page does it every 30 s.

## Try it with Unity

1. Sign in as `m.kandjii@nust.na`. On **Today**, open the EPH810S lecture (or wait for it to open itself at 09:55).
2. Press Play in the Unity lab, walk to the E201 door and press **E**.
3. The tap appears under **Live taps**, the counter goes up, and the Register shows the student. A tap before the session is open shows as **Rejected** with the reason.
4. **Close session** opens the summary.

## Screens

| Lecturer | Admin |
| --- | --- |
| Today (live session, live taps, today's sessions) | Overview (campus today, needs attention) |
| Sessions (week) + New session | Readers & rooms + reader detail + add reader |
| Register + mark present by hand (undo 10 s) | Rooms |
| Reports (weekly bars, below 75%, tap quality) | Courses (assign lecturer) |
| Session closed (summary) | Campus reports (busiest times) |
| Student detail | Roles & access |
| Settings (defaults, alerts) | Audit log |

On a phone the sidebar becomes a menu and a bottom tab bar, and the hand-mark drawer becomes a bottom sheet.

## Code

| File | Job |
| --- | --- |
| `js/store.js` | Supabase client, loads every table, applies Realtime changes, all writes |
| `js/derive.js` | Every number on screen is calculated here from the live tables |
| `js/ui.js` | Small view helpers, icons, toasts, CSV export, bar chart |
| `js/lecturer.js` | Lecturer and assistant screens |
| `js/admin.js` | Admin screens |
| `js/main.js` | Sign-in, shell, routing, one event handler for the whole page |

## Not connected yet

- Real NUST sign-in (codes are shown on screen).
- Email delivery for reminders and summaries: these are recorded in the audit log only.
- NUST ITS export.
- Physical door readers: only the Unity reader `E201-SIM` has a device key.

The database policies are open demo policies with mock data. Add Supabase Auth and per-role policies before any real student data (see `docs/live-sync-setup.md`).
