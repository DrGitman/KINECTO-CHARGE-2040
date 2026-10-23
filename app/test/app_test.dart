import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/app.dart';
import 'package:kinecto_care/core/app_strings.dart';
import 'package:kinecto_care/core/widgets/floating_tab_bar.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: KinectoCareApp()));
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.signInButton));
  await tester.pumpAndSettle();
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

    expect(find.text(AppStrings.homePlaceholder), findsOneWidget);
    expect(find.byType(FloatingTabBar), findsOneWidget);
  });

  testWidgets('tab bar switches between the four tabs', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);

    await _openTab(tester, AppStrings.faultsTab);
    expect(find.text(AppStrings.faultsPlaceholder), findsOneWidget);

    await _openTab(tester, AppStrings.repairsTab);
    expect(find.text(AppStrings.repairsPlaceholder), findsOneWidget);

    await _openTab(tester, AppStrings.profileTab);
    expect(find.text(AppStrings.profilePlaceholder), findsOneWidget);

    await _openTab(tester, AppStrings.homeTab);
    expect(find.text(AppStrings.homePlaceholder), findsOneWidget);
  });

  testWidgets('comfort opens full screen from home and goes back', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signIn(tester);

    await tester.tap(find.text(AppStrings.openComfortButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.comfortPlaceholder), findsOneWidget);
    expect(find.byType(FloatingTabBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.homePlaceholder), findsOneWidget);
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
