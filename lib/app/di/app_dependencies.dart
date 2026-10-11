import 'package:http/http.dart' as http;
import 'package:sembast/sembast.dart';

import '../../core/cache/query_metadata_store.dart';
import '../../core/config/app_config.dart';
import '../../core/network/rate_limiter.dart';
import '../../core/network/thesportsdb_client.dart';
import '../../core/sync/sync_scheduler.dart';
import '../../core/time/clock.dart';
import '../../features/competitions/data/datasources/competition_remote_data_source.dart';
import '../../features/competitions/data/repositories/competition_repository_impl.dart';
import '../../features/competitions/domain/repositories/competition_repository.dart';
import '../../features/diagnostics/data/repositories/diagnostics_repository_impl.dart';
import '../../features/diagnostics/domain/repositories/diagnostics_repository.dart';
import '../../features/matches/data/datasources/match_local_data_source.dart';
import '../../features/matches/data/datasources/match_remote_data_source.dart';
import '../../features/matches/data/repositories/match_repository_impl.dart';
import '../../features/matches/domain/repositories/match_repository.dart';

/// Composition root: construye una sola vez los servicios y repositorios de
/// la app. Los widgets los obtienen mediante `RepositoryProvider`.
class AppDependencies {
  AppDependencies._({
    required this.config,
    required this.clock,
    required this.database,
    required this.apiClient,
    required this.matchRepository,
    required this.competitionRepository,
    required this.diagnosticsRepository,
    required http.Client httpClient,
  }) : _httpClient = httpClient;

  factory AppDependencies.create({
    required Database database,
    AppConfig? config,
    http.Client? httpClient,
    Clock clock = const SystemClock(),
  }) {
    final appConfig = config ?? AppConfig.fromEnvironment();
    final client = httpClient ?? http.Client();
    final apiClient = TheSportsDbClient(
      config: appConfig,
      httpClient: client,
      rateLimiter: RateLimiter(
        maxRequests: appConfig.maxRequestsPerMinute,
        clock: clock,
      ),
    );
    final scheduler = SyncScheduler();
    final metadata = QueryMetadataStore(database);

    return AppDependencies._(
      config: appConfig,
      clock: clock,
      database: database,
      apiClient: apiClient,
      matchRepository: MatchRepositoryImpl(
        remote: MatchRemoteDataSource(apiClient),
        local: MatchLocalDataSource(database),
        metadata: metadata,
        scheduler: scheduler,
        clock: clock,
      ),
      competitionRepository: CompetitionRepositoryImpl(
        remote: CompetitionRemoteDataSource(apiClient),
        database: database,
        metadata: metadata,
        scheduler: scheduler,
        clock: clock,
      ),
      diagnosticsRepository: DiagnosticsRepositoryImpl(apiClient),
      httpClient: client,
    );
  }

  final AppConfig config;
  final Clock clock;
  final Database database;
  final TheSportsDbClient apiClient;
  final MatchRepository matchRepository;
  final CompetitionRepository competitionRepository;
  final DiagnosticsRepository diagnosticsRepository;
  final http.Client _httpClient;

  Future<void> dispose() async {
    _httpClient.close();
    await database.close();
  }
}
