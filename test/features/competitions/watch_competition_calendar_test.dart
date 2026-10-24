import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:http/http.dart' as http;
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/watch_competition_calendar.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/recorded_api.dart';

const primera = 4406;
const nacional = 4616;
const copa = 4500;

/// Fase 18: calendario de una temporada con repositorios reales y
/// respuestas grabadas (11/10/2026). Al abrirse solo lee lo guardado; las
/// fechas que faltan se piden solo si se pide.
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

  Stream<CompetitionCalendar> watch(
    int competitionId, {
    int year = 2026,
    bool download = false,
    bool forceRefresh = false,
  }) => WatchCompetitionCalendar(api.matches)(
    competitionId,
    Season(year),
    now: clock.now(),
    cancelToken: CancelToken(),
    download: download,
    forceRefresh: forceRefresh,
  );

  Future<void> storeRound(int competitionId, int apiRound) =>
      api.matches.syncRound(
        RoundQuery(
          competitionId: competitionId,
          season: '2026',
          apiRound: apiRound,
        ),
        priority: SyncPriority.visible,
      );

  test('al abrirse: solo lo guardado, sin peticiones', () async {
    await storeRound(primera, 12);
    api.requests.clear();

    final emissions = await watch(primera).toList();

    expect(api.requests, isEmpty);
    final calendar = emissions.single;
    expect(calendar.matches, hasLength(30));
    expect(calendar.roundsTotal, 17);
    expect(calendar.roundsStored, 1);
    expect(calendar.roundsPending, 16);
    expect(calendar.progress.isRunning, isFalse);
    expect(calendar.progress.fetched, 0);
  });

  test('sin nada guardado: vacío, sin peticiones', () async {
    final calendar = (await watch(nacional).toList()).single;

    expect(api.requests, isEmpty);
    expect(calendar.matches, isEmpty);
    expect(calendar.roundsTotal, 36);
    expect(calendar.roundsStored, 0);
    expect(calendar.roundsPending, 36);
  });

  group('completar a pedido (P2)', () {
    test('Primera 2026 en frío: 17 (fechas 1–16 y la ronda 0); '
        'en caliente 0', () async {
      final calendar = await watch(primera, download: true).last;

      expect(api.requests, hasLength(17));
      expect(calendar.matches, hasLength(495));
      expect(calendar.roundsPending, 0);
      expect(calendar.roundsStored, 17);
      expect(calendar.progress.fetched, 17);
      expect(calendar.progress.done, 17);

      api.requests.clear();
      final again = await watch(primera, download: true).toList();
      expect(api.requests, isEmpty);
      expect(again, hasLength(1));
      expect(again.single.matches, hasLength(495));
    });

    test('solo pide lo que falta', () async {
      await storeRound(primera, 12);
      await storeRound(primera, 13);
      api.requests.clear();

      await watch(primera, download: true).last;

      expect(api.requests, hasLength(15));
      expect(
        api.requestLabels,
        isNot(anyOf(contains('4406:r12:s2026'), contains('4406:r13:s2026'))),
      );
    });

    test('Nacional 2026: 36; Copa 2026: 6', () async {
      expect(
        (await watch(nacional, download: true).last).matches,
        hasLength(648),
      );
      expect(api.requests, hasLength(36));
      api.requests.clear();

      expect((await watch(copa, download: true).last).matches, hasLength(62));
      expect(api.requests, hasLength(6));
    });

    test('el avance se emite fecha por fecha', () async {
      final emissions = await watch(copa, download: true).toList();

      expect(emissions.first.progress.isRunning, isTrue);
      expect(emissions.first.progress.done, 0);
      expect(emissions.last.progress.isRunning, isFalse);
      expect([
        for (final e in emissions) e.matches.length,
      ], orderedEquals([...emissions.map((e) => e.matches.length)]..sort()));
    });

    test('sin red: se detiene con el error y muestra lo guardado', () async {
      await storeRound(primera, 12);
      api.offline = true;

      final calendar = await watch(primera, download: true).last;

      expect(calendar.matches, hasLength(30));
      expect(calendar.progress.failure, isNotNull);
      expect(calendar.roundsPending, 16);
    });
  });

  test('refresco manual: fuerza la fecha en juego y completa', () async {
    await watch(primera, download: true).last;
    api.requests.clear();
    // Después del mínimo entre refrescos: la fecha 12 tiene partidos en
    // juego hoy.
    clock.advance(const Duration(minutes: 1));

    final calendar = await watch(primera, forceRefresh: true).last;

    expect(api.requestLabels, contains('4406:r12:s2026'));
    expect(calendar.progress.fetched, greaterThan(0));
    expect(calendar.roundsPending, 0);
  });

  /// Fase R3.1: toda consulta de rondas responde HTTP 429.
  void limitAllRounds() =>
      api.respond = (url) => url.path.endsWith('eventsround.php')
      ? http.Response('{"error": "Too Many Requests"}', 429)
      : null;

  test('Fase R3.1: 429 persistente en «Actualizar»: 3 intentos de la fecha '
      'en juego y nada más; lo guardado sigue', () async {
    await watch(primera, download: true).last;
    clock.advance(const Duration(minutes: 10));
    api.requests.clear();
    limitAllRounds();

    final calendar = await watch(primera, forceRefresh: true).last;

    expect(api.requestLabels, List.filled(3, '4406:r12:s2026'));
    expect(calendar.progress.isRunning, isFalse);
    expect(calendar.progress.failure, isA<RateLimitFailure>());
    expect(calendar.matches, isNotEmpty);
  });

  test('cada partido con su fase y su etapa, sin red', () async {
    final calendar = await watch(primera, download: true).last;
    final labels = calendar.labels;
    String labelOf(String home, int round) {
      final m = calendar.matches.firstWhere(
        (m) => m.home.name == home && m.apiRound == round,
      );
      final l = labels[m.id]!;
      return [?l.phase, l.stage].join(' · ');
    }

    expect(labels, hasLength(495));
    // Fecha 12 del Clausura (11/10) y del Apertura (marzo), en la misma
    // ronda de la API.
    expect(labelOf('San Lorenzo', 12), 'Clausura · Fecha 12');
    expect(
      labels.values.where(
        (l) => l.phase == 'Apertura' && l.stage == 'Fecha 12',
      ),
      hasLength(15),
    );
    expect(labels.values.where((l) => l.stage.contains('final')), isNotEmpty);

    await watch(copa, download: true).last;
    final cup = await watch(copa).last;
    expect(cup.labels.values.map((l) => l.phase).toSet(), {null});
    expect(
      cup.labels.values.map((l) => l.stage).toSet(),
      containsAll(['Cuartos de final', 'Semifinales']),
    );
  });

  test('Fase D3: Libertadores 2026, «Completar» = 10 rondas y cada partido '
      'con su fase', () async {
    // Grabaciones del 14/10/2026: el reloj en esa hora.
    clock = FakeClock(DateTime.utc(2026, 10, 15, 0, 45));
    api = RecordedApi(
      clock: clock,
      db: await newDatabaseFactoryMemory().openDatabase('cup.db'),
    );

    final opened = await watch(4501).last;
    expect(api.requests, isEmpty);
    expect(opened.roundsTotal, 10);

    final calendar = await watch(4501, download: true).last;
    expect(api.requests, hasLength(10));
    final counts = <String, int>{};
    for (final l in calendar.labels.values) {
      final key = [?l.phase, l.stage].join(' · ');
      counts[key] = (counts[key] ?? 0) + 1;
    }
    expect(counts, {
      'Fases previas · Fase 1': 6,
      'Fases previas · Fase 2': 16,
      'Fases previas · Fase 3': 8,
      for (var r = 1; r <= 6; r++) 'Fase de grupos · Fecha $r': 16,
      'Eliminatorias · Octavos de final': 16,
      'Eliminatorias · Cuartos de final': 8,
      'Eliminatorias · Semifinales': 4,
    });

    api.requests.clear();
    await watch(4501, download: true).last;
    expect(api.requests, isEmpty);
  });
}
