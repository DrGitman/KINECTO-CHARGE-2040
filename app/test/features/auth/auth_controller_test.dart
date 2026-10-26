import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/features/auth/data/fake_auth_repository.dart';
import 'package:kinecto_care/features/auth/domain/auth_repository.dart';
import 'package:kinecto_care/features/auth/domain/auth_session.dart';
import 'package:kinecto_care/features/auth/presentation/auth_controller.dart';

class _FailingAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> signIn() async => throw const AuthException('offline');

  @override
  Future<void> signOut() async {}
}

ProviderContainer _containerWith(AuthRepository repository) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts signed out', () {
    final container = _containerWith(FakeAuthRepository());

    expect(container.read(authControllerProvider), isNull);
  });

  test('sign-in stores the mock user session', () async {
    final container = _containerWith(FakeAuthRepository());

    await container.read(authControllerProvider.notifier).signIn();

    expect(
      container.read(authControllerProvider)?.userId,
      FakeAuthRepository.mockUserId,
    );
  });

  test('sign-out clears the session', () async {
    final container = _containerWith(FakeAuthRepository());
    final controller = container.read(authControllerProvider.notifier);

    await controller.signIn();
    await controller.signOut();

    expect(container.read(authControllerProvider), isNull);
  });

  test('failed sign-in rethrows and stays signed out', () async {
    final container = _containerWith(_FailingAuthRepository());

    await expectLater(
      container.read(authControllerProvider.notifier).signIn(),
      throwsA(isA<AuthException>()),
    );
    expect(container.read(authControllerProvider), isNull);
  });
}
