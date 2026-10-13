import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/watch_standings.dart';
import 'package:sembast/sembast_memory.dart';

import '../../../helpers/fake_clock.dart';
import '../../../helpers/recorded_api.dart';

/// T13.4 con repositorios reales y respuestas grabadas (11/10/2026).
void main() {
  late FakeClock clock;
  late RecordedApi api;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 11, 20, 35));
    api = RecordedApi(
      clock: clock,
      db: await newDatabaseFactoryMemory().openDatabase('app.db'),
    );
  });

  Stream<StandingsView> watch(
    int competitionId,
    int year, {
    CancelToken? token,
    bool forceRefresh = false,
  }) => WatchStandings(api.matches)(
    competitionId,
    Season(year),
    now: clock.now(),
    cancelToken: token ?? CancelToken(),
    forceRefresh: forceRefresh,
  );

  test('en frío: 16 peticiones (fechas 1–16, sin la ronda 0) y las 5 '
      'tablas', () async {
    final views = await watch(4406, 2026).toList();
    final last = views.last;

    expect(api.requests, hasLength(16));
    expect(api.requestLabels, isNot(contains('4406:r0:s2026')));
    expect(last.progress.isRunning, isFalse);
    expect(last.progress.fetched, 16);
    expect(last.zoneIssues, isEmpty);
    expect(last.tables.map((t) => t.key), [
      'anual',
      'apertura-a',
      'apertura-b',
      'clausura-a',
      'clausura-b',
    ]);
    expect(last.table('anual')!.rows, hasLength(30));
    expect(last.table('anual')!.coverage.roundsQueried, 16);
    expect(last.table('anual')!.coverage.roundsTotal, 16);
  });

  test('recalcula a medida que llegan las fechas', () async {
    final views = await watch(4406, 2026).toList();

    // Primera emisión: nada guardado todavía.
    expect(views.first.hasMatches, isFalse);
    expect(views.first.progress.isRunning, isTrue);
    final queried = [
      for (final v in views.skip(1))
        v.table('anual')?.coverage.roundsQueried ?? 0,
    ];
    // Una emisión por fecha y la de cierre (ya sin descarga en curso).
    expect(queried, [for (var r = 1; r <= 16; r++) r, 16]);
    expect(views.last.progress.isRunning, isFalse);
    final counted = [
      for (final v in views.skip(1)) v.table('anual')!.coverage.counted,
    ];
    for (var i = 1; i < counted.length; i++) {
      expect(counted[i], greaterThanOrEqualTo(counted[i - 1]));
    }
  });

  test('en caliente: 0 peticiones, una sola emisión', () async {
    await watch(4406, 2026).last;
    api.requests.clear();

    final views = await watch(4406, 2026).toList();

    expect(api.requests, isEmpty);
    expect(views, hasLength(1));
    expect(views.single.progress.fetched, 0);
    expect(views.single.tables, hasLength(5));
  });

  test('refresco manual: fuerza solo las fechas con partidos sin terminar '
      'de ayer y hoy', () async {
    await watch(4406, 2026).last;
    api.requests.clear();
    clock.advance(const Duration(minutes: 1));

    final last = await watch(4406, 2026, forceRefresh: true).last;

    // Al 11/10 solo la fecha 12 tiene partidos de ayer/hoy sin terminar.
    expect(api.requestLabels, ['4406:r12:s2026']);
    expect(last.progress.fetched, 1);
  });

  test(
    'Copa, Primera 2025 y Nacional 2025: sin tablas y sin peticiones',
    () async {
      for (final (id, year) in [(4500, 2026), (4406, 2025), (4616, 2025)]) {
        final views = await watch(id, year).toList();
        expect(views.single.isAvailable, isFalse);
      }
      expect(api.requests, isEmpty);
    },
  );

  test('Nacional en frío: 36 peticiones (fechas 1–36) y las 2 tablas de '
      'zona', () async {
    final views = await watch(4616, 2026).toList();
    final last = views.last;

    expect(api.requests, hasLength(36));
    expect(api.requestLabels.toSet(), {
      for (var r = 1; r <= 36; r++) '4616:r$r:s2026',
    });
    expect(last.progress.isRunning, isFalse);
    expect(last.progress.fetched, 36);
    expect(last.zoneIssues, isEmpty);
    expect(last.tables.map((t) => t.key), ['zona-a', 'zona-b']);
    expect(last.tables.map((t) => t.shortTitle), ['Zona A', 'Zona B']);
    for (final t in last.tables) {
      expect(t.rows, hasLength(18));
      expect(t.coverage.roundsQueried, 36);
      expect(t.coverage.roundsTotal, 36);
    }
  });

  test('Nacional en caliente: 0 peticiones, una sola emisión', () async {
    await watch(4616, 2026).last;
    api.requests.clear();

    final views = await watch(4616, 2026).toList();

    expect(api.requests, isEmpty);
    expect(views, hasLength(1));
    expect(views.single.tables, hasLength(2));
  });

  test('Nacional con zonas que no coinciden (armadas en el test): sin '
      'tablas y con el motivo', () async {
    const real = CompetitionCatalog.primeraNacional;
    final format = real.standingsFor(const Season(2026)) as LeagueZones;
    // Ferro (Zona A) pasado a la Zona B: armado para probar la regla.
    final wrong = CompetitionDefinition(
      id: real.id,
      name: real.name,
      shortName: real.shortName,
      format: real.format,
      rules: real.rules,
      standingsBySeason: {
        2026: LeagueZones(
          zones: {
            'A': {...format.zones['A']!}..remove(137774),
            'B': {...format.zones['B']!, 137774},
          },
          regularRounds: format.regularRounds,
          interzonalsPerTeam: format.interzonalsPerTeam,
          tieBreak: format.tieBreak,
          tableArticle: format.tableArticle,
          tieBreakArticle: format.tieBreakArticle,
          relegationNote: format.relegationNote,
          regulation: format.regulation,
        ),
      },
    );

    final last = await WatchStandings(api.matches, catalog: [wrong])(
      4616,
      const Season(2026),
      now: clock.now(),
      cancelToken: CancelToken(),
    ).last;

    expect(last.hasMatches, isTrue);
    expect(last.tables, isEmpty);
    expect(last.zoneIssues, contains(startsWith('Ferro Carril Oeste tiene')));
  });

  test('sin red y sin nada guardado: termina con el error', () async {
    api.offline = true;

    final last = await watch(4406, 2026).last;

    expect(last.hasMatches, isFalse);
    expect(last.progress.isRunning, isFalse);
    expect(last.progress.failure, isA<NetworkFailure>());
  });

  test('cancelar detiene la descarga', () async {
    final token = CancelToken();
    final done = Completer<void>();
    final sub = watch(4406, 2026, token: token).listen((v) {
      if (v.progress.done >= 3 && !token.isCancelled) {
        token.cancel();
        done.complete();
      }
    });
    await done.future;
    final atCancel = api.requests.length;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(api.requests.length, lessThanOrEqualTo(atCancel + 1));
    expect(api.requests.length, lessThan(16));
  });
}
