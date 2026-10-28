# Attendance privacy and consent

## Why attendance information is needed

The attendance system helps lecturers check who attended a class and lets students review their own records. The system only needs information that supports that purpose.

## Information collected for a tap

A tap event needs a tag identifier, reader identifier, session identifier, direction and time. The server can use a protected tag-to-student mapping to show the correct student in the register.

## Information we do not need

The attendance system does not need continuous location tracking, movement history, body temperature or the jacket's energy data. A classroom reader is used to identify the correct class, not to build a record of where students move throughout the day.

## Who can access records

Students should only see their own attendance. Lecturers should only see the modules assigned to them. Administrators should only receive the access they need for their duties. These restrictions must be checked by the backend, not just by hiding buttons.

## If something goes wrong

A student can report a missing or incorrect tap to the lecturer. Only an authorised lecturer can correct the record. Every manual change needs a reason, the lecturer's name and a timestamp. The original event history should be kept for audit purposes.

## Consent and transparency

Students should receive a plain explanation of what a cuff tap records, why it is used, who can see it and how to ask for a correction. The university must decide the appropriate consent or other lawful basis before real deployment. A student should not be misled into thinking a mock login is secure.

## Storage and retention

This prototype uses fictional student IDs and stores records in the browser. Real attendance records must be stored securely. NUST must confirm the retention period, archive rules and deletion process before real student information is collected.

## What still needs to be checked

We still need to review the backend security, reader credentials, access logs, data retention and the actual privacy notice. No real student records should be entered into this prototype.
