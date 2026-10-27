import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/app.dart';
import 'package:kinecto_care/core/app_strings.dart';
import 'package:kinecto_care/core/widgets/floating_tab_bar.dart';
import 'package:kinecto_care/features/faults/presentation/fault_copy.dart';
import 'package:kinecto_care/features/faults/domain/fault.dart';

import 'helpers.dart';

// Phone-sized surface (360 x 800 logical px).
const Size _phoneSize = Size(1080, 2400);
const double _phonePixelRatio = 3;

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _phonePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [fixedClockOverride],
      child: const KinectoCareApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.signInButton));
  await tester.pumpAndSettle();
}

// The floating tab bar covers the last tiles until the list is scrolled to its end.
Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
  await tester.pumpAndSettle();
}

// Lists build lazily, so scroll until the button exists before tapping it.
Future<void> _tapInList(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text(label));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on sign-in when signed out', (tester) async {
    await _pumpApp(tester);

    expect(find.text(AppStrings.signInButton), findsOneWidget);
    expect(find.byType(FloatingTabBar), findsNothing);
  });

  testWidgets('sign-in lands on the home tab', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);

    expect(find.text(AppStrings.heroOneFault), findsOneWidget);
    expect(find.byType(FloatingTabBar), findsOneWidget);
  });

  testWidgets('tab bar switches between the four tabs', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);

    await _openTab(tester, AppStrings.faultsTab);
    expect(find.text(AppStrings.noFaultsThisMonth), findsNothing);
    expect(
      find.text(_shortTitle(FaultCode.insideSensorSilent)),
      findsOneWidget,
    );

    await _openTab(tester, AppStrings.repairsTab);
    expect(find.text(AppStrings.repairsPlaceholder), findsOneWidget);

    await _openTab(tester, AppStrings.profileTab);
    expect(find.text(AppStrings.profilePlaceholder), findsOneWidget);

    await _openTab(tester, AppStrings.homeTab);
    expect(find.text(AppStrings.heroOneFault), findsOneWidget);
  });

  testWidgets('comfort opens full screen from home and goes back', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signIn(tester);

    await _scrollToEnd(tester);
    await tester.tap(find.text(AppStrings.comfortTile));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.insideSensorOffline), findsOneWidget);
    expect(find.byType(FloatingTabBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.heroOneFault), findsOneWidget);
  });

  testWidgets('open faults tile opens the fault, resolving it clears home', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signIn(tester);

    await _scrollToEnd(tester);
    await tester.tap(find.text(AppStrings.openFaultsTile));
    await tester.pumpAndSettle();
    expect(
      find.text(_copy(FaultCode.insideSensorSilent).title),
      findsOneWidget,
    );

    await _tapInList(tester, AppStrings.markResolvedButton);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.heroAllGood), findsOneWidget);
  });

  testWidgets('book a fix goes to the repairs tab', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _openTab(tester, AppStrings.faultsTab);

    await tester.tap(find.text(_shortTitle(FaultCode.insideSensorSilent)));
    await tester.pumpAndSettle();
    await _tapInList(tester, AppStrings.bookAFixButton);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.repairsPlaceholder), findsOneWidget);
  });

  testWidgets('subsystem chips filter the fault log', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _openTab(tester, AppStrings.faultsTab);

    await tester.tap(
      find.text(FaultCopy.subsystemLabel(FaultSubsystem.energy)),
    );
    await tester.pumpAndSettle();

    expect(find.text(_shortTitle(FaultCode.bufferNotCharging)), findsOneWidget);
    expect(find.text(_shortTitle(FaultCode.insideSensorSilent)), findsNothing);
  });

  testWidgets('saved comfort mode shows on the home tile', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _scrollToEnd(tester);
    await tester.tap(find.text(AppStrings.comfortTile));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.modeCool));
    await tester.pump();
    await _scrollToEnd(tester);
    await tester.tap(find.text(AppStrings.saveToJacketButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.comfortSaved), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.modeCool), findsOneWidget);
  });

  testWidgets('comfort gauge reads again once the sensor fault is resolved', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _scrollToEnd(tester);
    await tester.tap(find.text(AppStrings.openFaultsTile));
    await tester.pumpAndSettle();
    await _tapInList(tester, AppStrings.markResolvedButton);
    await tester.pumpAndSettle();

    await _scrollToEnd(tester);
    await tester.tap(find.text(AppStrings.comfortTile));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.insideNow), findsOneWidget);
    expect(find.text(AppStrings.insideSensorOffline), findsNothing);
  });

  testWidgets('sign-out from profile returns to sign-in', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    await _openTab(tester, AppStrings.profileTab);

    await tester.tap(find.text(AppStrings.signOutButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.signInButton), findsOneWidget);
  });
}

FaultCopy _copy(FaultCode code) => FaultCopy.of(code);

String _shortTitle(FaultCode code) => _copy(code).shortTitle;
