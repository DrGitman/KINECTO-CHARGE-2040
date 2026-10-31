import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/features/auth/data/fake_auth_repository.dart';
import 'package:kinecto_care/features/auth/domain/auth_repository.dart';
import 'package:kinecto_care/features/auth/presentation/auth_controller.dart';

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts signed out', () {
    expect(_container().read(authControllerProvider), isNull);
  });

  test('only NUST emails are accepted', () {
    expect(isNustEmail('j.amupolo@nust.na'), isTrue);
    expect(isNustEmail('221012345@students.nust.na'), isTrue);
    expect(isNustEmail('someone@gmail.com'), isFalse);
  });

  test('email then code signs the wearer in with their jacket', () async {
    final container = _container();
    final controller = container.read(authControllerProvider.notifier);

    final code = await controller.requestCode(FakeAuthRepository.mockEmail);
    await controller.verifyCode(FakeAuthRepository.mockEmail, code);

    final session = container.read(authControllerProvider);
    expect(session?.studentId, FakeAuthRepository.mockUserId);
    expect(session?.jacketId, isNotEmpty);
  });

  test('a wrong code keeps the wearer signed out', () async {
    final container = _container();
    final controller = container.read(authControllerProvider.notifier);
    await controller.requestCode(FakeAuthRepository.mockEmail);

    await expectLater(
      controller.verifyCode(FakeAuthRepository.mockEmail, '000000'),
      throwsA(isA<AuthException>()),
    );
    expect(container.read(authControllerProvider), isNull);
  });

  test('sign-out clears the session', () async {
    final container = _container();
    final controller = container.read(authControllerProvider.notifier);
    await controller.verifyCode(FakeAuthRepository.mockEmail, FakeAuthRepository.mockCode);
    await controller.signOut();
    expect(container.read(authControllerProvider), isNull);
  });
}
