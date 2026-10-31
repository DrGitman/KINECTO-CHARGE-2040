# Unity to Attendance website: integration contract

## How it works now

Unity never talks to the website. Both talk to the shared Supabase project:

```
Unity door reader (E201-SIM)  --POST-->  Edge Function attendance-ingest  -->  record_tap()  -->  attendance_events / tap_attempts
                                                                                                         |
Attendance website  <-----------------------  Supabase Realtime  <---------------------------------------+
```

1. Unity posts the tap to `functions/v1/attendance-ingest` with its reader key (`x-reader-key`).
2. The function calls `record_tap(p_tag, p_direction, p_reader_id, p_session_id, p_source)`. The database decides whether the tap is accepted: the tag must belong to a student, the reader must have exactly one open session, and the student must take that course.
3. Every attempt, accepted or rejected, goes into `tap_attempts`. Accepted taps also go into `attendance_events`. The reader's `last_seen` is updated.
4. Every open website receives the new rows through Realtime and updates Today, the Register, Reports and the reader pages within about a second.

The website keeps no attendance data of its own. A refresh shows exactly what is in the database.

## Unity request

```json
{"reader_id":"E201-SIM","tag_id":"MOCK-0187","direction":"IN","ts":"2026-10-30T10:02:00Z"}
```

`session_id` is optional. Without it, the database uses the one session that is open at that reader.

## Responses

| Result | Meaning | Shown on the website |
| --- | --- | --- |
| `ok: true` | Tap recorded | Live taps (green), Register: Present or Late |
| `Tap IN already recorded for this session.` | Same student, same session, same direction | Live taps, counted as a duplicate in tap quality |
| `No open session at this reader for this student.` | No session open at that reader, or the student does not take that course | Live taps (Rejected), reader detail |
| `More than one open session at this reader.` | Two sessions open in one room (the website blocks this) | Live taps (Rejected) |
| `Unknown tag.` | The tag is not linked to a student | Live taps (Rejected) |

## Test without Unity

```bash
curl -X POST "https://iqlhmjmzcgbmofrujprt.supabase.co/functions/v1/attendance-ingest" \
  -H "Content-Type: application/json" \
  -H "x-reader-key: <reader key from Kinecto_Virtual_Lab/Assets/StreamingAssets/lab_connection.json>" \
  -d '{"reader_id":"E201-SIM","tag_id":"MOCK-0187","direction":"IN"}'
```

## Security before production

The website uses demo sign-in codes and open demo database policies with mock students. Before real student data: Supabase Auth with NUST accounts, per-role row-level security, one key per physical reader stored outside the repository, and moving the reader key out of `lab_connection.json`.
