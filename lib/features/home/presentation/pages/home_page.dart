import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/widgets/match_card.dart';
import '../../../../shared/presentation/widgets/match_day_list.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/repositories/competition_repository.dart';
import '../../../competitions/presentation/routing/fixture_route.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../domain/entities/favorite_team_overview.dart';
import '../../domain/entities/home_feed.dart';
import '../../domain/usecases/get_home_feed.dart';
import '../../domain/usecases/watch_favorite_teams.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_favorites_bloc.dart';

/// Inicio: tus equipos, partidos de hoy, próximos 7 días y de ayer de todas
/// las competiciones, con accesos a cada fixture y al buscador.
class HomePage extends StatelessWidget {
  const HomePage({super.key, this.showDiagnostics = false});

  /// Muestra el acceso a la pantalla de diagnóstico.
  final bool showDiagnostics;

  @override
  Widget build(BuildContext context) {
    final matches = context.read<MatchRepository>();
    final clock = context.read<Clock>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => HomeBloc(
            getHomeFeed: GetHomeFeed(
              competitions: context.read<CompetitionRepository>(),
              matches: matches,
            ),
            clock: clock,
          )..add(const HomeStarted()),
        ),
        BlocProvider(
          create: (context) => HomeFavoritesBloc(
            watchFavoriteTeams: WatchFavoriteTeams(
              favorites: context.read<FavoritesRepository>(),
              matches: matches,
            ),
            clock: clock,
          )..add(const HomeFavoritesStarted()),
        ),
      ],
      child: _HomeView(showDiagnostics: showDiagnostics),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({required this.showDiagnostics});

  final bool showDiagnostics;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        final bloc = context.read<HomeBloc>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Fútbol Argentino'),
            actions: [
              IconButton(
                tooltip: 'Buscar equipo',
                onPressed: () => context.go(AppRoutes.teams),
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: state.isBusy
                    ? null
                    : () => bloc.add(const HomeRefreshRequested()),
                icon: const Icon(Icons.refresh),
              ),
              if (showDiagnostics)
                IconButton(
                  tooltip: 'Diagnóstico de la API',
                  icon: const Icon(Icons.bug_report_outlined),
                  onPressed: () => context.push(AppRoutes.diagnostics),
                ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: switch (state) {
                HomeInitial() || HomeLoading() => Center(
                  child: Semantics(
                    label: 'Cargando partidos',
                    child: const CircularProgressIndicator(),
                  ),
                ),
                HomeFailure(:final failure) => ErrorView(
                  failure: failure,
                  onRetry: () => bloc.add(const HomeRefreshRequested()),
                ),
                HomeLoaded(:final feed) => _FeedView(feed: feed),
              },
            ),
          ),
        );
      },
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView({required this.feed});

  final HomeFeed feed;

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<HomeBloc>()..add(const HomeRefreshRequested());
    await bloc.stream.firstWhere((s) => !s.isBusy);
  }

  @override
  Widget build(BuildContext context) {
    final now = context.read<Clock>().now();
    void retry() => context.read<HomeBloc>().add(const HomeRefreshRequested());
    void open(int matchId) => context.push(AppRoutes.matchDetail(matchId));

    final labels = {
      for (final c in feed.competitions)
        for (final m in c.matches) m.match.id: _contextLabel(m),
    };
    final today = feed.todayMatches;
    final upcoming = feed.upcoming;
    final recent = feed.recent;
    final fetchedAt = feed.fetchedAt;
    final refreshError = feed.refreshError;
    final failed = feed.failedCompetitions;

    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          if (feed.isLoading) const LinearProgressIndicator(),
          if (refreshError != null && fetchedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: StaleDataBanner(
                fetchedAt: fetchedAt,
                failure: refreshError,
                onRetry: retry,
              ),
            ),
          if (failed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _FailedCompetitionsNotice(
                competitions: failed,
                onRetry: retry,
              ),
            ),
          const _Shortcuts(),
          _FavoriteTeams(now: now),

          SectionHeader(title: 'Hoy', subtitle: MatchLabels.day(feed.today)),
          if (today.isEmpty)
            _EmptySection(
              feed.isLoading ? 'Buscando partidos…' : 'No hay partidos hoy.',
            )
          else
            for (final m in today)
              MatchCard(
                key: ValueKey(m.match.id),
                match: m.match,
                now: now,
                subtitle: labels[m.match.id],
                onTap: () => open(m.match.id),
              ),

          const SectionHeader(title: 'Próximos 7 días'),
          if (upcoming.isEmpty)
            _EmptySection(
              feed.isLoading
                  ? 'Buscando partidos…'
                  : 'No hay partidos en los próximos 7 días.',
            )
          else
            ...matchDayItems(
              matches: [for (final m in upcoming) m.match],
              now: now,
              subtitle: (m) => labels[m.id],
              onTap: (m) => open(m.id),
            ),

          const SectionHeader(title: 'Recientes', subtitle: 'Partidos de ayer'),
          if (recent.isEmpty)
            _EmptySection(
              feed.isLoading ? 'Buscando partidos…' : 'No hubo partidos ayer.',
            )
          else
            ...matchDayItems(
              matches: [for (final m in recent) m.match],
              now: now,
              subtitle: (m) => labels[m.id],
              onTap: (m) => open(m.id),
            ),

          if (fetchedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Actualizado el '
                '${ArgentinaTime.formatDay(ArgentinaTime.dayOf(fetchedAt))} '
                'a las ${ArgentinaTime.formatTime(fetchedAt)} · '
                'Horarios de Argentina',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }

  /// «Primera División · Clausura · Fecha 12».
  static String _contextLabel(HomeMatch m) =>
      [m.competitionName, ?m.phaseLabel, m.stageLabel].join(' · ');
}

/// «Tus equipos»: próximo y último partido de cada favorito, con lo
/// guardado (sin peticiones).
class _FavoriteTeams extends StatelessWidget {
  const _FavoriteTeams({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return switch (context.watch<HomeFavoritesBloc>().state) {
      HomeFavoritesLoading() => const SizedBox.shrink(),
      HomeFavoritesLoaded(:final teams) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Tus equipos'),
          if (teams.isEmpty)
            const _EmptySection(
              'Tocá la estrella de un equipo, en el buscador o en su ficha, '
              'para seguirlo desde acá.',
            )
          else
            for (final t in teams)
              _FavoriteTeam(key: ValueKey(t.team.teamId), team: t, now: now),
        ],
      ),
    };
  }
}

class _FavoriteTeam extends StatelessWidget {
  const _FavoriteTeam({super.key, required this.team, required this.now});

  final FavoriteTeamOverview team;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final favorite = team.team;
    final next = team.next;
    final last = team.last;
    // Sin encabezados de día: el día va en la tarjeta.
    Widget card(String prefix, HomeMatch m) => MatchCard(
      match: m.match,
      now: now,
      subtitle:
          '$prefix · ${MatchLabels.day(m.match.kickoff.argentinaDay)}\n'
          '${_FeedView._contextLabel(m)}',
      onTap: () => context.push(AppRoutes.matchDetail(m.match.id)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: TeamBadge(name: favorite.name, url: favorite.badgeUrl),
          title: Text(favorite.name),
          trailing: const Icon(Icons.chevron_right),
          // La ficha dentro de Favoritos: «atrás» vuelve a la lista.
          onTap: () => context.go(AppRoutes.favoriteTeam(favorite.teamId)),
        ),
        if (!team.hasMatches)
          const _EmptySection(
            'Sin partidos guardados. Abrí la ficha para buscarlos.',
          ),
        if (next != null)
          card(next.match.status.isInPlay ? 'En juego' : 'Próximo', next),
        if (last != null) card('Último', last),
      ],
    );
  }
}

/// Accesos al buscador y a cada competición.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Buscar equipo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.teams),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final competition in CompetitionCatalog.all)
                ActionChip(
                  avatar: const Icon(Icons.emoji_events_outlined),
                  label: Text(competition.name),
                  tooltip: 'Fixture de ${competition.name}',
                  onPressed: () =>
                      context.go('${FixtureRoute.basePath}/${competition.id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailedCompetitionsNotice extends StatelessWidget {
  const _FailedCompetitionsNotice({
    required this.competitions,
    required this.onRetry,
  });

  final List<CompetitionDefinition> competitions;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final names = competitions.map((c) => c.name).join(', ');
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No se pudo cargar: $names.',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
