import 'dart:math' as math;

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
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/live_auto_refresh.dart';
import '../../../../shared/presentation/widgets/match_day_list.dart';
import '../../../../shared/presentation/widgets/refresh_feedback.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../match_detail/presentation/pages/match_detail_page.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../../../../app/shell/top_bar_team_search.dart';
import '../../domain/catalog/competition_catalog.dart';
import '../../domain/entities/phase.dart';
import '../../domain/entities/season.dart';
import '../../domain/repositories/competition_repository.dart';
import '../../domain/usecases/resolve_current_stage.dart';
import '../../domain/usecases/watch_competition_calendar.dart';
import '../../domain/usecases/watch_knockout_bracket.dart';
import '../../domain/usecases/watch_stage_matches.dart';
import '../../domain/usecases/watch_standings.dart';
import '../bloc/bracket_bloc.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/competition_fixture_bloc.dart';
import '../bloc/standings_bloc.dart';
import '../routing/fixture_route.dart';
import '../widgets/bracket_panel.dart';
import '../widgets/calendar_panel.dart';
import '../widgets/fixture_controls.dart';
import '../widgets/competition_picker.dart';
import '../widgets/series_list.dart';
import '../widgets/standings_panel.dart';
import '../widgets/view_tabs.dart';
import '../../../../shared/presentation/widgets/content_app_bar.dart';

/// Fixture, tablas, calendario y llaves de cualquier competición del
/// catálogo.
class CompetitionsPage extends StatelessWidget {
  const CompetitionsPage({
    super.key,
    required this.initialEvent,
    this.initialView = CompetitionsView.fixture,
    this.initialTable,
    this.initialMonth,
    this.initialBracketPhase,
  });

  /// Selección inicial (de la URL o por defecto).
  final FixtureOpened initialEvent;
  final CompetitionsView initialView;

  /// Tabla elegida en la URL (`anual`, `apertura-a`, `zona-a`…).
  final String? initialTable;

  /// Mes del calendario elegido en la URL.
  final CalendarMonth? initialMonth;

  /// Torneo del cuadro de llaves elegido en la URL.
  final PhaseKey? initialBracketPhase;

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
        // Se crea al abrir la vista «Llaves».
        BlocProvider(
          create: (context) => BracketBloc(
            watchBracket: WatchKnockoutBracket(context.read<MatchRepository>()),
            clock: clock,
          ),
        ),
      ],
      child: _CompetitionsView(
        competitionId: initialEvent.competitionId,
        initialView: _availableView(initialEvent.competitionId, initialView),
        initialTable: initialTable,
        initialMonth: initialMonth,
        initialBracketPhase: initialBracketPhase,
      ),
    );
  }
}

/// [view] si la competición la ofrece; si no, el Fixture (`vista=tabla` de
/// una competición sin tabla).
CompetitionsView _availableView(int competitionId, CompetitionsView view) {
  final definition = CompetitionCatalog.byId(competitionId);
  return definition == null || view.isAvailableFor(definition)
      ? view
      : CompetitionsView.fixture;
}

class _CompetitionsView extends StatefulWidget {
  const _CompetitionsView({
    required this.competitionId,
    required this.initialView,
    this.initialTable,
    this.initialMonth,
    this.initialBracketPhase,
  });

  /// Competición que abre la pantalla.
  final int competitionId;
  final CompetitionsView initialView;
  final String? initialTable;
  final CalendarMonth? initialMonth;
  final PhaseKey? initialBracketPhase;

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

  /// Torneo del cuadro de llaves; `null`: el último con eliminatorias.
  late PhaseKey? _bracketPhase = widget.initialBracketPhase;

  /// Competición y temporada mostradas (para saber cuándo cambian).
  late int _competitionId = widget.competitionId;
  Season? _season;

  /// Competición y temporada pedidas al `StandingsBloc`.
  (int, Season)? _standingsTarget;

  /// Competición y temporada pedidas al `CalendarBloc`.
  (int, Season)? _calendarTarget;

  /// Competición y temporada pedidas al `BracketBloc`.
  (int, Season)? _bracketTarget;

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

  /// Las tablas, el calendario y las llaves descargan fechas solo mientras
  /// se ven.
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
      case CompetitionsView.bracket:
        context.read<BracketBloc>().add(
          visible ? const BracketResumed() : const BracketPaused(),
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

  /// Pide las llaves de la competición y temporada elegidas (o sigue la
  /// descarga si son las mismas).
  void _loadBracket(CompetitionFixtureState fixture) {
    final definition = fixture.definition;
    final season = fixture.season;
    if (definition == null || season == null) return;
    final target = (definition.id, season);
    final bloc = context.read<BracketBloc>();
    if (target == _bracketTarget) {
      bloc.add(const BracketResumed());
    } else {
      _bracketTarget = target;
      bloc.add(BracketStarted(competitionId: definition.id, season: season));
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
      case CompetitionsView.bracket:
        _loadBracket(fixture);
      case CompetitionsView.fixture:
    }
    if (view != CompetitionsView.table) {
      context.read<StandingsBloc>().add(const StandingsPaused());
    }
    if (view != CompetitionsView.calendar) {
      context.read<CalendarBloc>().add(const CalendarPaused());
    }
    if (view != CompetitionsView.bracket) {
      context.read<BracketBloc>().add(const BracketPaused());
    }
    _updateUrl(fixture);
  }

  void _selectBracketPhase(PhaseKey phase) {
    setState(() => _bracketPhase = phase);
    _updateUrl(context.read<CompetitionFixtureBloc>().state);
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
    return switch (_view) {
      CompetitionsView.table => FixtureRoute.tableUri(
        definition.id,
        season,
        _tableKey,
      ),
      CompetitionsView.bracket => FixtureRoute.bracketUri(
        definition.id,
        season,
        _bracketPhase,
      ),
      _ => FixtureRoute.calendarUri(definition.id, season, _month),
    };
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
    final standingsBusy = context.select<StandingsBloc, bool>(
      (bloc) => bloc.state.isBusy,
    );
    final calendarBusy = context.select<CalendarBloc, bool>(
      (bloc) => bloc.state.isBusy,
    );
    final bracketBusy = context.select<BracketBloc, bool>(
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
        final definition = state.definition;
        final changed = definition != null && definition.id != _competitionId;
        if (changed) {
          setState(() {
            _tableKey = null;
            _bracketPhase = null;
          });
        }
        if (changed || (_season != null && state.season != _season)) {
          setState(() => _month = null);
        }
        _competitionId = definition?.id ?? _competitionId;
        _season = state.season ?? _season;
        // La competición nueva no ofrece la vista abierta (p. ej. la Tabla
        // al pasar a la B Metro): se vuelve al Fixture.
        if (definition != null && !_view.isAvailableFor(definition)) {
          _showView(CompetitionsView.fixture);
        }
        switch (_view) {
          case CompetitionsView.table:
            _loadStandings(state);
          case CompetitionsView.calendar:
            _loadCalendar(state);
          case CompetitionsView.bracket:
            _loadBracket(state);
          case CompetitionsView.fixture:
        }
        _updateUrl(state);
      },
      // El ancho de la barra superior (la sección sin el riel, hasta el de
      // la columna de contenido): de ahí sale lo que entra en ella.
      builder: (context, state) => LayoutBuilder(
        builder: (context, constraints) => _page(
          context,
          state,
          math.min(constraints.maxWidth, Breakpoints.listWidth(context)),
          expanded: expanded,
          busy: (
            standings: standingsBusy,
            calendar: calendarBusy,
            bracket: bracketBusy,
          ),
        ),
      ),
    );
  }

  Widget _page(
    BuildContext context,
    CompetitionFixtureState state,
    double width, {
    required bool expanded,
    required ({bool standings, bool calendar, bool bracket}) busy,
  }) {
    final bloc = context.read<CompetitionFixtureBloc>();
    final definition =
        state.definition ?? CompetitionCatalog.byId(_competitionId);
    final season = state.season;
    final seasons = state.seasons;
    final hasSeason = season != null && seasons.isNotEmpty;
    final compact = Breakpoints.isCompact(context);

    // Nivel 1: competición y, si entra al lado, la temporada (E-D8). Lo que
    // le queda al título: el ancho de la barra menos el botón Atrás (si lo
    // hay), las acciones y los márgenes del título.
    final leading = (ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
        ? kToolbarHeight
        : 0.0;
    final actions =
        (expanded ? TopBarTeamSearch.barWidth : 0) + AppSizes.tapTarget;
    final layout = definition == null
        ? null
        : CompetitionTitleLayout.resolve(
            context,
            competition: definition,
            width: width - leading - actions - 2 * AppSpacing.sm,
            seasonWidth: hasSeason
                ? AppSpacing.sm +
                      SeasonSelector.widthFor(
                        context,
                        seasons,
                        compact: compact,
                      )
                : null,
          );
    final seasonInBar = layout?.seasonInBar ?? true;
    Widget seasonSelector({required bool compact}) => SeasonSelector(
      season: season!,
      seasons: seasons,
      compact: compact,
      onChanged: (s) => bloc.add(FixtureSeasonChanged(s)),
    );
    // Si no entra en la barra, baja al principio de los filtros (nivel 3),
    // en su propio renglón: al final de una fila desplazable quedaría fuera
    // de la vista.
    final filterSeason = hasSeason && !seasonInBar
        ? seasonSelector(compact: false)
        : null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nivel 2: vistas.
        ViewTabs(
          view: _view,
          views: [
            for (final v in CompetitionsView.values)
              // La abierta sigue hasta que el listener la cambie.
              if (v == _view ||
                  definition == null ||
                  v.isAvailableFor(definition))
                v,
          ],
          onChanged: _showView,
        ),
        // Nivel 3: filtros de la vista (las tablas y las llaves llevan los
        // suyos arriba de su contenido).
        if (filterSeason != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
              0,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: filterSeason,
            ),
          ),
        if (_view == CompetitionsView.fixture) FixtureSelectors(state: state),
        Expanded(child: _viewContent(context, state, expanded: expanded)),
      ],
    );
    final selected = _selectedMatchId;

    return Scaffold(
      appBar: ContentAppBar(
        maxWidth: Breakpoints.listWidth(context),
        bar: AppBar(
          titleSpacing: AppSpacing.sm,
          title: definition == null
              ? const Text('Competiciones')
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: CompetitionPicker(
                        key: FixtureSelectors.competitionSelectorKey,
                        selected: definition,
                        shortName: layout!.shortName,
                        onSelected: (id) =>
                            bloc.add(FixtureCompetitionChanged(id)),
                      ),
                    ),
                    if (hasSeason && seasonInBar) ...[
                      const SizedBox(width: AppSpacing.sm),
                      // La barra limita la escala del título a 1,34; la
                      // temporada es un control y usa la del sistema.
                      MediaQuery(
                        data: MediaQuery.of(context),
                        child: seasonSelector(compact: compact),
                      ),
                    ],
                  ],
                ),
          actions: [
            const TopBarTeamSearch(),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: switch (_view) {
                CompetitionsView.table =>
                  busy.standings ? null : () => _refreshStandings(context),
                CompetitionsView.calendar =>
                  busy.calendar ? null : () => _refreshCalendar(context),
                CompetitionsView.bracket =>
                  busy.bracket ? null : () => _refreshBracket(context),
                CompetitionsView.fixture =>
                  state.stage == null || state.isRefreshing
                      ? null
                      : () => _refreshFixture(context),
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Breakpoints.listWidth(context)),
          child: expanded && _view == CompetitionsView.fixture
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: content),
                    const VerticalDivider(width: AppSizes.divider),
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
  }

  /// Contenido de la vista abierta, debajo de la cabecera.
  Widget _viewContent(
    BuildContext context,
    CompetitionFixtureState state, {
    required bool expanded,
  }) => switch (_view) {
    CompetitionsView.table => StandingsPanel(
      tableKey: _tableKey,
      onTableSelected: _selectTable,
      onRefresh: () => _refreshStandings(context),
    ),
    CompetitionsView.calendar => CalendarPanel(
      month: _month,
      onMonthChanged: _selectMonth,
      onRefresh: () => _refreshCalendar(context),
    ),
    CompetitionsView.bracket => BracketPanel(
      phase: _bracketPhase,
      onPhaseSelected: _selectBracketPhase,
      onRefresh: () => _refreshBracket(context),
    ),
    CompetitionsView.fixture => LiveAutoRefresh(
      hasLiveMatches: () => _fixtureHasLiveMatches(context),
      onTick: () =>
          context.read<CompetitionFixtureBloc>().add(const FixtureLiveTick()),
      child: _FixtureContentView(
        state: state,
        selectedMatchId: expanded ? _selectedMatchId : null,
        // En escritorio el partido se abre en el panel; si no, en su
        // pantalla.
        onOpen: expanded
            ? (id) => setState(() => _selectedMatchId = id)
            : (id) => context.push(AppRoutes.matchDetail(id)),
      ),
    ),
  };
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

/// Actualiza las llaves y, si no hizo falta consultar la red, lo avisa.
Future<void> _refreshBracket(BuildContext context) async {
  final bloc = context.read<BracketBloc>()
    ..add(const BracketRefreshRequested());
  final after = await bloc.stream.firstWhere((s) => !s.isBusy);
  if (after case BracketLoaded(:final view)
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
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                    : '${state.stage!.label}: TheSportsDB todavía no tiene '
                          'los partidos cargados.',
              ),
            ],
          ),
        );

      case final FixtureLoaded loaded:
        final now = context.read<Clock>().now();
        return RefreshIndicator(
          onRefresh: () => _refreshFixture(context),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              if (loaded.isRefreshing) const LinearProgressIndicator(),
              if (loaded.refreshError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: StaleDataBanner(
                    fetchedAt: loaded.fetchedAt,
                    failure: loaded.refreshError!,
                    onRetry: retry,
                  ),
                ),
              if (loaded.matches.series.isNotEmpty)
                ...seriesItems(
                  series: loaded.matches.series,
                  unpaired: loaded.matches.unpaired,
                  now: now,
                  onTap: (m) => onOpen(m.id),
                  selectedId: selectedMatchId,
                )
              else
                ...matchDayItems(
                  matches: loaded.matches.matches,
                  now: now,
                  onTap: (m) => onOpen(m.id),
                  selectedId: selectedMatchId,
                ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
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
