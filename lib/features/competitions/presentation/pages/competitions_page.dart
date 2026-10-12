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
import '../../domain/repositories/competition_repository.dart';
import '../../domain/usecases/resolve_current_stage.dart';
import '../../domain/usecases/watch_stage_matches.dart';
import '../bloc/competition_fixture_bloc.dart';
import '../routing/fixture_route.dart';
import '../widgets/fixture_controls.dart';

/// Fixture reutilizable de cualquier competición del catálogo.
class CompetitionsPage extends StatelessWidget {
  const CompetitionsPage({super.key, required this.initialEvent});

  /// Selección inicial (de la URL o por defecto).
  final FixtureOpened initialEvent;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final competitions = context.read<CompetitionRepository>();
        return CompetitionFixtureBloc(
          watchStageMatches: WatchStageMatches(context.read<MatchRepository>()),
          resolveCurrentStage: ResolveCurrentStage(competitions),
          competitions: competitions,
          clock: context.read<Clock>(),
        )..add(initialEvent);
      },
      child: const _CompetitionsView(),
    );
  }
}

class _CompetitionsView extends StatefulWidget {
  const _CompetitionsView();

  @override
  State<_CompetitionsView> createState() => _CompetitionsViewState();
}

class _CompetitionsViewState extends State<_CompetitionsView> {
  /// Partido abierto en el panel de detalle (escritorio).
  int? _selectedMatchId;

  /// En Web: al volver a esta pantalla (de un partido o de otra sección),
  /// el router pone su ubicación, que no tiene la etapa.
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!kIsWeb) return;
    final router = GoRouter.maybeOf(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_restoreUrl);
    _router = router?..routerDelegate.addListener(_restoreUrl);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_restoreUrl);
    super.dispose();
  }

  void _restoreUrl() {
    final router = _router;
    if (router == null || !mounted) return;
    final uri = FixtureRoute.urlToRestore(
      // Incluye lo abierto con `push` (p. ej. un partido).
      router.state.uri,
      context.read<CompetitionFixtureBloc>().state.stage,
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
    return BlocConsumer<CompetitionFixtureBloc, CompetitionFixtureState>(
      listenWhen: (previous, current) => previous.stage != current.stage,
      listener: (context, state) {
        final stage = state.stage;
        // En Web, la URL refleja la etapa para poder compartirla. Se
        // reemplaza sin navegar (no recrea la pantalla).
        if (kIsWeb && stage != null) {
          SystemNavigator.routeInformationUpdated(
            uri: FixtureRoute.uriFor(stage),
            replace: true,
          );
        }
      },
      builder: (context, state) {
        final fixture = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: FixtureSelectors(state: state),
            ),
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
        );
        final selected = _selectedMatchId;

        return Scaffold(
          appBar: AppBar(
            title: Text(state.definition?.name ?? 'Competiciones'),
            actions: [
              const TopBarTeamSearch(),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: state.stage == null || state.isRefreshing
                    ? null
                    : () => _refreshFixture(context),
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
              child: expanded
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: fixture),
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
                  : fixture,
            ),
          ),
        );
      },
    );
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
