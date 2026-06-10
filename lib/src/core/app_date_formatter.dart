const _monthNames = [
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

String formatAppDate(DateTime date) {
  return '${date.day}${_ordinalSuffix(date.day)} ${_monthNames[date.month - 1]} ${date.year}';
}

String formatStoredAppDate(String value) {
  final date = parseAppDate(value);
  return date == null ? value : formatAppDate(date);
}

DateTime? parseAppDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final colonParts = trimmed.split(':');
  if (colonParts.length == 3) {
    final day = int.tryParse(colonParts[0]);
    final month = int.tryParse(colonParts[1]);
    final year = int.tryParse(colonParts[2]);
    return _validDate(year: year, month: month, day: day);
  }

  final match = RegExp(
    r'^(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)\s+(\d{4})$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (match == null) return null;

  final day = int.tryParse(match.group(1)!);
  final month =
      _monthNames.indexWhere(
        (monthName) => monthName.toLowerCase() == match.group(2)!.toLowerCase(),
      ) +
      1;
  final year = int.tryParse(match.group(3)!);
  return _validDate(year: year, month: month, day: day);
}

String _ordinalSuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';

  return switch (day % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
}

DateTime? _validDate({int? year, int? month, int? day}) {
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}
