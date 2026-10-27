import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/features/faults/domain/fault.dart';
import 'package:kinecto_care/features/faults/presentation/fault_copy.dart';

void main() {
  // Comfort product, never medical wording.
  final banned = RegExp(r'health|fever|diagnos|body', caseSensitive: false);

  test('fault copy uses comfort wording only', () {
    for (final code in FaultCode.values) {
      final copy = FaultCopy.of(code);
      final text = [
        copy.shortTitle,
        copy.title,
        copy.whatHappened,
        copy.whatWeDid,
        copy.whatToDo,
      ].join(' ');
      expect(banned.hasMatch(text), isFalse, reason: code.id);
    }
  });
}
