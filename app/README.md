# Kinecto Care

The phone app for people who wear the Kinecto jacket (Flutter, Android and iOS). It shows how the jacket is doing, lets the wearer change comfort settings, and tells them about faults and their class taps.

It is a separate system from **Kinecto Attendance**, the website for lecturers and admins. Both read the same Supabase database.

The screens follow App Design boards 04 and 04b in Figma.

## Run it

Run these from this `app` folder with your Android phone plugged in (USB debugging on):

```powershell
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <your phone id> --dart-define-from-file=supabase.json
```

Sign in with `j.amupolo@nust.na`. Email sending is not connected in this prototype, so the six digit code is shown on the screen. Then press Play in the Unity Virtual Lab and the app follows the virtual jacket live.

Before the first run, the database files listed in the main [README](../README.md) (step 2) must have been run once in Supabase.

## Where the data comes from

Nothing on the screens is typed in by hand.

| What you see | Where it comes from |
| --- | --- |
| Your name, email and jacket | `students` table (looked up by your NUST email) |
| Home tiles, gauge, Cuff tag, Pod & battery | `jacket_status`, updated by the jacket about once a second |
| Energy and Comfort charts | `jacket_samples` (one reading every 10 seconds), added up by the `jacket_buckets` database function |
| Comfort settings | `comfort_settings`. Saving here reaches the jacket on its next send |
| Faults | `faults`, opened and fixed by the jacket |
| Notifications | `jacket_events`, written by the database when a fault opens or is fixed, comfort settings change, or you tap at a classroom door |

Changes arrive through Supabase Realtime, so the screens update by themselves.

Without Supabase (for example in `flutter test`) the app uses built in sample data marked as simulated.

## Code layout

```text
lib/
  app.dart                  theme and router
  main.dart                 connects to Supabase and restores the signed in wearer
  core/                     theme, router, shared strings and widgets
  features/
    auth/                   NUST email and code sign in
    home/                   Home screen, jacket health gauge
    jacket/                 live jacket status, history, Energy, Cuff tag, Pod & battery
    comfort/                comfort settings and Comfort today
    faults/                 fault log and fault detail
    notifications/          notification feed
    profile/                profile and help
    settings/               theme and alert preferences
```

## Not connected yet

* Real NUST single sign on and email delivery (the code is shown on screen).
* Push notifications when the app is closed. Alerts appear while the app is open.
* Repairs and booking a fix (FabLab repair work, separate branch).
