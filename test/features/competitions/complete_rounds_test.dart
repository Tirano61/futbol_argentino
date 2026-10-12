import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season_completion.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/complete_rounds.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fixture_matches.dart';
import '../../helpers/recorded_api.dart';

const primera = 4406;
const nacional = 4616;
const copa = 4500;

/// Fase 12: historial a pedido con repositorios reales y respuestas
/// grabadas (11/10/2026): presupuestos en frío y en caliente, rondas que no
/// se vuelven a pedir, cupo P2, cancelación y error.
void main() {
  late FakeClock clock;
  late DateTime start;
  late RecordedApi api;

  setUp(() async {
    start = DateTime.utc(2026, 10, 11, 20, 35);
    clock = FakeClock(start);
    api = RecordedApi(
      clock: clock,
      db: await newDatabaseFactoryMemory().openDatabase('app.db'),
    );
  });

  CompleteRounds complete() => CompleteRounds(api.matches);

  Future<SeasonCompletion> load(
    int competitionId,
    int year, {
    List<int>? rounds,
    bool forceRefresh = false,
  }) => complete()(
    competitionId,
    Season(year),
    now: clock.now(),
    cancelToken: CancelToken(),
    rounds: rounds,
    forceRefresh: forceRefresh,
  ).last;

  Set<RoundCompletionStatus> statuses(SeasonCompletion c) => {
    for (final r in c.rounds) r.status,
  };

  group('en frío', () {
    test('Primera 2026 completa: 17 rondas (fechas 1–16 + ronda 0)', () async {
      final result = await load(primera, 2026);

      expect(result.rounds.map((r) => r.apiRound), [
        for (var r = 1; r <= 16; r++) r,
        0,
      ]);
      expect(api.requests, hasLength(17));
      expect(statuses(result), {RoundCompletionStatus.fetched});
      expect(result.progress.isRunning, isFalse);
      expect(result.progress.done, 17);
      expect(result.progress.total, 17);
      expect(result.progress.fetched, 17);
      expect(result.progress.failure, isNull);
      // 15 fechas × 30 + fecha 16 (30 + 8 octavos) + 7 de la ronda 0.
      expect(result.matches, hasLength(495));
    });

    test('Primera 2026, solo las fechas regulares 1–16: 16', () async {
      final result = await load(
        primera,
        2026,
        rounds: [for (var r = 1; r <= 16; r++) r],
      );

      expect(api.requests, hasLength(16));
      expect(api.requestLabels, isNot(contains('4406:r0:s2026')));
      expect(result.progress.done, 16);
    });

    test('Primera Nacional 2026: 36', () async {
      final result = await load(nacional, 2026);

      expect(api.requests, hasLength(36));
      expect(result.progress.done, 36);
      expect(result.matches, hasLength(648));
    });

    test('Copa Argentina 2026: 6', () async {
      final result = await load(copa, 2026);

      expect(api.requestLabels, [
        '4500:r64:s2026',
        '4500:r32:s2026',
        '4500:r16:s2026',
        '4500:r125:s2026',
        '4500:r150:s2026',
        '4500:r200:s2026',
      ]);
      expect(result.progress.done, 6);
    });

    test('Primera 2025: 16 (sin eliminatorias verificadas)', () async {
      final result = await load(primera, 2025);

      expect(api.requests, hasLength(16));
      expect(result.matches, hasLength(480));
    });

    test('P2: como mucho 10 rondas por minuto, de a una', () async {
      await load(primera, 2026);

      final offsets = [for (final t in api.requestTimes) t.difference(start)];
      expect(
        offsets.where((d) => d < const Duration(minutes: 1)),
        hasLength(10),
      );
      expect(
        offsets.where(
          (d) =>
              d >= const Duration(minutes: 1) && d < const Duration(minutes: 2),
        ),
        hasLength(7),
      );
    });
  });

  group('en caliente', () {
    test('ninguna petición: todo vigente', () async {
      await load(primera, 2026);
      api.requests.clear();

      final emissions = await complete()(
        primera,
        const Season(2026),
        now: clock.now(),
        cancelToken: CancelToken(),
      ).toList();

      expect(api.requests, isEmpty);
      // Una sola emisión, ya terminada: no hay nada que consultar.
      expect(emissions, hasLength(1));
      final result = emissions.single;
      expect(statuses(result), {RoundCompletionStatus.fresh});
      expect(result.progress.isRunning, isFalse);
      expect(result.progress.done, 17);
      expect(result.progress.fetched, 0);
      expect(result.matches, hasLength(495));
    });

    test('temporada anterior terminada: vencida, no se vuelve a pedir '
        '(histórica)', () async {
      await load(primera, 2025);
      api.requests.clear();
      clock.advance(const Duration(days: 60));

      final result = await load(primera, 2025);

      expect(api.requests, isEmpty);
      expect(statuses(result), {RoundCompletionStatus.historic});
      expect(result.progress.done, 16);
    });

    test(
      'con refresco manual, la temporada anterior sí se vuelve a pedir',
      () async {
        await load(primera, 2025);
        api.requests.clear();
        clock.advance(const Duration(days: 60));

        final result = await load(primera, 2025, forceRefresh: true);

        expect(api.requests, hasLength(16));
        expect(statuses(result), {RoundCompletionStatus.fetched});
      },
    );

    test('temporada actual a los 31 días: solo las rondas que pueden '
        'cambiar', () async {
      await load(primera, 2026);
      final settled = <String>{};
      for (var r = 0; r <= 16; r++) {
        final state = await api.matches.roundCacheState(
          RoundQuery(competitionId: primera, season: '2026', apiRound: r),
        );
        if (state.isClosed) settled.add('4406:r$r:s2026');
      }
      api.requests.clear();
      clock.advance(const Duration(days: 31));

      final result = await load(primera, 2026);

      // Cerradas al 11/10: la ronda 0 (mayo) y las fechas 1–10. Se piden la
      // 11 (un partido reprogramado al 14/10), la 12 (en juego) y la 13–16.
      expect(settled, {for (var r = 0; r <= 10; r++) '4406:r$r:s2026'});
      expect(api.requestLabels.toSet().intersection(settled), isEmpty);
      expect(api.requests, hasLength(6));
      expect([
        for (final r in result.rounds)
          if (r.status == RoundCompletionStatus.settled) r.apiRound,
      ], hasLength(settled.length));
    });

    test('rondas ya guardadas por otra pantalla no se piden', () async {
      await api.matches.syncRound(
        const RoundQuery(competitionId: copa, season: '2026', apiRound: 64),
      );
      api.requests.clear();

      final result = await load(copa, 2026);

      expect(api.requests, hasLength(5));
      expect(api.requestLabels, isNot(contains('4500:r64:s2026')));
      expect(result.rounds.first.status, RoundCompletionStatus.fresh);
    });
  });

  test('emite lo guardado antes de terminar', () async {
    await load(copa, 2026, rounds: [64]);

    final emissions = await complete()(
      copa,
      const Season(2026),
      now: clock.now(),
      cancelToken: CancelToken(),
    ).toList();

    final first = emissions.first;
    expect(first.progress.isRunning, isTrue);
    expect(first.progress.done, 1);
    expect(first.progress.total, 6);
    expect(first.matches, hasLength(32));
    expect(emissions.last.matches, hasLength(62));
  });

  test('cancelar detiene la descarga: no hay más peticiones', () async {
    final token = CancelToken();
    final stopped = Completer<void>();
    final emissions = <SeasonCompletion>[];
    final sub =
        complete()(
          nacional,
          const Season(2026),
          now: clock.now(),
          cancelToken: token,
        ).listen((c) {
          emissions.add(c);
          if (c.progress.done >= 3 && !token.isCancelled) {
            token.cancel();
            stopped.complete();
          }
        });
    await stopped.future;
    final atCancel = api.requests.length;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    // Como mucho termina la ronda que ya estaba en curso.
    expect(api.requests.length, lessThanOrEqualTo(atCancel + 1));
    expect(api.requests.length, lessThan(36));
    expect(api.scheduler.pending, 0);
    expect(emissions.last.progress.isRunning, isTrue);
  });

  test('un error detiene la descarga y lo informa', () async {
    await load(copa, 2026, rounds: [64, 32]);
    api.offline = true;

    final result = await load(copa, 2026);

    expect(result.progress.isRunning, isFalse);
    expect(result.progress.failure, isA<NetworkFailure>());
    expect(result.progress.done, 2);
    expect(result.progress.fetched, 0);
    // Lo guardado sigue disponible.
    expect(result.matches, hasLength(48));
  });

  group('classify (estados armados en el test sobre partidos reales)', () {
    final finished = fixtureMatches('eventsround_4406_r1_s2025');
    final scheduled = [
      for (final m in fixtureMatches('eventsround_4406_r16_s2026'))
        if (m.status.isScheduled) m,
    ];
    const stale = RoundCacheState(
      freshness: RoundFreshness.stale,
      isClosed: true,
      isComplete: true,
    );

    RoundCompletionStatus classify(
      RoundCacheState state,
      List<dynamic> stored, {
      bool finishedSeason = false,
      bool force = false,
    }) => CompleteRounds.classify(
      state,
      [...stored.cast()],
      seasonFinished: finishedSeason,
      forceRefresh: force,
    );

    test('falta y vigente', () {
      expect(
        classify(RoundCacheState.missing, const []),
        RoundCompletionStatus.missing,
      );
      expect(
        classify(
          const RoundCacheState(freshness: RoundFreshness.fresh),
          scheduled,
        ),
        RoundCompletionStatus.fresh,
      );
      // Vigente: tampoco con refresco manual.
      expect(
        classify(
          const RoundCacheState(freshness: RoundFreshness.fresh),
          finished,
          force: true,
        ),
        RoundCompletionStatus.fresh,
      );
    });

    test('cerrada y vencida: no se pide si todo tiene resultado', () {
      expect(classify(stale, finished), RoundCompletionStatus.settled);
      expect(
        classify(stale, finished, finishedSeason: true),
        RoundCompletionStatus.historic,
      );
      expect(
        classify(stale, finished, force: true),
        RoundCompletionStatus.stale,
      );
    });

    test('se pide si hay partidos sin resultado', () {
      expect(
        classify(stale, [...finished, scheduled.first]),
        RoundCompletionStatus.stale,
      );
      final noScore = rebuild(finished.first, clearScore: true);
      expect(
        classify(stale, [noScore], finishedSeason: true),
        RoundCompletionStatus.stale,
      );
    });

    test('respuesta incompleta o ronda no cerrada: se pide', () {
      expect(
        classify(
          const RoundCacheState(
            freshness: RoundFreshness.stale,
            isClosed: true,
          ),
          finished,
          finishedSeason: true,
        ),
        RoundCompletionStatus.stale,
      );
      expect(
        classify(
          const RoundCacheState(
            freshness: RoundFreshness.stale,
            isComplete: true,
          ),
          finished,
        ),
        RoundCompletionStatus.stale,
      );
    });

    test('postergado: final solo en una temporada terminada', () {
      final postponed = rebuild(
        finished.first,
        clearScore: true,
        status: const MatchStatus(kind: MatchStatusKind.postponed),
      );
      expect(classify(stale, [postponed]), RoundCompletionStatus.stale);
      expect(
        classify(stale, [postponed], finishedSeason: true),
        RoundCompletionStatus.historic,
      );
    });
  });
}
