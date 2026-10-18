import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/cache/cache_class.dart';
import 'package:futbol_argentino/core/cache/query_metadata_store.dart';
import 'package:futbol_argentino/core/config/app_config.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
import 'package:futbol_argentino/core/network/thesportsdb_client.dart';
import 'package:futbol_argentino/core/result/data_result.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/matches/data/datasources/match_local_data_source.dart';
import 'package:futbol_argentino/features/matches/data/datasources/match_remote_data_source.dart';
import 'package:futbol_argentino/features/matches/data/repositories/match_repository_impl.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

import '../../../helpers/fake_clock.dart';
import '../../../helpers/fixtures.dart';

typedef Handler = Future<http.Response> Function(http.Request request);

/// Responde con los fixtures reales según la consulta.
Future<http.Response> fixtureHandler(http.Request request) async {
  final q = request.url.queryParameters;
  final name = switch (request.url.pathSegments.last) {
    'eventsround.php' => 'eventsround_${q['id']}_r${q['r']}_s${q['s']}',
    'lookupevent.php' => 'lookupevent_${q['id']}',
    _ => throw StateError('sin fixture para ${request.url}'),
  };
  return http.Response.bytes(fixtureBytes(name), 200);
}

http.Response json(String body) => http.Response(body, 200);

const round12 = RoundQuery(
  competitionId: 4406,
  season: '2026',
  apiRound: 12,
  expectedMinimum: 15,
);

/// Final de la Sudamericana 2026: la ronda que se vio pedida dos veces en
/// `bracket_budget_test` (HITO_E §26.5).
const sud200 = RoundQuery(
  competitionId: 4724,
  season: '2026',
  apiRound: 200,
  expectedMinimum: 1,
);

/// Retiene una lectura de la vigencia hasta que se libera [gate]: la
/// ventana entre la lectura de `syncRound`/`watchRound` y el scheduler.
class GatedMetadata extends QueryMetadataStore {
  GatedMetadata(super.db);

  Completer<void>? gate;

  @override
  Future<QueryMetadata?> get(String key) async {
    final snapshot = await super.get(key);
    final g = gate;
    if (g != null) {
      gate = null;
      await g.future;
    }
    return snapshot;
  }
}

const round1 = RoundQuery(
  competitionId: 4406,
  season: '2026',
  apiRound: 1,
  expectedMinimum: 15,
);

void main() {
  late FakeClock clock;
  late DatabaseFactory factory;
  late Database db;
  late List<Uri> requests;
  late Handler handler;

  MatchRepositoryImpl build({
    QueryMetadataStore? metadata,
    SyncScheduler? scheduler,
  }) {
    final client = TheSportsDbClient(
      config: const AppConfig(apiKey: '123', enableDiagnostics: false),
      httpClient: MockClient((request) {
        requests.add(request.url);
        return handler(request);
      }),
      rateLimiter: RateLimiter(
        maxRequests: 25,
        clock: clock,
        delay: clock.delay,
      ),
      retryDelay: clock.delay,
    );
    return MatchRepositoryImpl(
      remote: MatchRemoteDataSource(client),
      local: MatchLocalDataSource(db),
      metadata: metadata ?? QueryMetadataStore(db),
      scheduler: scheduler ?? SyncScheduler(),
      clock: clock,
    );
  }

  setUp(() async {
    // Momento de la grabación de los fixtures.
    clock = FakeClock(DateTime.utc(2026, 10, 11, 20, 35));
    factory = newDatabaseFactoryMemory();
    db = await factory.openDatabase('app.db');
    requests = [];
    handler = fixtureHandler;
  });

  tearDown(() => db.close());

  test('sin caché: una petición y emite los 30 partidos de la red', () async {
    final results = await build().watchRound(round12).toList();

    expect(results, hasLength(1));
    expect(results.single.origin, DataOrigin.remote);
    expect(results.single.data, hasLength(30));
    expect(requests, hasLength(1));
  });

  test('dentro del TTL: solo caché y cero peticiones', () async {
    final repo = build();
    await repo.watchRound(round1).toList(); // ronda cerrada: 30 días
    clock.advance(const Duration(days: 1));

    final results = await repo.watchRound(round1).toList();

    expect(results.single.origin, DataOrigin.cache);
    expect(results.single.data, hasLength(30));
    expect(requests, hasLength(1));
  });

  test('vencida: emite caché y después la versión de la red', () async {
    final repo = build();
    await repo.watchRound(round12).toList(); // con partidos en juego: 2 min
    clock.advance(const Duration(minutes: 3));

    final results = await repo.watchRound(round12).toList();

    expect(results.map((r) => r.origin), [DataOrigin.cache, DataOrigin.remote]);
    expect(requests, hasLength(2));
  });

  test(
    'sin conexión con caché: datos guardados + error de actualización',
    () async {
      final repo = build();
      await repo.watchRound(round12).toList();
      clock.advance(const Duration(minutes: 3));
      handler = (_) async =>
          throw http.ClientException('Network is unreachable');

      final results = await repo.watchRound(round12).toList();

      expect(results, hasLength(2));
      expect(results.last.origin, DataOrigin.cache);
      expect(results.last.data, hasLength(30));
      expect(
        results.last.refreshError,
        isA<NetworkFailure>().having(
          (f) => f.detail,
          'detail',
          contains('Network is unreachable'),
        ),
      );
    },
  );

  test('sin conexión y sin caché: el stream termina con el error', () async {
    handler = (_) async => throw http.ClientException('Network is unreachable');

    await expectLater(
      build().watchRound(round12),
      emitsError(isA<NetworkFailure>()),
    );
  });

  test('JSON con forma inesperada y sin caché: FormatFailure', () async {
    handler = (_) async => json('{"events": "x"}');

    await expectLater(
      build().watchRound(round12),
      emitsError(isA<FormatFailure>()),
    );
  });

  test('refresco manual: ignorado antes de 30 s, permitido después', () async {
    final repo = build();
    await repo.watchRound(round1).toList();

    clock.advance(const Duration(seconds: 10));
    await repo.watchRound(round1, forceRefresh: true).toList();
    expect(requests, hasLength(1));

    clock.advance(const Duration(seconds: 25));
    final results = await repo.watchRound(round1, forceRefresh: true).toList();
    expect(requests, hasLength(2));
    expect(results.last.origin, DataOrigin.remote);
  });

  test('dos pantallas pidiendo la misma ronda: una sola petición', () async {
    final repo = build();

    final both = await Future.wait([
      repo.watchRound(round12).toList(),
      repo.watchRound(round12).toList(),
    ]);

    expect(requests, hasLength(1));
    expect(both.every((r) => r.last.data.length == 30), isTrue);
  });

  test(
    'events null con datos guardados: se conservan y se reintenta pronto',
    () async {
      final repo = build();
      await repo.watchRound(round12).toList();
      clock.advance(const Duration(minutes: 3));
      handler = (_) async => json('{"events": null}');

      final results = await repo.watchRound(round12).toList();

      expect(results.last.data, hasLength(30));
      final meta = await QueryMetadataStore(
        db,
      ).get(MatchRepositoryImpl.roundKey(round12));
      expect(meta!.cacheClass, CacheClass.retrySoon);
      expect(meta.quality, 'suspectEmpty');
    },
  );

  test('respuesta truncada: no borra los partidos que faltan', () async {
    final repo = build();
    await repo.watchRound(round12).toList();
    clock.advance(const Duration(minutes: 3));
    final full =
        jsonDecode(utf8.decode(fixtureBytes('eventsround_4406_r12_s2026')))
            as Map<String, dynamic>;
    handler = (_) async => json(
      jsonEncode({'events': (full['events'] as List).take(10).toList()}),
    );

    final results = await repo.watchRound(round12).toList();

    expect(results.last.data, hasLength(30));
  });

  test('los datos sobreviven a cerrar y reabrir la base', () async {
    await build().watchRound(round1).toList();
    await db.close();
    db = await factory.openDatabase('app.db');
    clock.advance(const Duration(hours: 1));

    final results = await build().watchRound(round1).toList();

    expect(results.single.origin, DataOrigin.cache);
    expect(results.single.data, hasLength(30));
    expect(requests, hasLength(1));
  });

  group('prefetchRound', () {
    test('descarga una ronda no guardada y la deja en caché', () async {
      final repo = build();

      await repo.prefetchRound(round1);
      final results = await repo.watchRound(round1).toList();

      expect(requests, hasLength(1));
      expect(results.single.origin, DataOrigin.cache);
    });

    test('vigente: no consulta', () async {
      final repo = build();
      await repo.watchRound(round1).toList();

      await repo.prefetchRound(round1);

      expect(requests, hasLength(1));
    });

    test('sin conexión: no lanza', () async {
      handler = (_) async => throw http.ClientException('offline');

      await build().prefetchRound(round1);
    });
  });

  group('getMatch', () {
    test('partido guardado por su ronda y vigente: sin petición', () async {
      final repo = build();
      await repo.watchRound(round1).toList();
      final id = requests.length;

      final result = await repo.getMatch(2397711);

      expect(result.origin, DataOrigin.cache);
      expect(result.data.home.name, 'Aldosivi');
      expect(requests, hasLength(id));
    });

    test('sin caché: lookupevent', () async {
      final result = await build().getMatch(2397877);

      expect(result.origin, DataOrigin.remote);
      expect(result.data.id, 2397877);
      expect(requests.single.path, endsWith('lookupevent.php'));
    });

    test('la API no lo tiene y no hay caché: NotFoundFailure', () async {
      handler = (_) async => json('{"events": null}');

      await expectLater(build().getMatch(1), throwsA(isA<NotFoundFailure>()));
    });

    test('sin conexión con caché vencida: guardado + error', () async {
      final repo = build();
      await repo.watchRound(round12).toList();
      clock.advance(const Duration(hours: 1));
      handler = (_) async => throw http.ClientException('offline');

      // Un partido de la fecha 12 que se estaba jugando (vence en 2 min).
      final live = (await MatchLocalDataSource(db).round(
        competitionId: 4406,
        season: '2026',
        apiRound: 12,
      )).firstWhere((Match m) => m.status.isInPlay);
      final result = await repo.getMatch(live.id);

      expect(result.origin, DataOrigin.cache);
      expect(result.refreshError, isA<NetworkFailure>());
    });
  });
  group('vigencia leída antes de que otro trabajo guarde la ronda', () {
    late GatedMetadata metadata;
    late SyncScheduler scheduler;
    late Completer<void> release;

    setUp(() {
      metadata = GatedMetadata(db);
      scheduler = SyncScheduler(clock: clock, delay: clock.delay);
      release = Completer<void>();
      // La primera petición queda en curso hasta [release].
      handler = (request) async {
        if (requests.length == 1) await release.future;
        return fixtureHandler(request);
      };
    });

    /// A (precarga del fixture, P1) está en curso; B lee la vigencia (sin
    /// la ronda), A termina y la guarda, y recién entonces B llega al
    /// scheduler. Devuelve lo que hizo B.
    Future<T> raceAfterA<T>(
      MatchRepositoryImpl repo,
      Future<T> Function() startB,
    ) async {
      final a = repo.syncRound(sud200);
      await pumpEventQueue();
      expect(requests, hasLength(1));
      final gate = metadata.gate = Completer<void>();
      final b = startB();
      await pumpEventQueue();
      release.complete();
      await a;
      gate.complete();
      return b;
    }

    test('syncRound: no vuelve a pedir la ronda', () async {
      final repo = build(metadata: metadata, scheduler: scheduler);

      final queried = await raceAfterA(
        repo,
        () => repo.syncRound(sud200, priority: SyncPriority.team),
      );

      expect(requests, hasLength(1), reason: '$requests');
      // Como al sumarse a un trabajo ajeno: la ronda se actualizó.
      expect(queried, isTrue);
    });

    test('watchRound: no vuelve a pedir la ronda', () async {
      final repo = build(metadata: metadata, scheduler: scheduler);

      final results = await raceAfterA(
        repo,
        () => repo.watchRound(sud200, priority: SyncPriority.team).toList(),
      );

      expect(requests, hasLength(1), reason: '$requests');
      // La final 2026 todavía no tiene partidos: lo guardado por A.
      expect(results.last.refreshError, isNull);
    });

    test(
      'un refresco forzado que se suma a ese trabajo en cola sí pide',
      () async {
        final repo = build(metadata: metadata, scheduler: scheduler);
        // B (P2) queda en cola con la app en segundo plano.
        scheduler.pause();
        late Future<bool> b;
        await raceAfterA(repo, () async {
          b = repo.syncRound(sud200, priority: SyncPriority.team);
        });
        await pumpEventQueue();
        expect(scheduler.pending, 1);

        // Pasó el intervalo mínimo del refresco manual desde lo que guardó A.
        clock.advance(const Duration(seconds: 40));
        final forced = await repo.syncRound(
          sud200,
          priority: SyncPriority.visible,
          forceRefresh: true,
        );
        await b;

        expect(forced, isTrue);
        expect(requests, hasLength(2), reason: '$requests');
      },
    );

    test('una ronda vencida en cola se pide al empezar el trabajo', () async {
      final repo = build(metadata: metadata, scheduler: scheduler);
      release.complete();
      await repo.syncRound(sud200);
      clock.advance(const Duration(days: 1));
      scheduler.pause();

      final b = repo.syncRound(sud200, priority: SyncPriority.team);
      await pumpEventQueue();
      expect(requests, hasLength(1));
      scheduler.resume();

      expect(await b, isTrue);
      expect(requests, hasLength(2), reason: '$requests');
    });
  });
}
