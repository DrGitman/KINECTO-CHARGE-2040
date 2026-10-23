import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/core/router/app_routes.dart';

void main() {
  group('resolveRedirect', () {
    test('sends a signed-out user to sign-in', () {
      expect(
        resolveRedirect(isSignedIn: false, location: AppRoutes.faults),
        AppRoutes.signIn,
      );
    });

    test('keeps a signed-out user on sign-in', () {
      expect(
        resolveRedirect(isSignedIn: false, location: AppRoutes.signIn),
        isNull,
      );
    });

    test('sends a signed-in user away from sign-in to home', () {
      expect(
        resolveRedirect(isSignedIn: true, location: AppRoutes.signIn),
        AppRoutes.home,
      );
    });

    test('lets a signed-in user open any tab', () {
      expect(
        resolveRedirect(isSignedIn: true, location: AppRoutes.comfort),
        isNull,
      );
    });
  });
}
