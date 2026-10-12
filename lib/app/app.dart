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
import '../features/teams/domain/repositories/team_repository.dart';
import 'di/app_dependencies.dart';
import 'router/app_router.dart';
import 'shell/rate_limit_notice.dart';
import 'theme/app_theme.dart';

class FutbolArgentinoApp extends StatefulWidget {
  const FutbolArgentinoApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

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
      ],
      // Global: la estrella de cualquier pantalla y la lista de Favoritos
      // comparten el mismo estado.
      child: BlocProvider(
        create: (context) => FavoritesBloc(
          favorites: deps.favoritesRepository,
          clock: deps.clock,
        )..add(const FavoritesSubscribed()),
        child: MaterialApp.router(
          title: 'Fútbol Argentino',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          locale: const Locale('es', 'AR'),
          supportedLocales: const [Locale('es', 'AR'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: _router,
          builder: (context, child) =>
              RateLimitNotice(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
