import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/widgets/match_day_list.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../matches/domain/repositories/match_repository.dart';
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

class _CompetitionsView extends StatelessWidget {
  const _CompetitionsView();

  @override
  Widget build(BuildContext context) {
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
        final bloc = context.read<CompetitionFixtureBloc>();
        return Scaffold(
          appBar: AppBar(
            title: Text(state.definition?.name ?? 'Competiciones'),
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                onPressed: state.stage == null || state.isRefreshing
                    ? null
                    : () => bloc.add(const FixtureRefreshRequested()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: FixtureSelectors(state: state),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: StageNavigator(state: state),
                  ),
                  Expanded(child: _FixtureContentView(state: state)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FixtureContentView extends StatelessWidget {
  const _FixtureContentView({required this.state});

  final CompetitionFixtureState state;

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<CompetitionFixtureBloc>()
      ..add(const FixtureRefreshRequested());
    await bloc.stream.firstWhere((s) => !s.isRefreshing);
  }

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

      case FixtureEmpty(:final refreshError, :final fetchedAt):
        return RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
          onRefresh: () => _refresh(context),
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
              ...matchDayItems(matches: loaded.matches.matches, now: now),
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
