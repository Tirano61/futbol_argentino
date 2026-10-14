import '../../../../core/time/calendar_day.dart';
import '../../../../core/time/calendar_month.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../entities/season.dart';

/// Partidos de un mes agrupados por día argentino (la misma regla que el
/// resto de la app: `Kickoff.argentinaDay`, deduplicados por `idEvent`).
final class MonthCalendar {
  MonthCalendar._(this.month, this.days);

  factory MonthCalendar.of(CalendarMonth month, Iterable<Match> matches) {
    final days = <CalendarDay, List<Match>>{};
    for (final group in MatchGrouping.byArgentinaDay(matches)) {
      final day = group.day;
      if (day != null && month.contains(day)) days[day] = group.matches;
    }
    return MonthCalendar._(month, days);
  }

  final CalendarMonth month;

  /// Días del mes con partidos, en orden; cada uno con sus partidos
  /// ordenados por hora.
  final Map<CalendarDay, List<Match>> days;

  List<Match> matchesOn(CalendarDay day) => days[day] ?? const [];

  int get matchCount => days.values.fold(0, (n, day) => n + day.length);

  /// Día que se muestra al abrir el mes. En el mes de hoy: hoy si tiene
  /// partidos; si no, el próximo con partidos; si no hay próximos, el
  /// último. En otro mes, el primero con partidos. `null` si el mes no tiene
  /// partidos.
  CalendarDay? defaultDay(CalendarDay today) {
    if (days.isEmpty) return null;
    if (!month.contains(today)) return days.keys.first;
    return days.keys.where((d) => !d.isBefore(today)).firstOrNull ??
        days.keys.last;
  }

  /// Partidos sin fecha conocida («Fecha por confirmar»): no caen en ningún
  /// mes.
  static List<Match> undated(Iterable<Match> matches) => [
    for (final group in MatchGrouping.byArgentinaDay(matches))
      if (group.day == null) ...group.matches,
  ];

  /// Meses con partidos, en orden.
  static List<CalendarMonth> monthsWithMatches(Iterable<Match> matches) => [
    ...{
      for (final group in MatchGrouping.byArgentinaDay(matches))
        if (group.day case final day?) CalendarMonth.of(day),
    },
  ];

  /// Mes que se muestra al abrir el calendario: el de hoy si cae entre el
  /// primero y el último con partidos; si no, el más cercano con partidos.
  /// Sin partidos: el de hoy en la temporada actual; en otra, el último
  /// (temporada pasada) o el primero (futura) de su año.
  static CalendarMonth initialMonth(
    Iterable<Match> matches, {
    required CalendarDay today,
    required Season season,
  }) {
    final current = CalendarMonth.of(today);
    final months = monthsWithMatches(matches);
    if (months.isEmpty) {
      if (season.year == today.year) return current;
      return CalendarMonth(season.year, season.year < today.year ? 12 : 1);
    }
    if (current.isBefore(months.first)) return months.first;
    if (current.isAfter(months.last)) return months.last;
    return current;
  }

  /// Meses a los que se puede ir: del primero al último con partidos,
  /// ampliado para incluir [shown].
  static ({CalendarMonth first, CalendarMonth last}) navigableRange(
    Iterable<Match> matches,
    CalendarMonth shown,
  ) {
    final months = monthsWithMatches(matches);
    if (months.isEmpty) return (first: shown, last: shown);
    return (
      first: shown.isBefore(months.first) ? shown : months.first,
      last: shown.isAfter(months.last) ? shown : months.last,
    );
  }
}
