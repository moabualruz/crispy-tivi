// Pure EPG date/time utilities.
//
// These functions operate only on [DateTime] values — no Flutter or
// Riverpod imports. Safe to use in domain, application, and presentation
// layers alike.

/// Returns the Monday of the week containing [date].
DateTime getEpgWeekStart(DateTime date) {
  return DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: date.weekday - 1));
}

/// Returns true if [a] and [b] are the same calendar day.
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Abbreviated month + day label, e.g. "Feb 22".
String epgTodayLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]}'
      ' ${date.day}';
}
