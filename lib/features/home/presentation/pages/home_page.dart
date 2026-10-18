import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/info_banner.dart';
import '../../../../shared/presentation/widgets/live_auto_refresh.dart';
import '../../../../shared/presentation/widgets/refresh_feedback.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/repositories/competition_repository.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../../../../app/shell/top_bar_team_search.dart';
import '../../domain/entities/home_feed.dart';
import '../../domain/usecases/get_home_feed.dart';
import '../../domain/usecases/watch_favorite_teams.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_favorites_bloc.dart';
import '../widgets/favorite_teams_section.dart';
import '../widgets/home_match_list.dart';
import '../widgets/home_shortcuts.dart';

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

  /// Actualiza y, si no hizo falta consultar la red (se actualizó hace
  /// menos de 30 s), lo avisa.
  static Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<HomeBloc>();
    final before = _fetchTimes(bloc.state);
    bloc.add(const HomeRefreshRequested());
    final after = await bloc.stream.firstWhere((s) => !s.isBusy);
    if (after case HomeLoaded(:final feed)
        when context.mounted &&
            feed.refreshError == null &&
            feed.failedCompetitions.isEmpty &&
            listEquals(_fetchTimes(after), before)) {
      showAlreadyUpToDate(context, feed.fetchedAt!);
    }
  }

  static List<DateTime?> _fetchTimes(HomeState state) => switch (state) {
    HomeLoaded(:final feed) => [for (final c in feed.competitions) c.fetchedAt],
    _ => const [],
  };

  /// Hay partidos en vivo en el Inicio y no se está cargando (D11). «Tus
  /// equipos» se actualiza solo con lo que se guarda.
  static bool _hasLiveMatches(BuildContext context) =>
      switch (context.read<HomeBloc>().state) {
        HomeLoaded(:final feed) when !feed.isLoading => MatchGrouping.anyLive([
          for (final c in feed.competitions)
            for (final m in c.matches) m.match,
        ], context.read<Clock>().now()),
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    // «Tus equipos» va arriba de todo: se espera a tenerlo para que no
    // aparezca después y corra el resto (solo lee lo guardado).
    final favoritesReady = context.select<HomeFavoritesBloc, bool>(
      (bloc) => bloc.state is! HomeFavoritesLoading,
    );
    final expanded = Breakpoints.isExpanded(context);
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        final bloc = context.read<HomeBloc>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Fútbol Argentino'),
            actions: [
              // En escritorio. En pantallas más angostas el acceso va arriba
              // del contenido, sin un ícono duplicado en la barra.
              const TopBarTeamSearch(),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: state.isBusy ? null : () => _refresh(context),
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Ajustes',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(AppRoutes.settings),
              ),
              if (showDiagnostics)
                IconButton(
                  tooltip: 'Diagnóstico de la API',
                  icon: const Icon(Icons.bug_report_outlined),
                  onPressed: () => context.push(AppRoutes.diagnostics),
                ),
            ],
          ),
          body: LiveAutoRefresh(
            hasLiveMatches: () => _hasLiveMatches(context),
            onTick: () => bloc.add(const HomeLiveTick()),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: expanded ? Breakpoints.maxContentWidth : 900,
                ),
                child: switch (state) {
                  HomeInitial() || HomeLoading() => const _Loading(),
                  HomeLoaded() when !favoritesReady => const _Loading(),
                  HomeFailure(:final failure) => ErrorView(
                    failure: failure,
                    onRetry: () => bloc.add(const HomeRefreshRequested()),
                  ),
                  HomeLoaded(:final feed) => _FeedView(
                    feed: feed,
                    twoColumns: expanded,
                    onRefresh: () => _refresh(context),
                  ),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: 'Cargando partidos',
      child: const CircularProgressIndicator(),
    ),
  );
}

class _FeedView extends StatelessWidget {
  const _FeedView({
    required this.feed,
    required this.twoColumns,
    required this.onRefresh,
  });

  final HomeFeed feed;

  /// Escritorio: Hoy y Próximos a la izquierda; accesos, tus equipos y
  /// Recientes a la derecha.
  final bool twoColumns;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = context.read<Clock>().now();
    void retry() => context.read<HomeBloc>().add(const HomeRefreshRequested());
    void open(HomeMatch m) => context.push(AppRoutes.matchDetail(m.match.id));
    String emptyOrLoading(String empty) =>
        feed.isLoading ? 'Buscando partidos…' : empty;

    final phone = Breakpoints.isCompact(context);
    // 12 en teléfonos, como las demás pantallas: con 16, a 360 px
    // «Independiente» ya no entra en un renglón de la fila (E2).
    final gutter = phone ? AppSpacing.md : AppSpacing.xl;
    final today = HomeGrouping.byDay(feed.todayMatches);
    final upcoming = HomeGrouping.byDay(feed.upcoming);
    final recent = HomeGrouping.byDay(feed.recent);
    // Ayer es un solo día: va en el título, como el de Hoy.
    final recentDay = recent.length == 1 ? recent.single.day : null;
    final fetchedAt = feed.fetchedAt;
    final refreshError = feed.refreshError;
    final failed = feed.failedCompetitions;

    final notices = [
      if (refreshError != null && fetchedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: StaleDataBanner(
            fetchedAt: fetchedAt,
            failure: refreshError,
            onRetry: retry,
          ),
        ),
      if (failed.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: _FailedCompetitionsNotice(
            competitions: failed,
            onRetry: retry,
          ),
        ),
    ];

    final todaySection = [
      SectionHeader(title: 'Hoy', subtitle: MatchLabels.day(feed.today)),
      if (today.isEmpty)
        HomeEmptyMessage(emptyOrLoading('No hay partidos hoy.'))
      else
        ...homeMatchItems(
          days: today,
          now: now,
          onTap: open,
          dayHeaders: false,
        ),
    ];

    final upcomingSection = [
      const SectionHeader(title: 'Próximos 7 días'),
      if (upcoming.isEmpty)
        HomeEmptyMessage(
          emptyOrLoading('No hay partidos en los próximos 7 días.'),
        )
      else
        ...homeMatchItems(days: upcoming, now: now, onTap: open),
    ];

    final recentSection = [
      SectionHeader(
        title: 'Recientes',
        subtitle: recentDay != null
            ? MatchLabels.day(recentDay)
            : 'Partidos de ayer',
      ),
      if (recent.isEmpty)
        HomeEmptyMessage(emptyOrLoading('No hubo partidos ayer.'))
      else
        ...homeMatchItems(
          days: recent,
          now: now,
          onTap: open,
          dayHeaders: recentDay == null,
        ),
    ];

    final footer = [
      if (fetchedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Text(
            'Actualizado el '
            '${ArgentinaTime.formatDay(ArgentinaTime.dayOf(fetchedAt))} '
            'a las ${ArgentinaTime.formatTime(fetchedAt)} · '
            'Horarios de Argentina',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ];

    Widget column(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    Widget padded(Widget child) => Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: child,
    );
    const gap = SizedBox(height: AppSpacing.sm);

    final List<Widget> children;
    if (twoColumns) {
      children = [
        ...notices,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: column([...todaySection, ...upcomingSection]),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              flex: 2,
              child: column([
                // El buscador está en la barra superior.
                const SizedBox(height: AppSpacing.lg),
                const CompetitionShortcuts(singleRow: false),
                FavoriteTeamsSection(now: now),
                ...recentSection,
              ]),
            ),
          ],
        ),
        ...footer,
      ].map(padded).toList();
    } else {
      children = [
        for (final w in [...notices, gap, const TeamSearchShortcut(), gap])
          padded(w),
        // En un teléfono, la fila de accesos llega a los bordes.
        if (phone)
          CompetitionShortcuts(singleRow: true, gutter: gutter)
        else
          padded(const CompetitionShortcuts(singleRow: false)),
        for (final w in [
          FavoriteTeamsSection(now: now),
          ...todaySection,
          ...upcomingSection,
          ...recentSection,
          ...footer,
        ])
          padded(w),
      ];
    }

    // La barra de actualización queda fija arriba aunque se desplace la
    // lista.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (feed.isLoading) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: children,
            ),
          ),
        ),
      ],
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
    final names = competitions.map((c) => c.name).join(', ');
    return InfoBanner(
      tone: InfoTone.error,
      icon: Icons.cloud_off,
      text: 'No se pudo cargar: $names.',
      action: TextButton(onPressed: onRetry, child: const Text('Reintentar')),
    );
  }
}
