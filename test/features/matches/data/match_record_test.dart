import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/matches/data/models/match_record.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';

import '../../../helpers/fixture_matches.dart';

void main() {
  test('ida y vuelta sin pérdida para partidos reales de todo tipo', () {
    for (final name in [
      'eventsround_4406_r12_s2026', // confirmados, tentativos, en juego
      'eventsround_4406_r0_s2026', // AET y PEN
      'eventsround_4616_r34_s2026', // sin resultado, sin strTimeLocal
    ]) {
      for (final m in fixtureMatches(name)) {
        expect(MatchRecord.fromMap(MatchRecord.toMap(m)), m, reason: '${m.id}');
      }
    }
  });

  test('conserva lo que produjo el merge', () {
    final original = fixtureMatches('eventsround_4406_r12_s2026').first;
    final merged = Match(
      id: original.id,
      competitionId: original.competitionId,
      competitionName: original.competitionName,
      season: original.season,
      apiRound: 13,
      home: original.home,
      away: original.away,
      kickoff: const Kickoff.unknown(),
      status: original.status,
      lastSeenAt: original.lastSeenAt,
      previousKickoffUtc: DateTime.utc(2026, 3, 20, 23),
      previousApiRound: 12,
      membership: MatchMembership.orphaned,
    );

    final roundTrip = MatchRecord.fromMap(MatchRecord.toMap(merged));

    expect(roundTrip, merged);
    expect(roundTrip.kickoff.argentinaDay, isNull);
  });

  test('guarda los ids de equipo para buscar por equipo', () {
    final m = fixtureMatches('eventsround_4406_r12_s2026').first;

    expect(MatchRecord.toMap(m)['teamIds'], [m.home.id, m.away.id]);
    expect(
      MatchRecord.toMap(m)['kickoff'],
      containsPair('day', const CalendarDay(2026, 3, 21).toString()),
    );
  });
}
