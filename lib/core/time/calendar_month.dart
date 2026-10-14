import 'calendar_day.dart';

/// Mes calendario sin zona (p. ej. el mes de un calendario de partidos).
final class CalendarMonth implements Comparable<CalendarMonth> {
  const CalendarMonth(this.year, this.month);

  CalendarMonth.of(CalendarDay day) : year = day.year, month = day.month;

  /// Interpreta `yyyy-MM`; devuelve `null` si no es un mes válido.
  static CalendarMonth? tryParse(String? value) {
    final match = _isoMonth.firstMatch(value?.trim() ?? '');
    if (match == null) return null;
    final month = int.parse(match[2]!);
    if (month < 1 || month > 12) return null;
    return CalendarMonth(int.parse(match[1]!), month);
  }

  static final _isoMonth = RegExp(r'^(\d{4})-(\d{2})$');

  final int year;

  /// 1 = enero … 12 = diciembre.
  final int month;

  CalendarDay get firstDay => CalendarDay(year, month, 1);

  /// Cantidad de días del mes.
  int get length => DateTime.utc(year, month + 1, 0).day;

  bool contains(CalendarDay day) => day.year == year && day.month == month;

  CalendarMonth addMonths(int months) {
    final d = DateTime.utc(year, month + months);
    return CalendarMonth(d.year, d.month);
  }

  /// Semanas de lunes a domingo; `null`: el casillero es de otro mes.
  List<List<CalendarDay?>> get weeks {
    final cells = <CalendarDay?>[
      for (var i = 1; i < firstDay.weekday; i++) null,
      for (var d = 1; d <= length; d++) CalendarDay(year, month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
  }

  bool isBefore(CalendarMonth other) => compareTo(other) < 0;
  bool isAfter(CalendarMonth other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarMonth other) =>
      year != other.year ? year - other.year : month - other.month;

  @override
  bool operator ==(Object other) =>
      other is CalendarMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  /// `yyyy-MM`.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}
