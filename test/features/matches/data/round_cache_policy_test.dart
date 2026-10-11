import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/cache/cache_class.dart';
import 'package:futbol_argentino/features/matches/data/cache/round_cache_policy.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/services/round_merge_policy.dart';

import '../../../helpers/fixture_matches.dart';

CacheClass classify(
  String fixture,
  DateTime now, {
  ResponseQuality quality = ResponseQuality.complete,
}) => RoundCachePolicy.classify(
  matches: fixtureMatches(fixture),
  quality: quality,
  now: now,
);

void main() {
  // Momento de la grabación: 11/10/2026 17:35 ART.
  final recordedAt = DateTime.utc(2026, 10, 11, 20, 35);

  test('ronda con partidos en juego: live (2 min)', () {
    // Primera Nacional fecha 33 se grabó con partidos 1H, HT y 2H.
    expect(classify('eventsround_4616_r33_s2026', recordedAt), CacheClass.live);
  });

  test('ronda terminada hace meses: closed (30 días)', () {
    expect(
      classify('eventsround_4406_r1_s2026', recordedAt),
      CacheClass.closed,
    );
  });

  test('ronda dentro de la semana: upcoming (1 h)', () {
    // Nacional fecha 34: 17 y 18 de octubre.
    expect(
      classify('eventsround_4616_r34_s2026', recordedAt),
      CacheClass.upcoming,
    );
  });

  test('ronda a más de 7 días: future (12 h)', () {
    // Copa Argentina semifinales: 25 de octubre.
    expect(
      classify('eventsround_4500_r150_s2026', recordedAt),
      CacheClass.future,
    );
  });

  test('partidos de hoy aún no empezados: today (10 min)', () {
    // Nacional fecha 35 (24–25/10, grabada sin empezar), a las 09:00 ART
    // del 24/10.
    expect(
      classify('eventsround_4616_r35_s2026', DateTime.utc(2026, 10, 24, 12)),
      CacheClass.today,
    );
  });

  test('jugado ayer y todavía sin resultado: se sigue como today', () {
    final matches = [
      for (final m in fixtureMatches('eventsround_4616_r34_s2026'))
        rebuild(m, status: const MatchStatus.scheduled()),
    ];

    // 19/10: la fecha 34 (17–18/10) sigue figurando como no jugada.
    final result = RoundCachePolicy.classify(
      matches: matches,
      quality: ResponseQuality.complete,
      now: DateTime.utc(2026, 10, 19, 15),
    );

    expect(result, CacheClass.today);
  });

  test('respuesta parcial o vacía sospechosa: reintentar en 15 min', () {
    expect(
      classify(
        'eventsround_4406_r1_s2026',
        recordedAt,
        quality: ResponseQuality.partial,
      ),
      CacheClass.retrySoon,
    );
  });

  test('ronda vacía: 24 h', () {
    expect(
      RoundCachePolicy.classify(
        matches: const [],
        quality: ResponseQuality.empty,
        now: recordedAt,
      ),
      CacheClass.empty,
    );
  });
}
