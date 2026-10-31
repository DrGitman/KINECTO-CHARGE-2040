abstract final class AppRoutes {
  static const String signIn = '/sign-in';
  static const String verifyCode = '/sign-in/verify';
  static const String home = '/home';
  static const String faults = '/faults';
  static const String repairs = '/repairs';
  static const String profile = '/profile';

  // Inside the Home tab, so the tab bar stays (board 04b).
  static const String notifications = '/home/notifications';
  static const String energy = '/home/energy';
  static const String comfortToday = '/home/comfort';

  // Full screen above the tabs.
  static const String comfort = '/comfort';
  static const String cuff = '/cuff';
  static const String pod = '/pod';
  static const String notificationSettings = '/settings/notifications';
  static const String themeSettings = '/settings/theme';
  static const String help = '/help';

  // Fault detail is also full screen, opened from the log, a Home tile or an alert.
  static const String faultDetail = '/fault/:id';
  static String faultDetailFor(String faultId) => '/fault/$faultId';
}

/// Signed-out users always land on sign-in, signed-in users never see it.
String? resolveRedirect({required bool isSignedIn, required String location}) {
  final isOnSignIn = location == AppRoutes.signIn || location.startsWith('${AppRoutes.signIn}/');
  if (!isSignedIn) return isOnSignIn ? null : AppRoutes.signIn;
  return isOnSignIn ? AppRoutes.home : null;
}
