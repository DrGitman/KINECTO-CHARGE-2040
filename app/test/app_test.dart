import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/app.dart';
import 'package:kinecto_care/core/app_strings.dart';
import 'package:kinecto_care/core/widgets/floating_tab_bar.dart';
import 'package:kinecto_care/features/auth/data/fake_auth_repository.dart';
import 'package:kinecto_care/features/auth/domain/auth_repository.dart';
import 'package:kinecto_care/features/faults/domain/fault.dart';
import 'package:kinecto_care/features/faults/presentation/fault_copy.dart';

import 'helpers.dart';

// Phone-sized surface (360 x 800 logical px).
const Size _phoneSize = Size(1080, 2400);
const double _phonePixelRatio = 3;

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _phonePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: [fixedClockOverride], child: const KinectoCareApp()),
  );
  await tester.pumpAndSettle();
}

// NUST email, then the 6-digit code shown on the verify screen.
Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), FakeAuthRepository.mockEmail);
  await tester.pump();
  await tester.tap(find.text(AppStrings.sendMyCode));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), FakeAuthRepository.mockCode);
  await tester.pumpAndSettle();
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
  await tester.pumpAndSettle();
}

Future<void> _tapInList(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).last);
  await Scrollable.ensureVisible(tester.element(find.text(label)), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(label));
  await tester.pumpAndSettle();
}

String _shortTitle(FaultCode code) => FaultCopy.of(code).shortTitle;

void main() {
  testWidgets('opens on sign-in when signed out', (tester) async {
    await _pumpApp(tester);
    expect(find.text(AppStrings.sendMyCode), findsOneWidget);
    expect(find.byType(FloatingTabBar), findsNothing);
  });

  testWidgets('a non-NUST email is refused', (tester) async {
    await _pumpApp(tester);
    await tester.enterText(find.byType(TextField), 'someone@gmail.com');
    await tester.tap(find.text(AppStrings.sendMyCode));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.signInProblem(AuthProblem.notNust)), findsOneWidget);
  });

  testWidgets('email and code land on home with the wearer name', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    expect(find.text(AppStrings.heroOneFault), findsOneWidget);
    expect(find.text(FakeAuthRepository.mockSession.greetingName), findsOneWidget);
    expect(find.byType(FloatingTabBar), findsOneWidget);
  });

  testWidgets('tab bar switches between the four tabs', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);

    await _openTab(tester, AppStrings.faultsTab);
    expect(find.text(_shortTitle(FaultCode.insideSensorSilent)), findsOneWidget);

    await _openTab(tester, AppStrings.repairsTab);
    expect(find.text(AppStrings.repairsPlaceholder), findsOneWidget);

    await _openTab(tester, AppStrings.profileTab);
    expect(find.text(FakeAuthRepository.mockSession.name), findsOneWidget);
    expect(find.text(FakeAuthRepository.mockEmail), findsOneWidget);

    await _openTab(tester, AppStrings.homeTab);
    expect(find.text(AppStrings.heroOneFault), findsOneWidget);
  });

  testWidgets('open faults tile opens the fault, resolving it clears home', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _scrollToEnd(tester);
    await tester.tap(find.text(AppStrings.openFaultsTile));
    await tester.pumpAndSettle();
    expect(find.text(FaultCopy.of(FaultCode.insideSensorSilent).title), findsOneWidget);

    await tester.tap(find.text(AppStrings.markResolvedButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.heroAllGood), findsOneWidget);
  });

  testWidgets('subsystem chips filter the fault log', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _openTab(tester, AppStrings.faultsTab);

    await tester.tap(find.text(FaultCopy.subsystemLabel(FaultSubsystem.energy)));
    await tester.pumpAndSettle();

    expect(find.text(_shortTitle(FaultCode.bufferNotCharging)), findsOneWidget);
    expect(find.text(_shortTitle(FaultCode.insideSensorSilent)), findsNothing);
  });

  testWidgets('comfort settings save from profile and show on the tile', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _openTab(tester, AppStrings.profileTab);
    await _tapInList(tester, AppStrings.openComfortButton);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.insideSensorOffline), findsOneWidget);

    await tester.tap(find.text(AppStrings.modeCool));
    await tester.pump();
    await _tapInList(tester, AppStrings.saveToJacketButton);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.comfortSaved), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openTab(tester, AppStrings.homeTab);
    expect(find.text(AppStrings.modeCool), findsOneWidget);
  });

  testWidgets('profile shows the saved comfort range', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _openTab(tester, AppStrings.profileTab);
    expect(find.text(AppStrings.comfortSummary(AppStrings.modeAuto, '19', '26°C')), findsOneWidget);
  });

  testWidgets('sign-out from profile returns to sign-in', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _openTab(tester, AppStrings.profileTab);
    await _tapInList(tester, AppStrings.signOutButton);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.signOutTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.signOutButton).last);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.sendMyCode), findsOneWidget);
  });

  testWidgets('fault alerts cannot be turned off', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _openTab(tester, AppStrings.profileTab);
    await _tapInList(tester, AppStrings.notificationsTitle);
    await tester.pumpAndSettle();

    final faultSwitch = tester.widget<Switch>(find.byType(Switch).first);
    expect(faultSwitch.value, isTrue);
    expect(faultSwitch.onChanged, isNull);
  });

  testWidgets('help shows the four repair card steps', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _openTab(tester, AppStrings.profileTab);
    await _tapInList(tester, AppStrings.helpTitle);
    await tester.pumpAndSettle();
    for (final step in AppStrings.repairCardSteps) {
      expect(find.text(step), findsOneWidget);
    }
  });
}
