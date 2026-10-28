# Kinecto Attendance System

This is the browser prototype for the attendance part of Kinecto Smart Jacket 2040. It is built with HTML, CSS and JavaScript.

## Run the application

1. Open the `attendance` folder in Visual Studio Code.
2. Start Live Server and open `index.html`.
3. Select a sample role on the sign-in page.

There are three sample roles: Lecturer (Dr. Mark), Student (Student 001) and NUST Administrator (P. Shikongo). The role selector is only for testing. It is not a secure login system.

## How to test attendance

1. Sign in as Dr. Mark.
2. Open the Today page and check that the EPH810S lecture is open.
3. Go to Tap Station and choose `MOCK-0187`.
4. Choose Tap IN and simulate the tap.
5. Check the Today counter and Register page.
6. Return to Tap Station, wait at least 10 seconds, then choose Tap OUT.
7. Check the register again.

Events are saved in this browser's local storage. They are kept separate by session ID. A student must be registered for the selected module. Tap OUT is rejected if there is no earlier Tap IN, and duplicate taps within 10 seconds are ignored.

## Student and lecturer messages

Sign in as Student 001 to view attendance and send a query. Sign in as Dr. Mark to open Messages and reply. Students cannot edit attendance in their view. A lecturer can record a manual correction with a reason from the Register page.

## What is not connected yet

Unity, Render, the university database, physical NFC readers and real NUST sign-in are not connected. The reader statuses and report charts contain sample information. Browser role selection and local storage are not secure enough for real student records.

The `docs/hci/attendance` folder explains the system, roles, privacy rules and the planned integration.


## Figma-based visual rebuild
The lecturer Today, Register and Reports screens and the administrator Readers screen have been rebuilt to follow the supplied Figma screenshots. The logo symbol is taken from the supplied Figma reference and is used as a local image asset. The attendance application is separate from the jacket interface.

The lecturer profile uses Dr. Mark. Student records use fictional IDs. The login is a role switcher for local testing, not real authentication. Reader statuses, weekly report values and some totals are illustrative. Unity, Render and NUST ITS are not connected.

The attendance event engine still records sample IN and OUT events per session. Open the Tap Station under the lecturer role to try it.
