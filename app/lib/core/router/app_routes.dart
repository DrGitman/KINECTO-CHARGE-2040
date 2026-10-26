abstract final class AppRoutes {
  static const String signIn = '/sign-in';
  static const String home = '/home';
  static const String faults = '/faults';
  static const String repairs = '/repairs';
  static const String profile = '/profile';

  // Comfort is not a tab: it is pushed full screen from the Home tile and from Profile.
  static const String comfort = '/comfort';

  // Fault detail is also full screen, opened from the log, a Home tile or an alert.
  static const String faultDetail = '/fault/:id';
  static String faultDetailFor(String faultId) => '/fault/$faultId';
}

/// Signed-out users always land on sign-in, signed-in users never see it.
String? resolveRedirect({required bool isSignedIn, required String location}) {
  final isOnSignIn = location == AppRoutes.signIn;
  if (!isSignedIn) return isOnSignIn ? null : AppRoutes.signIn;
  return isOnSignIn ? AppRoutes.home : null;
}
