# Kinecto Care

Companion phone app for the Kinecto smart jacket (Flutter, Android and iOS).

This is the app shell only: theme, navigation and a mock sign-in. Home, Faults and Comfort are placeholders. NUST sign-in, Supabase, live alerts and push come in later pull requests.

## Stack

- Flutter 3.32 (Dart 3.8)
- `flutter_riverpod` for state and dependency injection
- `go_router` for navigation and the sign-in redirect

## Layout

```text
lib/
  app.dart              MaterialApp with theme and router
  core/                 theme, router, shared strings and widgets
  features/<feature>/
    data/               repositories and DTOs
    domain/             entities and interfaces
    presentation/       screens and controllers
```

## Run and test

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

## Mock data

Sign-in is faked by `FakeAuthRepository` and always returns the mock user `STU-MOCK-0001`. No real names or student numbers are stored.
