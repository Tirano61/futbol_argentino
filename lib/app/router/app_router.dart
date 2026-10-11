import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/diagnostics/domain/repositories/diagnostics_repository.dart';
import '../../features/diagnostics/presentation/bloc/api_test_bloc.dart';
import '../../features/diagnostics/presentation/bloc/cache_probe_bloc.dart';
import '../../features/diagnostics/presentation/pages/api_test_page.dart';
import '../../features/matches/domain/repositories/match_repository.dart';
import '../../shared/presentation/widgets/coming_soon_page.dart';
import '../shell/adaptive_shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const competitions = '/competiciones';
  static const teams = '/equipos';
  static const favorites = '/favoritos';
  static const diagnostics = '/diagnostico';
}

GoRouter createAppRouter({required bool enableDiagnostics}) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => ComingSoonPage(
                  title: 'Fútbol Argentino',
                  icon: Icons.sports_soccer,
                  message:
                      'Acá vas a ver los partidos de hoy, los próximos y '
                      'los resultados recientes.',
                  actions: [
                    if (enableDiagnostics)
                      IconButton(
                        tooltip: 'Diagnóstico de la API',
                        icon: const Icon(Icons.bug_report_outlined),
                        onPressed: () => context.push(AppRoutes.diagnostics),
                      ),
                  ],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.competitions,
                builder: (context, state) => const ComingSoonPage(
                  title: 'Competiciones',
                  icon: Icons.emoji_events,
                  message:
                      'Fixture de Primera División, Primera Nacional y '
                      'Copa Argentina por fecha y ronda.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teams,
                builder: (context, state) => const ComingSoonPage(
                  title: 'Equipos',
                  icon: Icons.shield,
                  message: 'Buscá un equipo para ver sus partidos.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.favorites,
                builder: (context, state) => const ComingSoonPage(
                  title: 'Favoritos',
                  icon: Icons.star,
                  message:
                      'Tus equipos favoritos, guardados en este dispositivo.',
                ),
              ),
            ],
          ),
        ],
      ),
      if (enableDiagnostics)
        GoRoute(
          path: AppRoutes.diagnostics,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) =>
                    ApiTestBloc(context.read<DiagnosticsRepository>()),
              ),
              BlocProvider(
                create: (context) =>
                    CacheProbeBloc(context.read<MatchRepository>()),
              ),
            ],
            child: const ApiTestPage(),
          ),
        ),
    ],
  );
}
