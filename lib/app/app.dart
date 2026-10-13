import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/network/rate_limit_status.dart';
import '../core/time/clock.dart';
import '../features/competitions/domain/repositories/competition_repository.dart';
import '../features/diagnostics/domain/repositories/diagnostics_repository.dart';
import '../features/favorites/domain/repositories/favorites_repository.dart';
import '../features/favorites/presentation/bloc/favorites_bloc.dart';
import '../features/matches/domain/repositories/match_repository.dart';
import '../features/settings/domain/entities/app_settings.dart';
import '../features/settings/domain/repositories/settings_repository.dart';
import '../features/settings/presentation/bloc/settings_bloc.dart';
import '../features/teams/domain/repositories/team_repository.dart';
import '../shared/presentation/widgets/badge_image_resolver.dart';
import 'di/app_dependencies.dart';
import 'router/app_router.dart';
import 'shell/rate_limit_notice.dart';
import 'theme/app_theme.dart';

class FutbolArgentinoApp extends StatefulWidget {
  const FutbolArgentinoApp({
    super.key,
    required this.dependencies,
    this.initialSettings,
  });

  final AppDependencies dependencies;

  /// Ajustes leídos antes de abrir la app (sin parpadeo del tema); si es
  /// `null`, se leen al arrancar.
  final AppSettings? initialSettings;

  @override
  State<FutbolArgentinoApp> createState() => _FutbolArgentinoAppState();
}

class _FutbolArgentinoAppState extends State<FutbolArgentinoApp> {
  late final GoRouter _router = createAppRouter(
    enableDiagnostics: widget.dependencies.config.enableDiagnostics,
  );

  /// Con la app oculta (Android en segundo plano, pestaña Web oculta) no
  /// empiezan sincronizaciones de fondo (P2).
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: widget.dependencies.syncScheduler.pause,
    onShow: widget.dependencies.syncScheduler.resume,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppConfig>.value(value: deps.config),
        RepositoryProvider<Clock>.value(value: deps.clock),
        RepositoryProvider<RateLimitStatus>.value(value: deps.rateLimitStatus),
        RepositoryProvider<DiagnosticsRepository>.value(
          value: deps.diagnosticsRepository,
        ),
        RepositoryProvider<MatchRepository>.value(value: deps.matchRepository),
        RepositoryProvider<CompetitionRepository>.value(
          value: deps.competitionRepository,
        ),
        RepositoryProvider<TeamRepository>.value(value: deps.teamRepository),
        RepositoryProvider<FavoritesRepository>.value(
          value: deps.favoritesRepository,
        ),
        RepositoryProvider<SettingsRepository>.value(
          value: deps.settingsRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          // Global: la estrella de cualquier pantalla y la lista de
          // Favoritos comparten el mismo estado.
          BlocProvider(
            create: (context) => FavoritesBloc(
              favorites: deps.favoritesRepository,
              clock: deps.clock,
            )..add(const FavoritesSubscribed()),
          ),
          BlocProvider(
            create: (context) => SettingsBloc(
              settings: deps.settingsRepository,
              initial: widget.initialSettings,
            )..add(const SettingsSubscribed()),
          ),
        ],
        child: BlocSelector<SettingsBloc, SettingsState, ThemePreference>(
          selector: (state) => state.settings.theme,
          builder: (context, theme) => BadgeImages(
            resolver: deps.badgeImages,
            child: MaterialApp.router(
              title: 'Fútbol Argentino',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: AppTheme.modeFor(theme),
              locale: const Locale('es', 'AR'),
              supportedLocales: const [Locale('es', 'AR'), Locale('es')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              routerConfig: _router,
              builder: (context, child) =>
                  RateLimitNotice(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}
