import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/cache/query_metadata_store.dart';
import 'package:futbol_argentino/core/config/app_config.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
import 'package:futbol_argentino/core/network/thesportsdb_client.dart';
import 'package:futbol_argentino/core/result/data_result.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/competitions/data/datasources/competition_remote_data_source.dart';
import 'package:futbol_argentino/features/competitions/data/repositories/competition_repository_impl.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

import '../../../helpers/fake_clock.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late FakeClock clock;
  late Database db;
  late List<Uri> requests;
  late Future<http.Response> Function(http.Request) handler;

  Future<http.Response> fixtureHandler(http.Request request) async {
    final id = request.url.queryParameters['id'];
    final name = switch (request.url.pathSegments.last) {
      'lookupleague.php' => 'lookupleague_$id',
      'eventsnextleague.php' => 'eventsnextleague_$id',
      'eventspastleague.php' => 'eventspastleague_$id',
      _ => throw StateError('sin fixture para ${request.url}'),
    };
    return http.Response.bytes(fixtureBytes(name), 200);
  }

  CompetitionRepositoryImpl build() {
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
    return CompetitionRepositoryImpl(
      remote: CompetitionRemoteDataSource(client),
      database: db,
      metadata: QueryMetadataStore(db),
      scheduler: SyncScheduler(),
      clock: clock,
    );
  }

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 11, 20, 35));
    db = await newDatabaseFactoryMemory().openDatabase('app.db');
    requests = [];
    handler = fixtureHandler;
  });

  tearDown(() => db.close());

  group('getCompetition', () {
    test(
      'Primera real desde la API y después desde la caché (7 días)',
      () async {
        final repo = build();

        final first = await repo.getCompetition(4406);
        clock.advance(const Duration(days: 6));
        final second = await repo.getCompetition(4406);

        expect(first.origin, DataOrigin.remote);
        expect(first.data.name, 'Primera División');
        expect(first.data.currentSeason, const Season(2026));
        expect(second.origin, DataOrigin.cache);
        expect(requests, hasLength(1));
      },
    );

    test('fuera del catálogo: NotFoundFailure sin consultar', () async {
      await expectLater(
        build().getCompetition(1),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(requests, isEmpty);
    });

    test('vencida y sin conexión: guardada + error', () async {
      final repo = build();
      await repo.getCompetition(4406);
      clock.advance(const Duration(days: 8));
      handler = (_) async => throw http.ClientException('offline');

      final result = await repo.getCompetition(4406);

      expect(result.origin, DataOrigin.cache);
      expect(result.refreshError, isA<NetworkFailure>());
    });
  });

  group('getSchedulePointers', () {
    test('próximo y último partido reales (2 peticiones)', () async {
      final result = await build().getSchedulePointers(4406);

      final recordedNext = fixtureEvents('eventsnextleague_4406').single;
      expect(
        result.data.next!.id,
        int.parse(recordedNext['idEvent'] as String),
      );
      expect(result.data.next!.apiRound, 12);
      expect(result.data.last, isNotNull);
      expect(requests, hasLength(2));
    });

    test('vigentes 30 minutos', () async {
      final repo = build();
      await repo.getSchedulePointers(4406);

      clock.advance(const Duration(minutes: 29));
      await repo.getSchedulePointers(4406);
      expect(requests, hasLength(2));

      clock.advance(const Duration(minutes: 2));
      final refreshed = await repo.getSchedulePointers(4406);
      expect(requests, hasLength(4));
      expect(refreshed.origin, DataOrigin.remote);
    });

    test('sin conexión ni caché: NetworkFailure', () async {
      handler = (_) async => throw http.ClientException('offline');

      await expectLater(
        build().getSchedulePointers(4406),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
