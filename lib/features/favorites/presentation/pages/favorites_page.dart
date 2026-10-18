import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/shell/top_bar_team_search.dart';
import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/content_app_bar.dart';
import '../../../../shared/presentation/widgets/match_group.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../domain/entities/favorite_team.dart';
import '../bloc/favorites_bloc.dart';
import '../widgets/favorite_button.dart';

/// Equipos favoritos (`/favoritos`), guardados en este dispositivo.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: ContentAppBar(
        maxWidth: Breakpoints.maxNarrowWidth,
        bar: AppBar(
          title: const Text('Favoritos'),
          actions: const [TopBarTeamSearch()],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Breakpoints.maxNarrowWidth,
          ),
          child: BlocBuilder<FavoritesBloc, FavoritesState>(
            builder: (context, state) => switch (state) {
              FavoritesLoading() => Center(
                child: Semantics(
                  label: 'Cargando favoritos',
                  child: const CircularProgressIndicator(),
                ),
              ),
              FavoritesLoaded(teams: []) => EmptyView(
                icon: Icons.star_outline,
                title: 'Todavía no tenés equipos favoritos',
                message:
                    'Buscá un equipo y tocá la estrella para tenerlo a mano '
                    'acá y en el Inicio.',
                action: FilledButton.tonalIcon(
                  onPressed: () => context.go(AppRoutes.teams),
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar equipo'),
                ),
              ),
              // En una superficie de grupo con divisores, como los
              // partidos (sin una tarjeta por equipo).
              FavoritesLoaded(:final teams) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                children: [
                  MatchGroup(
                    children: [
                      for (final team in teams)
                        _FavoriteTile(key: ValueKey(team.teamId), team: team),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Text(
                      'Guardados solo en este dispositivo',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({super.key, required this.team});

  final FavoriteTeam team;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: TeamBadge(name: team.name, url: team.badgeUrl),
      title: Text(team.name),
      trailing: FavoriteButton(team: team.ref),
      onTap: () => context.push(AppRoutes.favoriteTeam(team.teamId)),
    );
  }
}
