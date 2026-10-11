import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/services/match_grouping.dart';

import '../../../helpers/fixture_matches.dart';

void main() {
  final matches = fixtureMatches('eventsround_4406_r12_s2026');

  test('agrupa por día argentino, en orden', () {
    final groups = MatchGrouping.byArgentinaDay(matches);

    final days = groups.map((g) => g.day!).toList();
    expect(days, [...days]..sort());
    expect(groups.fold<int>(0, (n, g) => n + g.matches.length), 30);
  });

  test('00:30 UTC del 11/10 aparece el 10/10 (día argentino)', () {
    final groups = MatchGrouping.byArgentinaDay(matches);

    final october10 = groups.singleWhere(
      (g) => g.day == const CalendarDay(2026, 10, 10),
    );
    expect(october10.matches.map((m) => m.id), contains(2398125));
  });

  test('dentro del día: por hora, y los no confirmados al final', () {
    final groups = MatchGrouping.byArgentinaDay(matches);
    // 21/03/2026 incluye partidos tentativos de 00:00 UTC.
    final march21 = groups.singleWhere(
      (g) => g.day == const CalendarDay(2026, 3, 21),
    );
    final certainties = march21.matches
        .map((m) => m.kickoff.certainty)
        .toList();

    final firstUnconfirmed = certainties.indexWhere(
      (c) => c != KickoffCertainty.confirmed,
    );
    expect(firstUnconfirmed, greaterThan(0));
    expect(
      certainties
          .skip(firstUnconfirmed)
          .every((c) => c != KickoffCertainty.confirmed),
      isTrue,
    );
    final times = march21.matches
        .take(firstUnconfirmed)
        .map((m) => m.kickoff.utc!)
        .toList();
    expect(times, [...times]..sort());
  });

  test('sin fecha conocida va al final', () {
    final noDate = rebuild(matches.first, kickoff: const Kickoff.unknown());

    final groups = MatchGrouping.byArgentinaDay([noDate, ...matches.skip(1)]);

    expect(groups.last.day, isNull);
    expect(groups.last.matches.single.id, noDate.id);
  });

  test('deduplica por idEvent quedándose con el más reciente', () {
    final old = rebuild(matches.first, lastSeenAt: DateTime.utc(2026, 1, 1));
    final fresh = rebuild(matches.first, lastSeenAt: DateTime.utc(2026, 10, 1));

    final result = MatchGrouping.dedupe([old, fresh, old]);

    expect(result.single.lastSeenAt, DateTime.utc(2026, 10, 1));
  });
}
