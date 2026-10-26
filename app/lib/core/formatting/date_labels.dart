abstract final class DateLabels {
  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const int _shortMonthLength = 3;

  /// "just now", "2 min ago", "3 h ago", "4 d ago".
  static String timeAgo(DateTime then, DateTime now) {
    final elapsed = now.difference(then);
    if (elapsed.inMinutes < 1) return 'just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours} h ago';
    return '${elapsed.inDays} d ago';
  }

  /// "today 10:42", "yesterday", "12 Oct".
  static String day(DateTime then, DateTime now) {
    final days = _dateOnly(now).difference(_dateOnly(then)).inDays;
    if (days == 0) {
      return 'today ${_twoDigits(then.hour)}:${_twoDigits(then.minute)}';
    }
    if (days == 1) return 'yesterday';
    return '${then.day} ${_months[then.month - 1].substring(0, _shortMonthLength)}';
  }

  /// "October 2026".
  static String month(DateTime month) =>
      '${_months[month.month - 1]} ${month.year}';

  static DateTime _dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
