/// User-facing copy. Comfort wording only, never medical terms.
abstract final class AppStrings {
  static const String appTitle = 'Kinecto Care';

  static const String signInTitle = 'Welcome to Kinecto Care';
  static const String signInButton = 'Sign in with NUST';
  static const String signInMockNotice =
      'Mock sign-in for development. NUST single sign-on comes later.';
  static const String signInFailed = 'Sign-in failed. Please try again.';
  static const String signOutButton = 'Sign out';

  static const String homeTab = 'Home';
  static const String faultsTab = 'Faults';
  static const String repairsTab = 'Repairs';
  static const String profileTab = 'Profile';
  static const String comfortTitle = 'Comfort';
  static const String openComfortButton = 'Comfort settings';

  static const String repairsPlaceholder = 'No repairs yet.';
  static const String profilePlaceholder = 'Profile and settings coming soon.';

  static const String simulated = 'SIMULATED';
  static const String simulatedHint =
      'Simulated data from the Virtual Lab jacket';
  static const String loadFailed = 'Could not load your jacket data.';
  static const String retryButton = 'Try again';

  static const String greetingMorning = 'Good morning';
  static const String greetingAfternoon = 'Good afternoon';
  static const String greetingEvening = 'Good evening';
  static const String heroAllGood = 'Your jacket is looking good';
  static const String heroOneFault = 'One thing needs your attention';
  static String heroFaults(int count) => '$count things need your attention';
  static String pairedJacket(String jacketId) => '$jacketId · paired';

  static const String comfortBatteryLabel = 'Comfort battery';
  static const String gaugeLow = 'Low';
  static const String gaugeFull = 'Full';
  static const String energyBufferTile = 'Energy buffer';
  static const String comfortTile = 'Comfort';
  static const String cuffTagTile = 'Cuff tag';
  static const String openFaultsTile = 'Open faults';
  static const String cuffReady = 'Ready';
  static const String cuffNeedsCheck = 'Check tag';
  static const String modeAuto = 'Auto';
  static const String modeCool = 'Cool';
  static const String modeWarm = 'Warm';
  static const String modeOff = 'Off';

  static const String insideNow = 'inside now';
  static const String insideSensorOffline = 'Inside sensor offline';
  static const String noReading = '--';
  static const String warmMeBelow = 'Warm me below';
  static const String coolMeAbove = 'Cool me above';
  static const String lower = 'Lower';
  static const String raise = 'Raise';
  static const String limitsUsedInAuto = 'Auto mode uses these two limits.';
  static String prewarmBefore(String time) => 'Pre-warm before $time';
  static const String prewarmNote =
      'Saved as a preference. The jacket does not pre-warm yet.';
  static const String saveToJacketButton = 'Save to jacket';
  static String savedAgo(String ago) => 'Saved $ago';
  static const String comfortSaved = 'Comfort settings saved';
  static const String comfortSaveFailed =
      'Could not save these settings. Try again.';

  static const String faultsAll = 'All';
  static const String previousMonth = 'Previous month';
  static const String nextMonth = 'Next month';
  static const String noFaultsThisMonth = 'No faults this month.';

  static const String faultTitle = 'Fault';
  static const String needsAFix = 'Needs a fix';
  static const String whatHappened = 'What happened';
  static const String whatWeDid = 'What we did';
  static const String whatToDo = 'What to do';
  static const String bookAFixButton = 'Book a fix';
  static const String markResolvedButton = 'I fixed it, mark as resolved';
  static const String faultNotFound = 'This fault is no longer in your log.';
  static const String resolveFailed = 'Could not update this fault. Try again.';
}
