# Unity to Attendance website: integration contract

## Current implementation

The website has two independent modes. **Local demo** keeps its browser-based Tap Station and records. **API polling** (optional) uses `attendance/integration.js` to GET validated attendance events from a backend every 5 seconds. Both modes write accepted events into the same local attendance store, so the Lecturer Today/Register, Student My Attendance, and Admin Audit log can display them.

**Not implemented here:** a public POST endpoint, database, Unity bridge, secure authentication, server-side validation, Supabase realtime, or cross-device shared data. The browser cannot receive a POST directly from Unity. Do not configure Unity to POST to the website or GitHub Pages.

## Unity -> backend

The existing Unity bridge uses `reader_id`, `tag_id`, `direction`, and `ts`:

```json
{"reader_id":"E201-SIM","tag_id":"MOCK-TAG-0187","direction":"IN","ts":"2026-10-28T10:00:00Z","session_id":"EPH810S-LECT-01"}
```

`session_id` is strongly recommended. If it is missing, the browser imports only when exactly one open session matches the reader and student module. The backend should resolve the session authoritatively, not rely on this demo fallback.

## Backend -> website

Expose an HTTPS **GET** endpoint returning an array or an object with `events` array, containing only **accepted, server-validated** taps:

```json
{
  "events": [
    {"id":"evt-001","reader_id":"E201-SIM","tag_id":"MOCK-TAG-0187","direction":"IN","ts":"2026-10-28T10:00:00Z","session_id":"EPH810S-LECT-01"},
    {"id":"evt-002","reader_id":"E201-SIM","tag_id":"MOCK-TAG-0187","direction":"OUT","ts":"2026-10-28T12:00:00Z","session_id":"EPH810S-LECT-01"}
  ]
}
```

The browser supports camelCase aliases, checks direction and timestamps, maps the mock tag to a sample student, rejects ambiguous session mapping, and prevents duplicate imports. It never uses the browser's selected session as a fallback. It requires the corresponding session to be **open in the local demo state**. This is a prototype limitation: a real backend should also synchronize sessions and roster information. The API must set CORS for the website's origin.

## To connect

1. Run the site using Live Server, not `file://`.
2. Lecturer or Admin -> Settings -> Unity attendance integration.
3. Paste the backend's HTTPS GET events feed URL, enable fetching, and Save connection.
4. Open the corresponding session in the demo website. Send a validated event to the backend from Unity or an API test client.
5. Check Lecturer Today/Register, Student My Attendance, Admin Audit log. Use the same browser for switching roles.
6. If the backend is unavailable, disable fetching and continue local Tap Station demonstrations.

## Security before production

The role selector is not authentication, and `localStorage` is not a secure database. Do not use real student records or expose a private API key in frontend code. The production backend must authenticate Unity devices, validate tag ownership and session/reader mappings, enforce permissions, handle rejected taps and corrections, and provide authenticated, role-filtered API responses. A shared database and proper authorization are needed for multi-device operation.
