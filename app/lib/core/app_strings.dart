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

  static const String roleStudent = 'Student';
  static const String jacketPaired = 'Jacket paired';
  static const String mockAccount = 'Mock account';
  static String comfortSummary(String mode, String warm, String cool) =>
      '$mode · $warm to $cool';
  static const String notificationsTitle = 'Notifications';
  static const String notificationsSummary = 'Faults and repair updates';
  static const String themeTitle = 'Theme';
  static const String helpTitle = 'Repair card & help';
  static const String helpSummary = 'How to remove the pod';

  static const String signOutTitle = 'Sign out?';
  static const String signOutBody =
      'Your jacket keeps your comfort settings. You can sign back in any time with your NUST email.';
  static const String cancelButton = 'Cancel';

  static const String faultAlerts = 'Fault alerts';
  static const String faultAlertsHint = 'Always on for safety faults';
  static String newFaultAlert(String title) => 'Jacket fault: $title';
  static const String viewFaultButton = 'View';
  static const String repairUpdates = 'Repair updates';
  static const String repairUpdatesHint = 'Each repair stage';
  static const String energyTips = 'Energy tips';
  static const String energyTipsHint = 'Weekly summary';
  static const String comfortChanges = 'Comfort changes';
  static const String comfortChangesHint = 'When Auto switches mode';
  static const String feedbackRequests = 'Feedback requests';
  static const String feedbackRequestsHint = 'After a repair only';
  static const String quietHoursNote =
      'Quiet hours 22:00 to 07:00. Safety alerts still come through.';
  static const String alertsNotLiveNote =
      'Saved on this phone. Alerts start once the jacket is linked to Kinecto Care online.';

  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';
  static const String matchMyPhone = 'Match my phone';
  static const String largerText = 'Larger text';
  static const String reduceMotion = 'Reduce motion';

  static const String repairCardTitle = 'Repair card';
  static const List<String> repairCardSteps = [
    'Switch the pod off',
    'Undo the 4 screws on the lid',
    'Unplug the labelled connectors',
    'Lift the pod out; the jacket is now washable',
  ];
  static const String howKinectoWorks = 'How Kinecto works';
  static const String howKinectoWorksBody =
      'The comfort module warms or cools the inside of your jacket from its own battery. '
      'Energy from walking only powers the status light and the energy bar. '
      'It does not charge your phone or run the heater.';
  static const String contactFabLab = 'Contact the FabLab';
  static const String fabLabLocation = 'NUST FabLab · Engineering block';
}
