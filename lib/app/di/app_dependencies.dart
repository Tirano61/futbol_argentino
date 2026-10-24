import 'package:http/http.dart' as http;
import 'package:sembast/sembast.dart';

import '../../core/cache/query_metadata_store.dart';
import '../../core/config/app_config.dart';
import '../../core/network/rate_limit_status.dart';
import '../../core/platform/external_actions.dart';
import '../../core/network/rate_limiter.dart';
import '../../core/network/thesportsdb_client.dart';
import '../../core/sync/observed_sync_scheduler.dart';
import '../../core/sync/sync_scheduler.dart';
import '../../core/time/clock.dart';
import '../../features/competitions/data/datasources/competition_remote_data_source.dart';
import '../../features/competitions/data/repositories/competition_repository_impl.dart';
import '../../features/competitions/domain/repositories/competition_repository.dart';
import '../../features/diagnostics/data/repositories/diagnostics_repository_impl.dart';
import '../../features/diagnostics/domain/repositories/diagnostics_repository.dart';
import '../../features/favorites/data/repositories/favorites_repository_impl.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../features/matches/data/datasources/match_local_data_source.dart';
import '../../features/matches/data/datasources/match_remote_data_source.dart';
import '../../features/matches/data/repositories/match_repository_impl.dart';
import '../../features/matches/domain/repositories/match_repository.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/teams/data/datasources/team_remote_data_source.dart';
import '../../features/teams/data/repositories/team_repository_impl.dart';
import '../../features/teams/domain/repositories/team_repository.dart';
import '../../shared/presentation/widgets/badge_image_resolver.dart';

/// Composition root: construye una sola vez los servicios y repositorios de
/// la app. Los widgets los obtienen mediante `RepositoryProvider`.
class AppDependencies {
  AppDependencies._({
    required this.config,
    required this.clock,
    required this.database,
    required this.apiClient,
    required this.rateLimitStatus,
    required this.rateLimitRecovery,
    required this.syncScheduler,
    required this.matchRepository,
    required this.competitionRepository,
    required this.teamRepository,
    required this.favoritesRepository,
    required this.settingsRepository,
    required this.diagnosticsRepository,
    required this.badgeImages,
    required this.externalActions,
    required http.Client httpClient,
  }) : _httpClient = httpClient;

  factory AppDependencies.create({
    required Database database,
    AppConfig? config,
    http.Client? httpClient,
    Clock clock = const SystemClock(),
    BadgeImageResolver? badgeImages,
    ExternalActions? externalActions,
  }) {
    final appConfig = config ?? AppConfig.fromEnvironment();
    final client = httpClient ?? http.Client();
    final rateLimiter = RateLimiter(
      maxRequests: appConfig.maxRequestsPerMinute,
      clock: clock,
    );
    final apiClient = TheSportsDbClient(
      config: appConfig,
      httpClient: client,
      rateLimiter: rateLimiter,
      clock: clock,
    );
    final scheduler = ObservedSyncScheduler(
      clock: clock,
      rateLimit: rateLimiter,
    );
    final metadata = QueryMetadataStore(database);
    final matchLocal = MatchLocalDataSource(database);

    return AppDependencies._(
      config: appConfig,
      clock: clock,
      database: database,
      apiClient: apiClient,
      rateLimitStatus: rateLimiter,
      rateLimitRecovery: scheduler,
      syncScheduler: scheduler,
      matchRepository: MatchRepositoryImpl(
        remote: MatchRemoteDataSource(apiClient),
        local: matchLocal,
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
      teamRepository: TeamRepositoryImpl(
        remote: TeamRemoteDataSource(apiClient),
        matches: matchLocal,
        database: database,
        metadata: metadata,
        scheduler: scheduler,
        clock: clock,
      ),
      favoritesRepository: FavoritesRepositoryImpl(database),
      settingsRepository: SettingsRepositoryImpl(database),
      diagnosticsRepository: DiagnosticsRepositoryImpl(apiClient),
      badgeImages: badgeImages ?? BadgeImageResolver.forPlatform(),
      externalActions: externalActions ?? PlatformExternalActions(clock: clock),
      httpClient: client,
    );
  }

  final AppConfig config;
  final Clock clock;
  final Database database;
  final TheSportsDbClient apiClient;

  /// Pausa por HTTP 429 (para avisarla en pantalla).
  final RateLimitStatus rateLimitStatus;

  /// Si el scheduler dejó de reintentar un trabajo en la pausa vigente
  /// (para no prometer un reintento automático; Fase R3).
  final RateLimitRecovery rateLimitRecovery;

  /// Cola de sincronización (se pausa con la app en segundo plano).
  final SyncScheduler syncScheduler;
  final MatchRepository matchRepository;
  final CompetitionRepository competitionRepository;
  final TeamRepository teamRepository;
  final FavoritesRepository favoritesRepository;
  final SettingsRepository settingsRepository;
  final DiagnosticsRepository diagnosticsRepository;

  /// Escudos: caché en disco en Android, red en Web.
  final BadgeImageResolver badgeImages;

  /// Compartir y agregar al calendario.
  final ExternalActions externalActions;
  final http.Client _httpClient;

  Future<void> dispose() async {
    _httpClient.close();
    await database.close();
  }
}
