import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';

import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../../../shared/presentation/widgets/match_day_list.dart';
import '../../../../shared/presentation/widgets/refresh_feedback.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../match_detail/presentation/pages/match_detail_page.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../../app/shell/top_bar_team_search.dart';
import '../../domain/entities/season.dart';
import '../../domain/repositories/competition_repository.dart';
import '../../domain/standings/table_builders.dart';
import '../../domain/usecases/resolve_current_stage.dart';
import '../../domain/usecases/watch_stage_matches.dart';
import '../../domain/usecases/watch_standings.dart';
import '../bloc/competition_fixture_bloc.dart';
import '../bloc/standings_bloc.dart';
import '../routing/fixture_route.dart';
import '../widgets/fixture_controls.dart';
import '../widgets/standings_panel.dart';

/// Fixture y tablas de cualquier competición del catálogo.
class CompetitionsPage extends StatelessWidget {
  const CompetitionsPage({
    super.key,
    required this.initialEvent,
    this.initialView = CompetitionsView.fixture,
    this.initialTable,
  });

  /// Selección inicial (de la URL o por defecto).
  final FixtureOpened initialEvent;
  final CompetitionsView initialView;

  /// Tabla elegida en la URL (`anual`, `apertura-a`…).
  final String? initialTable;

  @override
  Widget build(BuildContext context) {
    final clock = context.read<Clock>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final competitions = context.read<CompetitionRepository>();
            return CompetitionFixtureBloc(
              watchStageMatches: WatchStageMatches(
                context.read<MatchRepository>(),
              ),
              resolveCurrentStage: ResolveCurrentStage(competitions),
              competitions: competitions,
              clock: clock,
            )..add(initialEvent);
          },
        ),
        // Se crea al abrir la vista «Tabla»: el fixture solo no la necesita.
        BlocProvider(
          create: (context) => StandingsBloc(
            watchStandings: WatchStandings(context.read<MatchRepository>()),
            clock: clock,
          ),
        ),
      ],
      child: _CompetitionsView(
        initialView: initialView,
        initialTable: initialTable,
      ),
    );
  }
}

class _CompetitionsView extends StatefulWidget {
  const _CompetitionsView({required this.initialView, this.initialTable});

  final CompetitionsView initialView;
  final String? initialTable;

  @override
  State<_CompetitionsView> createState() => _CompetitionsViewState();
}

class _CompetitionsViewState extends State<_CompetitionsView> {
  late var _view = widget.initialView;
  late var _tableKey = widget.initialTable ?? AnnualTableBuilder.key;

  /// Competición y temporada pedidas al `StandingsBloc`.
  (int, Season)? _standingsTarget;

  /// Partido abierto en el panel de detalle (escritorio).
  int? _selectedMatchId;

  /// En Web: al volver a esta pantalla (de un partido o de otra sección),
  /// el router pone su ubicación, que no tiene la etapa ni la tabla.
  GoRouter? _router;

  /// Se apaga cuando la sección queda oculta (otra sección del menú).
  ValueListenable<TickerModeData>? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.getValuesNotifier(context);
    if (visible != _visible) {
      _visible?.removeListener(_onVisibilityChanged);
      _visible = visible..addListener(_onVisibilityChanged);
    }
    if (!kIsWeb) return;
    final router = GoRouter.maybeOf(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_restoreUrl);
    _router = router?..routerDelegate.addListener(_restoreUrl);
  }

  @override
  void dispose() {
    _visible?.removeListener(_onVisibilityChanged);
    _router?.routerDelegate.removeListener(_restoreUrl);
    super.dispose();
  }

  /// Las tablas descargan fechas solo mientras se ven.
  void _onVisibilityChanged() {
    if (_view != CompetitionsView.table) return;
    context.read<StandingsBloc>().add(
      _visible!.value.enabled
          ? const StandingsResumed()
          : const StandingsPaused(),
    );
  }

  /// Pide las tablas de la competición y temporada elegidas (o sigue la
  /// descarga si son las mismas).
  void _loadStandings(CompetitionFixtureState fixture) {
    final definition = fixture.definition;
    final season = fixture.season;
    if (definition == null || season == null) return;
    final target = (definition.id, season);
    final bloc = context.read<StandingsBloc>();
    if (target == _standingsTarget) {
      bloc.add(const StandingsResumed());
    } else {
      _standingsTarget = target;
      bloc.add(StandingsStarted(competitionId: definition.id, season: season));
    }
  }

  void _showView(CompetitionsView view) {
    if (view == _view) return;
    setState(() => _view = view);
    final fixture = context.read<CompetitionFixtureBloc>().state;
    if (view == CompetitionsView.table) {
      _loadStandings(fixture);
    } else {
      context.read<StandingsBloc>().add(const StandingsPaused());
    }
    _updateUrl(fixture);
  }

  void _selectTable(String key) {
    setState(() => _tableKey = key);
    _updateUrl(context.read<CompetitionFixtureBloc>().state);
  }

  /// URL de lo que se ve: la etapa del fixture o la tabla.
  Uri? _currentUri(CompetitionFixtureState fixture) {
    if (_view == CompetitionsView.fixture) {
      final stage = fixture.stage;
      return stage == null ? null : FixtureRoute.uriFor(stage);
    }
    final definition = fixture.definition;
    final season = fixture.season;
    return definition == null || season == null
        ? null
        : FixtureRoute.tableUri(definition.id, season, _tableKey);
  }

  /// En Web, la URL refleja lo que se ve para poder compartirla. Se
  /// reemplaza sin navegar (no recrea la pantalla).
  void _updateUrl(CompetitionFixtureState fixture) {
    if (!kIsWeb) return;
    final uri = _currentUri(fixture);
    if (uri != null) {
      SystemNavigator.routeInformationUpdated(uri: uri, replace: true);
    }
  }

  void _restoreUrl() {
    final router = _router;
    if (router == null || !mounted) return;
    final uri = FixtureRoute.urlToRestore(
      // Incluye lo abierto con `push` (p. ej. un partido).
      router.state.uri,
      _currentUri(context.read<CompetitionFixtureBloc>().state),
    );
    if (uri == null) return;
    // Después de que el router informe su ubicación (también al final del
    // frame), para que quede la de la etapa; solo si esta pantalla sigue a
    // la vista (el router pudo abrir otra competición en su lugar).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      SystemNavigator.routeInformationUpdated(uri: uri, replace: true);
    });
  }

  /// Ancho del panel de detalle.
  static const _panelWidth = 440.0;

  @override
  Widget build(BuildContext context) {
    final expanded = Breakpoints.isExpanded(context);
    final table = _view == CompetitionsView.table;
    final standingsBusy = context.select<StandingsBloc, bool>(
      (bloc) => bloc.state.isBusy,
    );
    return BlocConsumer<CompetitionFixtureBloc, CompetitionFixtureState>(
      listenWhen: (previous, current) =>
          previous.stage != current.stage ||
          previous.definition != current.definition ||
          previous.season != current.season,
      listener: (context, state) {
        if (_view == CompetitionsView.table) _loadStandings(state);
        _updateUrl(state);
      },
      builder: (context, state) {
        final content = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ViewSelector(view: _view, onChanged: _showView),
                  const SizedBox(height: 8),
                  FixtureSelectors(state: state, showPhaseSelector: !table),
                ],
              ),
            ),
            if (table)
              Expanded(
                child: StandingsPanel(
                  tableKey: _tableKey,
                  onTableSelected: _selectTable,
                  onRefresh: () => _refreshStandings(context),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: StageNavigator(state: state),
              ),
              Expanded(
                child: _FixtureContentView(
                  state: state,
                  selectedMatchId: expanded ? _selectedMatchId : null,
                  // En escritorio el partido se abre en el panel; si no, en
                  // su pantalla.
                  onOpen: expanded
                      ? (id) => setState(() => _selectedMatchId = id)
                      : (id) => context.push(AppRoutes.matchDetail(id)),
                ),
              ),
            ],
          ],
        );
        final selected = _selectedMatchId;

        return Scaffold(
          appBar: AppBar(
            title: Text(state.definition?.name ?? 'Competiciones'),
            actions: [
              const TopBarTeamSearch(),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: table
                    ? (standingsBusy ? null : () => _refreshStandings(context))
                    : (state.stage == null || state.isRefreshing
                          ? null
                          : () => _refreshFixture(context)),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: expanded ? Breakpoints.maxContentWidth : 900,
              ),
              child: expanded && !table
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: content),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: _panelWidth,
                          child: selected == null
                              ? const EmptyView(
                                  icon: Icons.sports_soccer,
                                  title: 'Detalle del partido',
                                  message:
                                      'Elegí un partido de la lista para '
                                      'verlo acá.',
                                )
                              : MatchDetailPanel(
                                  key: ValueKey(selected),
                                  matchId: selected,
                                  onClose: () =>
                                      setState(() => _selectedMatchId = null),
                                ),
                        ),
                      ],
                    )
                  : content,
            ),
          ),
        );
      },
    );
  }
}

/// «Fixture | Tabla».
class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.view, required this.onChanged});

  final CompetitionsView view;
  final ValueChanged<CompetitionsView> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<CompetitionsView>(
    segments: const [
      ButtonSegment(
        value: CompetitionsView.fixture,
        label: Text('Fixture'),
        icon: Icon(Icons.calendar_month_outlined),
      ),
      ButtonSegment(
        value: CompetitionsView.table,
        label: Text('Tabla'),
        icon: Icon(Icons.leaderboard_outlined),
      ),
    ],
    selected: {view},
    showSelectedIcon: false,
    onSelectionChanged: (views) => onChanged(views.first),
  );
}

/// Actualiza las tablas y, si no hizo falta consultar la red, lo avisa.
Future<void> _refreshStandings(BuildContext context) async {
  final bloc = context.read<StandingsBloc>()
    ..add(const StandingsRefreshRequested());
  final after = await bloc.stream.firstWhere((s) => !s.isBusy);
  if (after case StandingsLoaded(:final view)
      when context.mounted &&
          view.progress.failure == null &&
          view.progress.fetched == 0) {
    showAlreadyUpToDate(context);
  }
}

/// Actualiza la etapa y, si no hizo falta consultar la red (se actualizó
/// hace menos de 30 s), lo avisa.
Future<void> _refreshFixture(BuildContext context) async {
  final bloc = context.read<CompetitionFixtureBloc>();
  DateTime? fetchedAt(CompetitionFixtureState s) => switch (s.content) {
    FixtureLoaded(:final fetchedAt) => fetchedAt,
    FixtureEmpty(:final fetchedAt) => fetchedAt,
    _ => null,
  };
  final stage = bloc.state.stage;
  final before = fetchedAt(bloc.state);
  bloc.add(const FixtureRefreshRequested());
  final after = await bloc.stream.firstWhere((s) => !s.isRefreshing);
  final at = fetchedAt(after);
  final error = switch (after.content) {
    FixtureLoaded(:final refreshError) => refreshError,
    FixtureEmpty(:final refreshError) => refreshError,
    _ => null,
  };
  if (context.mounted &&
      after.stage == stage &&
      at != null &&
      at == before &&
      error == null) {
    showAlreadyUpToDate(context, at);
  }
}

class _FixtureContentView extends StatelessWidget {
  const _FixtureContentView({
    required this.state,
    required this.onOpen,
    this.selectedMatchId,
  });

  final CompetitionFixtureState state;
  final void Function(int matchId) onOpen;
  final int? selectedMatchId;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CompetitionFixtureBloc>();
    void retry() => bloc.add(const FixtureRefreshRequested());

    switch (state.content) {
      case FixtureInitial() || FixtureLoading():
        return Center(
          child: Semantics(
            label: 'Cargando partidos',
            child: const CircularProgressIndicator(),
          ),
        );

      case FixtureFailure(:final failure):
        return ErrorView(
          failure: failure,
          onRetry: state.stage == null ? null : retry,
        );

      case FixtureEmpty(
        :final refreshError,
        :final fetchedAt,
        :final isRefreshing,
      ):
        return RefreshIndicator(
          onRefresh: () => _refreshFixture(context),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isRefreshing) const LinearProgressIndicator(),
              if (refreshError != null && fetchedAt != null)
                StaleDataBanner(
                  fetchedAt: fetchedAt,
                  failure: refreshError,
                  onRetry: retry,
                ),
              EmptyView(
                icon: Icons.event_busy,
                title: state.stage == null
                    ? 'Sin fechas conocidas'
                    : 'Sin partidos',
                message: state.stage == null
                    ? 'No hay fechas verificadas para esta temporada.'
                    : 'TheSportsDB todavía no tiene partidos cargados para '
                          '${state.stage!.label.toLowerCase()}.',
              ),
            ],
          ),
        );

      case final FixtureLoaded loaded:
        final now = context.read<Clock>().now();
        return RefreshIndicator(
          onRefresh: () => _refreshFixture(context),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              if (loaded.isRefreshing) const LinearProgressIndicator(),
              if (loaded.refreshError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: StaleDataBanner(
                    fetchedAt: loaded.fetchedAt,
                    failure: loaded.refreshError!,
                    onRetry: retry,
                  ),
                ),
              ...matchDayItems(
                matches: loaded.matches.matches,
                now: now,
                onTap: (m) => onOpen(m.id),
                selectedId: selectedMatchId,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Actualizado el '
                  '${ArgentinaTime.formatDay(ArgentinaTime.dayOf(loaded.fetchedAt))} '
                  'a las ${ArgentinaTime.formatTime(loaded.fetchedAt)} · '
                  'Horarios de Argentina',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        );
    }
  }
}
