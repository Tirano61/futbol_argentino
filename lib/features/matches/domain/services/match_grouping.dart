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

  /// Disputado: terminado, o con fecha pasada y sin estar en juego (un
  /// partido viejo sin actualizar no se muestra como próximo).
  static bool isPlayed(Match m, CalendarDay today) {
    if (m.status.isFinished) return true;
    if (m.status.isInPlay) return false;
    final day = m.kickoff.argentinaDay;
    return day != null && day.isBefore(today);
  }

  /// En vivo (D11): en juego según la API, o con inicio hace menos de
  /// [liveWindow] y sin terminar (la API suele tardar en pasarlo a `1H`).
  /// Misma regla que la vigencia `live` de las rondas (`RoundCachePolicy`).
  static bool isLive(Match m, DateTime now) {
    if (m.status.isInPlay) return true;
    final start = m.kickoff.utc;
    return start != null &&
        !now.isBefore(start) &&
        now.difference(start) < liveWindow &&
        !m.status.isFinished;
  }

  static const liveWindow = Duration(hours: 3);

  /// Hay al menos un partido en vivo ([isLive]).
  static bool anyLive(Iterable<Match> matches, DateTime now) =>
      matches.any((m) => isLive(m, now));

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
