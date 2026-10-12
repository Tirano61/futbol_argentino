import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/competitions/presentation/pages/competitions_page.dart';
import '../../features/competitions/presentation/routing/fixture_route.dart';
import '../../features/diagnostics/domain/repositories/diagnostics_repository.dart';
import '../../features/diagnostics/presentation/bloc/api_test_bloc.dart';
import '../../features/diagnostics/presentation/bloc/cache_probe_bloc.dart';
import '../../features/diagnostics/presentation/pages/api_test_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/match_detail/presentation/pages/match_detail_page.dart';
import '../../features/matches/domain/repositories/match_repository.dart';
import '../../features/teams/presentation/pages/team_detail_page.dart';
import '../../features/teams/presentation/pages/team_search_page.dart';
import '../../shared/presentation/widgets/coming_soon_page.dart';
import '../shell/adaptive_shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const competitions = '/competiciones';
  static const teams = '/equipos';
  static const favorites = '/favoritos';
  static const diagnostics = '/diagnostico';
  static const match = '/partidos';

  static String matchDetail(int id) => '$match/$id';
  static String teamDetail(int id) => '$teams/$id';
}

GoRouter createAppRouter({required bool enableDiagnostics}) {
  // En Web, `context.push` (p. ej. abrir un partido) también actualiza la
  // URL, para poder compartirla.
  GoRouter.optionURLReflectsImperativeAPIs = true;
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
                builder: (context, state) =>
                    HomePage(showDiagnostics: enableDiagnostics),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.competitions,
                builder: (context, state) => CompetitionsPage(
                  initialEvent: FixtureRoute.parse(
                    query: state.uri.queryParameters,
                  ),
                ),
              ),
              // Ruta hermana (no anidada): un enlace directo no apila la
              // página base ni muestra «atrás».
              GoRoute(
                path: '${AppRoutes.competitions}/:leagueId',
                builder: (context, state) => CompetitionsPage(
                  key: ValueKey(state.uri.toString()),
                  initialEvent: FixtureRoute.parse(
                    leagueId: state.pathParameters['leagueId'],
                    query: state.uri.queryParameters,
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teams,
                builder: (context, state) => TeamSearchPage(
                  initialQuery: state.uri.queryParameters['q'] ?? '',
                ),
                routes: [
                  // Anidada: «atrás» vuelve al buscador, también desde un
                  // enlace directo.
                  GoRoute(
                    path: ':teamId',
                    builder: (context, state) {
                      final id = int.tryParse(
                        state.pathParameters['teamId'] ?? '',
                      );
                      return id == null
                          ? const ComingSoonPage(
                              title: 'Equipo',
                              icon: Icons.shield,
                              message: 'El enlace del equipo no es válido.',
                            )
                          : TeamDetailPage(key: ValueKey(id), teamId: id);
                    },
                  ),
                ],
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
      // Fuera del shell: pantalla completa con «atrás».
      GoRoute(
        path: '${AppRoutes.match}/:eventId',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['eventId'] ?? '');
          return id == null
              ? const ComingSoonPage(
                  title: 'Partido',
                  icon: Icons.sports_soccer,
                  message: 'El enlace del partido no es válido.',
                )
              : MatchDetailPage(key: ValueKey(id), matchId: id);
        },
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
