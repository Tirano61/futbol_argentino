import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/entities/score.dart';
import 'package:futbol_argentino/features/matches/domain/services/tie_pairing.dart';

import '../../../helpers/fixture_matches.dart';
import '../../../helpers/fixtures.dart';

/// Emparejamiento de las piernas de ida y vuelta con partidos reales
/// grabados (la API no tiene un id de serie).
void main() {
  String names(List<dynamic> ties) =>
      ties.map((t) => '${t.first.name} - ${t.second.name}').join(' / ');

  test('octavos de la Libertadores 2025: 16 partidos, 8 series de dos '
      'piernas, en el orden de la ida', () {
    final pairs = TiePairing.pair(
      fixtureMatches('eventsround_4501_r16_s2025'),
      legs: 2,
    );
    expect(pairs.unpaired, isEmpty);
    expect(pairs.ties, hasLength(8));
    expect(pairs.ties.every((t) => t.legs.length == 2), isTrue);
    expect(pairs.ties.every((t) => t.isComplete), isTrue);
    expect(pairs.ties.first.first.name, 'Fortaleza');
    expect(pairs.ties.first.second.name, 'Vélez Sarsfield');
    // La ida antes que la vuelta, con los locales invertidos.
    for (final t in pairs.ties) {
      expect(t.legs.first.home.id, t.legs.last.away.id);
      expect(
        t.legs.first.kickoff.utc!.isBefore(t.legs.last.kickoff.utc!),
        isTrue,
      );
    }
  });

  test('el global suma las dos piernas en el orden de la llave', () {
    final pairs = TiePairing.pair(
      fixtureMatches('eventsround_4501_r16_s2025'),
      legs: 2,
    );
    // Fortaleza 0-0 Vélez; Vélez 2-0 Fortaleza.
    final velez = pairs.ties.first;
    expect(velez.scoreOf(velez.legs.last), const Score(home: 0, away: 2));
    expect(velez.aggregate, const Score(home: 0, away: 2));
    // Peñarol 1-0 Racing; Racing 3-1 Peñarol.
    final racing = pairs.ties.singleWhere((t) => t.involvesTeam(135170));
    expect(racing.first.name, 'Peñarol');
    expect(racing.aggregate, const Score(home: 2, away: 3));
  });

  test('la tanda de la vuelta se lee en el orden de la llave', () {
    // Ida Palmeiras 1-0 LDU; vuelta LDU 3-2 Palmeiras, 3-4 en penales.
    final tie = TiePairing.pair(
      fixtureMatches('eventsround_4501_r125_s2026'),
      legs: 2,
    ).ties.singleWhere((t) => t.first.name == 'Palmeiras');
    expect(tie.aggregate, const Score(home: 3, away: 3));
    expect(tie.decisive.status.decidedBy, MatchDecision.penalties);
    expect(tie.penalties, const Score(home: 4, away: 3));
  });

  test('una serie con la vuelta sin jugar está incompleta y sin global; '
      'en juego, el global parcial cuenta lo que va', () {
    final pairs = TiePairing.pair(
      fixtureMatches('eventsround_4501_r150_s2026'),
      legs: 2,
    );
    expect(pairs.ties, hasLength(2));
    final live = pairs.ties.first;
    expect(live.first.name, 'Fluminense');
    expect(live.legs.first.status.isInPlay, isTrue);
    expect(live.isComplete, isFalse);
    expect(live.aggregate, isNull);
    expect(live.partialAggregate, const Score(home: 0, away: 0));
    expect(live.current.id, live.legs.first.id);
    expect(pairs.ties.last.partialAggregate, isNull);
  });

  test('una sola pierna guardada queda como serie incompleta', () {
    final round = fixtureMatches('eventsround_4724_r150_s2026');
    final pairs = TiePairing.pair(round.take(3), legs: 2);
    expect(pairs.unpaired, isEmpty);
    expect(pairs.ties.map((t) => t.legs.length), [2, 1]);
    expect(pairs.ties.last.isComplete, isFalse);
  });

  test('más de dos partidos con el mismo par: el dato no cierra y no se '
      'elige ninguno', () {
    final events = fixtureEvents('eventsround_4501_r16_s2025');
    final round = [for (final e in events) matchFromEvent(e)];
    final fortaleza = events.firstWhere((e) => e['strHomeTeam'] == 'Fortaleza');
    // El mismo partido con otro idEvent (un duplicado de la API).
    final third = matchFromEvent({
      ...fortaleza,
      'idEvent': '${int.parse(fortaleza['idEvent'] as String) + 1000000}',
    });
    final pairs = TiePairing.pair([...round, third], legs: 2);
    expect(pairs.ties, hasLength(7));
    expect(pairs.unpaired, hasLength(3));
    expect(pairs.unpaired.every((m) => m.involvesTeam(third.home.id)), isTrue);
  });

  test('a un partido: cada partido es una llave', () {
    final pairs = TiePairing.pair(
      fixtureMatches('eventsround_4500_r125_s2026'),
      legs: 1,
    );
    expect(pairs.ties, hasLength(4));
    expect(pairs.ties.every((t) => !t.isSeries), isTrue);
    expect(names(pairs.ties), isNotEmpty);
  });
}
