# Roles and permissions

## Lecturer

A lecturer can view assigned sessions, open or close a session, review attendance, export a register, answer student queries and correct a missed tap with a recorded reason. Dr M. Kandjii (`m.kandjii@nust.na`) is the sample lecturer, P. Shikongo the sample admin and `tutor.eph@nust.na` a teaching assistant, who can open and close sessions but not mark students by hand.

## Student

A student can view their own modules, attendance history and tap times. They can send a message if a record seems wrong and read the lecturer's reply. Students cannot mark themselves present, change a tap time, edit a register or delete a record.

## NUST administrator

The administrator view covers readers, rooms, course assignments and role information. The sample administrator is P. Shikongo. Real administrative changes and access checks will require a secure backend.

## Important limitation

The current role selector is for local testing only. It does not prove who a user is. Before real deployment, the server must verify the user's identity and permissions for every request.
