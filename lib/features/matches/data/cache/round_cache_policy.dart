import '../../../../core/cache/cache_class.dart';
import '../../../../core/time/argentina_time.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_status.dart';
import '../../domain/services/match_grouping.dart';
import '../../domain/services/round_merge_policy.dart';

/// Vigencia de una ronda guardada según sus partidos (§5.5).
abstract final class RoundCachePolicy {
  static CacheClass classify({
    required List<Match> matches,
    required ResponseQuality quality,
    required DateTime now,
  }) {
    if (quality == ResponseQuality.partial ||
        quality == ResponseQuality.suspectEmpty) {
      return CacheClass.retrySoon;
    }
    if (matches.isEmpty) return CacheClass.empty;

    final today = ArgentinaTime.dayOf(now);
    final inAWeek = today.addDays(7);
    final recent = today.addDays(-2);
    var allSettled = true;
    var upcoming = false;
    var hasToday = false;
    DateTime? lastStart;

    for (final m in matches) {
      final start = m.kickoff.utc;
      final day = m.kickoff.argentinaDay;

      if (MatchGrouping.isLive(m, now)) return CacheClass.live;

      if (day == today) hasToday = true;
      if (!_isSettled(m.status.kind)) {
        allSettled = false;
        // Jugado hace poco y sin resultado todavía: se sigue como «hoy».
        if (day != null && day.isBefore(today) && !day.isBefore(recent)) {
          hasToday = true;
        }
        if (day != null && !day.isBefore(today) && !day.isAfter(inAWeek)) {
          upcoming = true;
        }
      }
      if (start != null && (lastStart == null || start.isAfter(lastStart))) {
        lastStart = start;
      }
    }

    if (hasToday) return CacheClass.today;
    if (upcoming) return CacheClass.upcoming;
    if (allSettled &&
        lastStart != null &&
        now.difference(lastStart) > const Duration(hours: 48)) {
      return CacheClass.closed;
    }
    return CacheClass.future;
  }

  /// Estados que ya no van a cambiar solos.
  static bool _isSettled(MatchStatusKind kind) => switch (kind) {
    MatchStatusKind.finished ||
    MatchStatusKind.cancelled ||
    MatchStatusKind.abandoned => true,
    _ => false,
  };
}
