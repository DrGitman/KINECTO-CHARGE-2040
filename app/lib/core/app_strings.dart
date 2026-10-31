import '../features/auth/domain/auth_repository.dart';
import '../features/jacket/domain/jacket_history.dart';

/// User-facing copy. Comfort wording only, never medical terms.
abstract final class AppStrings {
  static const String appTitle = 'Kinecto Care';

  static const String signInTitle = 'Welcome to\nKinecto Care';
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
  static const String gaugeFull = 'Great';
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

  static const String liveFromJacket = 'Live from the jacket';
  static const String heaterFanLabel = 'Heater & fan';
  static const String heatingNow = 'Heating';
  static const String coolingNow = 'Cooling';
  static const String idleNow = 'Idle';
  static const String outsideLabel = 'Outside';
  static const String harvestedLabel = 'Harvested';
  static const String activityLabel = 'Wearer';
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
      '$mode · $warm–$cool';
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
  static const String alertsLiveNote =
      'Saved on this phone. Fault alerts pop up as soon as your jacket reports one.';

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
  // ---------- Kinecto Care live screens (boards 04 and 04b) ----------
  static const String jacketDetails = 'Jacket details';
  static const String jacketHealth = 'Jacket health';
  static const String podTitle = 'Pod & battery';
  static const String energyTitle = 'Energy';
  static const String jacketNotInRange = 'Jacket not in range';
  static String lastReadingFrom(String time) => 'Showing the last reading from $time';
  static const String lastKnown = 'last known';
  static const String howToReconnect = 'How to reconnect';
  static const String reconnectUnity = 'Open the Kinecto Virtual Lab and press Play';
  static const String reconnectInternet = 'Check the lab PC is online';
  static const String reconnectPod = 'Check the pod switch is on';
  static const String reconnectBluetooth = 'Turn on Bluetooth on your phone';
  static const String reconnectCuff = 'Or hold your cuff to the phone';
  static const String tryAgain = 'Try again';

  static const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static String weekdayShort(int weekday) => _weekdays[(weekday - 1) % 7];
  static String rangeLabel(HistoryRange range) => switch (range) {
    HistoryRange.day => 'Day',
    HistoryRange.week => 'Week',
    HistoryRange.month => 'Month',
  };
  static String _rangeWord(HistoryRange range) => switch (range) {
    HistoryRange.day => 'today',
    HistoryRange.week => 'this week',
    HistoryRange.month => 'in 30 days',
  };
  static const String buffer = 'Buffer';
  static String harvestedIn(HistoryRange range, double mj) =>
      '${mj.toStringAsFixed(mj < 10 ? 2 : 0)} mJ harvested ${_rangeWord(range)}';
  static String walkingIn(HistoryRange range) => 'walking ${_rangeWord(range)}';
  static const String bufferVoltage = 'buffer voltage';
  static const String whatThisPowers = 'What this powers';
  static const String whatThisPowersBody =
      'The status light and this energy bar. Movement energy is small: it does not charge your phone or run the heater.';

  static const String insideWord = 'inside';
  static const String outsideWord = 'outside';
  static const String insideVsOutside = 'Inside vs outside today';
  static const String noHistoryYet = 'The chart fills in while your jacket reports today.';
  static const String heaterToday = 'heater today';
  static const String blowerToday = 'blower today';
  static const String modeNow = 'Mode now';
  static String yourRange(int warm, int cool) => 'Your range: warm below $warm °C, cool above $cool °C';
  static const String changeRange = 'Change range';
  static const String onNow = 'ON NOW';

  static const String tagReadable = 'Tag readable';
  static const String tagNotReadable = 'Tag can\'t be read';
  static String lastChecked(String ago) => 'Last checked $ago';
  static String lastTapLine(String direction, String where, String when) =>
      'Last tap: ${direction == 'OUT' ? 'out' : 'in'}${where.isEmpty ? '' : ' · $where'} · $when';
  static const String whatTheTagDoes = 'What the tag does';
  static const String whatTheTagDoesBody =
      'Lets you tap in and out of class at the reader. The tag has no battery and no location: the app and the university can\'t track where you are.';
  static const String testMyTag = 'Test my tag';
  static const String tagTestOk = 'Your jacket read the tag just now. It is working.';
  static const String tagTestFailed = 'The tag could not be read. Book a FabLab check.';

  static const String podChecks = 'Pod checks';
  static const String checkHeater = 'Heater and inside sensor';
  static const String checkFan = 'Cooling fan';
  static const String checkBuffer = 'Energy buffer charging';
  static const String checkBattery = 'Battery temperature';
  static const String ok = 'OK';
  static const String check = 'Check';
  static const String comfortTimeLeft = 'comfort time left';
  static const String batteryTemperature = 'battery temperature';
  static const String openRepairCard = 'Open repair card';

  static const String noNotifications = 'Nothing yet. Faults, comfort changes and your taps at class show up here.';
  static const String today = 'Today';
  static const String earlier = 'Earlier';
  static String faultFixedTitle(String title) => '$title fixed';
  static const String faultFixedBody = 'Everything is back to normal';
  static const String comfortSyncedTitle = 'Comfort settings synced';
  static String modeFromId(String? id) => switch (id) {
    'cool' => modeCool,
    'warm' => modeWarm,
    'off' => modeOff,
    _ => modeAuto,
  };
  static const String tappedIn = 'Tapped in at class';
  static const String tappedOut = 'Tapped out of class';

  static const String thisMonth = 'This month';
  static const String allClear = 'All clear';
  static const String closeButton = 'Close';

  static const String signInWithNust = 'Sign in with your NUST email';
  static const String signInBody = 'Students and staff use the same account. We\'ll email you a 6-digit code.';
  static const String emailHint = 'name@nust.na';
  static const String nustOnly = 'Only NUST institutional emails can sign in.';
  static String signInProblem(AuthProblem problem) => switch (problem) {
    AuthProblem.notNust => 'That is not a NUST email. Use your @nust.na address.',
    AuthProblem.unknownEmail => 'No Kinecto jacket is registered to this email.',
    AuthProblem.noJacket => 'Your account has no jacket paired yet. Ask the FabLab.',
    AuthProblem.wrongCode => 'That code is not right. Check it and try again.',
    AuthProblem.offline => 'Could not reach Kinecto. Check your internet and try again.',
  };
  static const String sendMyCode = 'Send my code';
  static const String emailUse = 'Your email is used only to sign in and to update you about repairs.';
  static const String checkYourEmail = 'Check your email';
  static const String weSentCode = 'We sent a 6-digit code to';
  static String resendIn(int seconds) => 'Resend code in 0:${seconds.toString().padLeft(2, '0')}';
  static const String resendCode = 'Resend code';
  static String demoCode(String code) =>
      'Prototype: email is not connected yet, so here is your code: $code';
  static const String verify = 'Verify';
  static const String jacketOffline = 'Jacket offline';
  static String syncedAgo(String ago) => 'Synced $ago · works offline';
  static const String comfortOfflineBanner =
      'Your jacket is offline. Saved settings reach it as soon as it reports again.';
}
