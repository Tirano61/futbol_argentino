import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/network/rate_limiter.dart';
import '../../core/network/thesportsdb_client.dart';
import '../../core/time/clock.dart';
import '../../features/diagnostics/data/repositories/diagnostics_repository_impl.dart';
import '../../features/diagnostics/domain/repositories/diagnostics_repository.dart';

/// Composition root: construye una sola vez los servicios y repositorios de
/// la app. Los widgets los obtienen mediante `RepositoryProvider`.
class AppDependencies {
  AppDependencies._({
    required this.config,
    required this.clock,
    required this.apiClient,
    required this.diagnosticsRepository,
    required http.Client httpClient,
  }) : _httpClient = httpClient;

  factory AppDependencies.create({
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

    return AppDependencies._(
      config: appConfig,
      clock: clock,
      apiClient: apiClient,
      diagnosticsRepository: DiagnosticsRepositoryImpl(apiClient),
      httpClient: client,
    );
  }

  final AppConfig config;
  final Clock clock;
  final TheSportsDbClient apiClient;
  final DiagnosticsRepository diagnosticsRepository;
  final http.Client _httpClient;

  void dispose() => _httpClient.close();
}
