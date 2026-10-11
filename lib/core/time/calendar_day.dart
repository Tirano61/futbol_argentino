/// Día calendario sin hora ni zona (p. ej. el «día argentino» de un partido).
final class CalendarDay implements Comparable<CalendarDay> {
  const CalendarDay(this.year, this.month, this.day);

  /// Interpreta `yyyy-MM-dd`; devuelve `null` si no es una fecha válida.
  static CalendarDay? tryParse(String? value) {
    final match = _isoDate.firstMatch(value?.trim() ?? '');
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final check = DateTime.utc(year, month, day);
    if (check.month != month || check.day != day) return null;
    return CalendarDay(year, month, day);
  }

  static final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  /// Medianoche UTC de este día (útil para comparar y sumar días).
  DateTime get asUtcDate => DateTime.utc(year, month, day);

  /// 1 = lunes … 7 = domingo.
  int get weekday => asUtcDate.weekday;

  CalendarDay addDays(int days) {
    final d = asUtcDate.add(Duration(days: days));
    return CalendarDay(d.year, d.month, d.day);
  }

  int differenceInDays(CalendarDay other) =>
      asUtcDate.difference(other.asUtcDate).inDays;

  bool isBefore(CalendarDay other) => compareTo(other) < 0;
  bool isAfter(CalendarDay other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDay other) => year != other.year
      ? year - other.year
      : month != other.month
      ? month - other.month
      : day - other.day;

  @override
  bool operator ==(Object other) =>
      other is CalendarDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// `yyyy-MM-dd`.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${_two(month)}-${_two(day)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
