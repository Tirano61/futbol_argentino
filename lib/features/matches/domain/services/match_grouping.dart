import '../../../../core/time/calendar_day.dart';
import '../entities/match.dart';

/// Partidos de un mismo día argentino.
final class MatchDayGroup {
  const MatchDayGroup({required this.day, required this.matches});

  /// `null`: partidos sin fecha conocida (van al final).
  final CalendarDay? day;
  final List<Match> matches;
}

abstract final class MatchGrouping {
  /// Orden: día argentino (sin fecha al final) → con hora confirmada por
  /// hora → sin hora confirmada → `idEvent`.
  static int compare(Match a, Match b) {
    final dayA = a.kickoff.argentinaDay;
    final dayB = b.kickoff.argentinaDay;
    if (dayA != dayB) {
      if (dayA == null) return 1;
      if (dayB == null) return -1;
      return dayA.compareTo(dayB);
    }
    final timeA = a.kickoff.confirmedUtc;
    final timeB = b.kickoff.confirmedUtc;
    if (timeA != null && timeB != null && timeA != timeB) {
      return timeA.compareTo(timeB);
    }
    if ((timeA == null) != (timeB == null)) return timeA == null ? 1 : -1;
    return a.id.compareTo(b.id);
  }

  /// Un partido por `idEvent`: gana el visto más recientemente.
  static List<Match> dedupe(Iterable<Match> matches) {
    final byId = <int, Match>{};
    for (final m in matches) {
      final current = byId[m.id];
      if (current == null || m.lastSeenAt.isAfter(current.lastSeenAt)) {
        byId[m.id] = m;
      }
    }
    return byId.values.toList();
  }

  static List<Match> sorted(Iterable<Match> matches) =>
      dedupe(matches)..sort(compare);

  /// Deduplica, ordena y agrupa por día argentino.
  static List<MatchDayGroup> byArgentinaDay(Iterable<Match> matches) {
    final groups = <MatchDayGroup>[];
    for (final m in sorted(matches)) {
      final day = m.kickoff.argentinaDay;
      if (groups.isEmpty || groups.last.day != day) {
        groups.add(MatchDayGroup(day: day, matches: [m]));
      } else {
        groups.last.matches.add(m);
      }
    }
    return groups;
  }
}
