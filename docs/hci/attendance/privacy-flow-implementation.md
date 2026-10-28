# Attendance privacy flows and implementation status

## 1. Intentional NFC tap
A student deliberately presents a passive cuff tag to a classroom reader. A valid tap is associated with a reader, active session and student registration. No continuous location, movement, temperature or energy history is collected by attendance.

**Prototype:** Tap Station generates local mock events. **Not implemented:** real reader, secure server validation or Unity-to-browser live feed.

## 2. Student access and attendance query
The student role displays only the sample student’s own records and registered modules. A student can submit a session-specific message to the lecturer but cannot mark attendance or edit records.

**Prototype:** browser-only role selection and local data filtering. **Not implemented:** NUST email login, backend access control, secure multi-user data isolation.

## 3. Lecturer correction
Lecturer selects a student in the selected session, chooses a reason, optionally adds a note and submits a correction. The correction records the actor, time, student and session and appears in the audit history.

**Prototype:** corrections and audit events in browser localStorage. **Not implemented:** tamper-resistant server audit log or independent verification of correction evidence.

## 4. Admin oversight
Admin can view reader/room configuration, course summaries, role descriptions and a read-only local audit log. Admin does not have lecturer attendance correction controls.

**Prototype:** mock reader configuration. **Not implemented:** remote reader management, real permission provisioning or campus-wide reporting.

## 5. Data minimisation and retention
Minimal intended tap data: pseudonymous tag identifier, reader identifier, session identifier, direction and timestamp. Tag-to-student mapping should be protected on the backend. Do not commit real student information. Data retention and deletion require institutional approval; no retention policy is asserted as approved.

## 6. Failure and dispute handling
Unknown tags, wrong module, closed sessions, duplicate IN and OUT without IN are rejected by the local simulation. Missing taps can be reported through Messages; the lecturer reviews before making a manual correction.

## 7. Security limitation
Browser role switching, sessionStorage and localStorage are demonstration-only and do not constitute authentication, authorisation, encryption or an immutable audit trail. Do not deploy with real student records.
