import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/core/formatting/date_labels.dart';

void main() {
  final now = DateTime(2026, 10, 26, 10, 42);

  test('timeAgo uses the largest whole unit', () {
    expect(DateLabels.timeAgo(now, now), 'just now');
    expect(
      DateLabels.timeAgo(now.subtract(const Duration(minutes: 2)), now),
      '2 min ago',
    );
    expect(
      DateLabels.timeAgo(now.subtract(const Duration(hours: 3)), now),
      '3 h ago',
    );
    expect(
      DateLabels.timeAgo(now.subtract(const Duration(days: 4)), now),
      '4 d ago',
    );
  });

  test('day shows the time today, then yesterday, then the date', () {
    expect(DateLabels.day(DateTime(2026, 10, 26, 8, 5), now), 'today 08:05');
    expect(DateLabels.day(DateTime(2026, 10, 25, 23, 59), now), 'yesterday');
    expect(DateLabels.day(DateTime(2026, 10, 12, 9), now), '12 Oct');
  });

  test('month names the month and year', () {
    expect(DateLabels.month(DateTime(2026, 10)), 'October 2026');
  });
}
