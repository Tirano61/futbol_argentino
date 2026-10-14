import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';

import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/calendar_month.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../../../shared/presentation/widgets/live_auto_refresh.dart';
import '../../../../shared/presentation/widgets/match_day_list.dart';
import '../../../../shared/presentation/widgets/refresh_feedback.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../match_detail/presentation/pages/match_detail_page.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../../../../app/shell/top_bar_team_search.dart';
import '../../domain/entities/season.dart';
import '../../domain/repositories/competition_repository.dart';
import '../../domain/usecases/resolve_current_stage.dart';
import '../../domain/usecases/watch_competition_calendar.dart';
import '../../domain/usecases/watch_stage_matches.dart';
import '../../domain/usecases/watch_standings.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/competition_fixture_bloc.dart';
import '../bloc/standings_bloc.dart';
import '../routing/fixture_route.dart';
import '../widgets/calendar_panel.dart';
import '../widgets/fixture_controls.dart';
import '../widgets/standings_panel.dart';

/// Fixture, tablas y calendario de cualquier competición del catálogo.
class CompetitionsPage extends StatelessWidget {
  const CompetitionsPage({
    super.key,
    required this.initialEvent,
    this.initialView = CompetitionsView.fixture,
    this.initialTable,
    this.initialMonth,
  });

  /// Selección inicial (de la URL o por defecto).
  final FixtureOpened initialEvent;
  final CompetitionsView initialView;

  /// Tabla elegida en la URL (`anual`, `apertura-a`, `zona-a`…).
  final String? initialTable;

  /// Mes del calendario elegido en la URL.
  final CalendarMonth? initialMonth;

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
        // Solo lee lo guardado al abrir la vista «Calendario».
        BlocProvider(
          create: (context) => CalendarBloc(
            watchCalendar: WatchCompetitionCalendar(
              context.read<MatchRepository>(),
            ),
            clock: clock,
          ),
        ),
      ],
      child: _CompetitionsView(
        initialView: initialView,
        initialTable: initialTable,
        initialMonth: initialMonth,
      ),
    );
  }
}

class _CompetitionsView extends StatefulWidget {
  const _CompetitionsView({
    required this.initialView,
    this.initialTable,
    this.initialMonth,
  });

  final CompetitionsView initialView;
  final String? initialTable;
  final CalendarMonth? initialMonth;

  @override
  State<_CompetitionsView> createState() => _CompetitionsViewState();
}

class _CompetitionsViewState extends State<_CompetitionsView> {
  late var _view = widget.initialView;

  /// Tabla elegida; `null`: la primera de la competición (la anual en
  /// Primera, la Zona A en Nacional).
  late String? _tableKey = widget.initialTable;

  /// Mes del calendario; `null`: el que corresponde a hoy.
  late CalendarMonth? _month = widget.initialMonth;

  /// Competición y temporada mostradas (para saber cuándo cambian).
  int? _competitionId;
  Season? _season;

  /// Competición y temporada pedidas al `StandingsBloc`.
  (int, Season)? _standingsTarget;

  /// Competición y temporada pedidas al `CalendarBloc`.
  (int, Season)? _calendarTarget;

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

  /// Las tablas y el calendario descargan fechas solo mientras se ven.
  void _onVisibilityChanged() {
    final visible = _visible!.value.enabled;
    switch (_view) {
      case CompetitionsView.table:
        context.read<StandingsBloc>().add(
          visible ? const StandingsResumed() : const StandingsPaused(),
        );
      case CompetitionsView.calendar:
        context.read<CalendarBloc>().add(
          visible ? const CalendarResumed() : const CalendarPaused(),
        );
      case CompetitionsView.fixture:
    }
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

  /// Pide el calendario de la competición y temporada elegidas (o vuelve a
  /// leer lo guardado si son las mismas).
  void _loadCalendar(CompetitionFixtureState fixture) {
    final definition = fixture.definition;
    final season = fixture.season;
    if (definition == null || season == null) return;
    final target = (definition.id, season);
    final bloc = context.read<CalendarBloc>();
    if (target == _calendarTarget) {
      bloc.add(const CalendarResumed());
    } else {
      _calendarTarget = target;
      bloc.add(CalendarStarted(competitionId: definition.id, season: season));
    }
  }

  void _showView(CompetitionsView view) {
    if (view == _view) return;
    setState(() => _view = view);
    final fixture = context.read<CompetitionFixtureBloc>().state;
    switch (view) {
      case CompetitionsView.table:
        _loadStandings(fixture);
      case CompetitionsView.calendar:
        _loadCalendar(fixture);
      case CompetitionsView.fixture:
    }
    if (view != CompetitionsView.table) {
      context.read<StandingsBloc>().add(const StandingsPaused());
    }
    if (view != CompetitionsView.calendar) {
      context.read<CalendarBloc>().add(const CalendarPaused());
    }
    _updateUrl(fixture);
  }

  void _selectMonth(CalendarMonth month) {
    setState(() => _month = month);
    _updateUrl(context.read<CompetitionFixtureBloc>().state);
  }

  void _selectTable(String key) {
    setState(() => _tableKey = key);
    _updateUrl(context.read<CompetitionFixtureBloc>().state);
  }

  /// URL de lo que se ve: la etapa del fixture, la tabla o el mes.
  Uri? _currentUri(CompetitionFixtureState fixture) {
    if (_view == CompetitionsView.fixture) {
      final stage = fixture.stage;
      return stage == null ? null : FixtureRoute.uriFor(stage);
    }
    final definition = fixture.definition;
    final season = fixture.season;
    if (definition == null || season == null) return null;
    return _view == CompetitionsView.table
        ? FixtureRoute.tableUri(definition.id, season, _tableKey)
        : FixtureRoute.calendarUri(definition.id, season, _month);
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
    final calendar = _view == CompetitionsView.calendar;
    final standingsBusy = context.select<StandingsBloc, bool>(
      (bloc) => bloc.state.isBusy,
    );
    final calendarBusy = context.select<CalendarBloc, bool>(
      (bloc) => bloc.state.isBusy,
    );
    return BlocConsumer<CompetitionFixtureBloc, CompetitionFixtureState>(
      listenWhen: (previous, current) =>
          previous.stage != current.stage ||
          previous.definition != current.definition ||
          previous.season != current.season ||
          // El fixture de fondo guardó su etapa: el calendario vuelve a
          // leer lo guardado (sin red).
          (_view == CompetitionsView.calendar &&
              _fixtureFetchedAt(previous) != _fixtureFetchedAt(current)),
      listener: (context, state) {
        // Cada competición tiene sus tablas: al cambiarla se muestra la
        // primera (la de la URL vale solo para la que abrió la pantalla).
        // El mes del calendario vale para una competición y temporada.
        final competitionId = state.definition?.id;
        if (_competitionId != null && competitionId != _competitionId) {
          setState(() => _tableKey = null);
        }
        if ((_competitionId != null && competitionId != _competitionId) ||
            (_season != null && state.season != _season)) {
          setState(() => _month = null);
        }
        _competitionId = competitionId ?? _competitionId;
        _season = state.season ?? _season;
        switch (_view) {
          case CompetitionsView.table:
            _loadStandings(state);
          case CompetitionsView.calendar:
            _loadCalendar(state);
          case CompetitionsView.fixture:
        }
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
                  FixtureSelectors(
                    state: state,
                    showPhaseSelector: _view == CompetitionsView.fixture,
                  ),
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
            else if (calendar)
              Expanded(
                child: CalendarPanel(
                  month: _month,
                  onMonthChanged: _selectMonth,
                  onRefresh: () => _refreshCalendar(context),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: StageNavigator(state: state),
              ),
              Expanded(
                child: LiveAutoRefresh(
                  hasLiveMatches: () => _fixtureHasLiveMatches(context),
                  onTick: () => context.read<CompetitionFixtureBloc>().add(
                    const FixtureLiveTick(),
                  ),
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
                onPressed: switch (_view) {
                  CompetitionsView.table =>
                    standingsBusy ? null : () => _refreshStandings(context),
                  CompetitionsView.calendar =>
                    calendarBusy ? null : () => _refreshCalendar(context),
                  CompetitionsView.fixture =>
                    state.stage == null || state.isRefreshing
                        ? null
                        : () => _refreshFixture(context),
                },
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
              child: expanded && _view == CompetitionsView.fixture
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

/// «Fixture | Tabla | Calendario».
class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.view, required this.onChanged});

  final CompetitionsView view;
  final ValueChanged<CompetitionsView> onChanged;

  static const _segments = [
    (CompetitionsView.fixture, 'Fixture', Icons.format_list_bulleted),
    (CompetitionsView.table, 'Tabla', Icons.leaderboard_outlined),
    (CompetitionsView.calendar, 'Calendario', Icons.calendar_month_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    // En un teléfono, sin íconos para que entren las tres etiquetas.
    final icons = !Breakpoints.isCompact(context);
    final selector = SegmentedButton<CompetitionsView>(
      segments: [
        for (final (value, label, icon) in _segments)
          ButtonSegment(
            value: value,
            label: Text(label),
            icon: icons ? Icon(icon) : null,
          ),
      ],
      selected: {view},
      showSelectedIcon: false,
      onSelectionChanged: (views) => onChanged(views.first),
    );
    // Con texto grande, en vez de partir las etiquetas en varias líneas, se
    // desplaza (como el selector de competiciones).
    if (MediaQuery.textScalerOf(context).scale(10) <= 13) return selector;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: selector,
      ),
    );
  }
}

/// La etapa mostrada tiene partidos en vivo y no se está cargando (D11).
bool _fixtureHasLiveMatches(BuildContext context) {
  final state = context.read<CompetitionFixtureBloc>().state;
  return switch (state.content) {
    FixtureLoaded(:final matches, isRefreshing: false) => MatchGrouping.anyLive(
      matches.matches,
      context.read<Clock>().now(),
    ),
    _ => false,
  };
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

/// Actualiza el calendario (fuerza las fechas recientes y completa la
/// temporada) y, si no hizo falta consultar la red, lo avisa.
Future<void> _refreshCalendar(BuildContext context) async {
  final bloc = context.read<CalendarBloc>()
    ..add(const CalendarRefreshRequested());
  final after = await bloc.stream.firstWhere((s) => !s.isBusy);
  if (after case CalendarLoaded(:final view)
      when context.mounted &&
          view.progress.failure == null &&
          view.progress.fetched == 0) {
    showAlreadyUpToDate(context);
  }
}

/// Cuándo se descargó la etapa mostrada en el fixture.
DateTime? _fixtureFetchedAt(CompetitionFixtureState s) => switch (s.content) {
  FixtureLoaded(:final fetchedAt) => fetchedAt,
  FixtureEmpty(:final fetchedAt) => fetchedAt,
  _ => null,
};

/// Actualiza la etapa y, si no hizo falta consultar la red (se actualizó
/// hace menos de 30 s), lo avisa.
Future<void> _refreshFixture(BuildContext context) async {
  final bloc = context.read<CompetitionFixtureBloc>();
  final stage = bloc.state.stage;
  final before = _fixtureFetchedAt(bloc.state);
  bloc.add(const FixtureRefreshRequested());
  final after = await bloc.stream.firstWhere((s) => !s.isRefreshing);
  final at = _fixtureFetchedAt(after);
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
