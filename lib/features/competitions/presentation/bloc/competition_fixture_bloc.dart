import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/data_result.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/clock.dart';
import '../../domain/catalog/competition_catalog.dart';
import '../../domain/entities/phase.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/stage.dart';
import '../../domain/repositories/competition_repository.dart';
import '../../domain/services/round_navigator.dart';
import '../../domain/usecases/resolve_current_stage.dart';
import '../../domain/usecases/watch_stage_matches.dart';

part 'competition_fixture_event.dart';
part 'competition_fixture_state.dart';

/// Fixture de una competición: selección (competición, temporada, fase,
/// etapa) y partidos de la etapa elegida.
///
/// Todos los eventos pasan por un único handler `restartable`: una nueva
/// selección cancela la carga anterior, así una respuesta vieja nunca pisa
/// a la nueva (navegación rápida entre fechas).
class CompetitionFixtureBloc
    extends Bloc<CompetitionFixtureEvent, CompetitionFixtureState> {
  CompetitionFixtureBloc({
    required WatchStageMatches watchStageMatches,
    required ResolveCurrentStage resolveCurrentStage,
    required CompetitionRepository competitions,
    required Clock clock,
  }) : _watch = watchStageMatches,
       _resolveCurrentStage = resolveCurrentStage,
       _competitions = competitions,
       _clock = clock,
       super(const CompetitionFixtureState()) {
    on<CompetitionFixtureEvent>(_onEvent, transformer: restartable());
  }

  final WatchStageMatches _watch;
  final ResolveCurrentStage _resolveCurrentStage;
  final CompetitionRepository _competitions;
  final Clock _clock;

  Future<void> _onEvent(
    CompetitionFixtureEvent event,
    Emitter<CompetitionFixtureState> emit,
  ) async {
    switch (event) {
      case FixtureOpened():
        await _open(emit, event);
      case FixtureCompetitionChanged(:final competitionId):
        await _open(emit, FixtureOpened(competitionId: competitionId));
      case FixtureSeasonChanged(:final season):
        final definition = state.definition;
        if (definition == null) return;
        emit(state.copyWith(season: season, content: const FixtureLoading()));
        final stage = await _resolveCurrentStage(definition, season);
        await _select(emit, definition, season, stage);
      case FixturePhaseChanged(:final phase):
        final definition = state.definition;
        final season = state.season;
        if (definition == null || season == null) return;
        await _select(
          emit,
          definition,
          season,
          _stageForPhase(definition, season, phase),
        );
      case FixtureStageChanged(:final stage):
        await _selectStage(emit, stage);
      case FixtureNextStageRequested():
        final current = state.stage;
        final next = current == null
            ? null
            : RoundNavigator.next(state.stages, current);
        if (next != null) await _selectStage(emit, next);
      case FixturePreviousStageRequested():
        final current = state.stage;
        final previous = current == null
            ? null
            : RoundNavigator.previous(state.stages, current);
        if (previous != null) await _selectStage(emit, previous);
      case FixtureRefreshRequested():
        // También con la etapa vacía: la pantalla espera el fin del
        // refresco.
        switch (state.content) {
          case final FixtureLoaded content:
            emit(state.copyWith(content: content.copyWith(isRefreshing: true)));
          case final FixtureEmpty content:
            emit(state.copyWith(content: content.copyWith(isRefreshing: true)));
          case _:
        }
        await _load(emit, forceRefresh: true);
    }
  }

  Future<void> _open(
    Emitter<CompetitionFixtureState> emit,
    FixtureOpened event,
  ) async {
    final definition =
        CompetitionCatalog.byId(event.competitionId) ??
        CompetitionCatalog.primeraDivision;
    emit(
      CompetitionFixtureState(
        definition: definition,
        phases: definition.phases,
        content: const FixtureLoading(),
      ),
    );

    final current = await _currentSeason(definition);
    final seasons = CompetitionCatalog.supportedSeasons(current);
    final requested = event.season;
    final season = requested != null && seasons.contains(requested)
        ? requested
        : current;
    emit(state.copyWith(seasons: seasons, season: season));

    Stage? stage;
    final phase = event.phase;
    final apiRound = event.apiRound;
    if (phase != null && apiRound != null) {
      stage = phase == PhaseKey.undetermined
          ? _undeterminedStage(definition, season, apiRound)
          : RoundNavigator.stagesFor(definition, season, phase)
                .where(
                  (s) =>
                      s.apiRound == apiRound &&
                      s.kind == (event.kind ?? StageKind.regular),
                )
                .firstOrNull;
    }
    stage ??= await _resolveCurrentStage(definition, season);
    await _select(emit, definition, season, stage);
  }

  /// Temporada actual según la API; sin datos, el año argentino actual.
  Future<Season> _currentSeason(CompetitionDefinition definition) async {
    try {
      final result = await _competitions.getCompetition(definition.id);
      final season = result.data.currentSeason;
      if (season != null) return season;
    } on Failure {
      // Sin red ni caché: se usa el año actual.
    }
    return Season(ArgentinaTime.dayOf(_clock.now()).year);
  }

  Future<void> _select(
    Emitter<CompetitionFixtureState> emit,
    CompetitionDefinition definition,
    Season season,
    Stage? stage,
  ) async {
    if (stage == null) {
      emit(
        CompetitionFixtureState(
          definition: definition,
          seasons: state.seasons,
          season: season,
          phases: definition.phases,
          content: const FixtureEmpty(),
        ),
      );
      return;
    }
    final stages = stage.phase == PhaseKey.undetermined
        ? [stage]
        : RoundNavigator.stagesFor(
            definition,
            season,
            stage.phase,
            knownMaxRound: stage.apiRound,
          );
    emit(
      CompetitionFixtureState(
        definition: definition,
        seasons: state.seasons,
        season: season,
        phases: [
          ...definition.phases,
          if (stage.phase == PhaseKey.undetermined) PhaseKey.undetermined,
        ],
        stages: stages,
        stage: stage,
        content: const FixtureLoading(),
      ),
    );
    await _load(emit);
  }

  Future<void> _selectStage(
    Emitter<CompetitionFixtureState> emit,
    Stage stage,
  ) async {
    emit(
      state.copyWith(
        stage: stage,
        undeterminedInRound: 0,
        content: const FixtureLoading(),
      ),
    );
    await _load(emit);
  }

  Stage? _stageForPhase(
    CompetitionDefinition definition,
    Season season,
    PhaseKey phase,
  ) {
    final apiRound = state.stage?.apiRound;
    if (phase == PhaseKey.undetermined) {
      return apiRound == null
          ? null
          : _undeterminedStage(definition, season, apiRound);
    }
    final stages = RoundNavigator.stagesFor(definition, season, phase);
    // Misma fecha en la otra fase, si existe.
    return stages
            .where((s) => s.apiRound == apiRound && s.kind == state.stage?.kind)
            .firstOrNull ??
        stages.firstOrNull;
  }

  /// Partidos de una ronda de la API sin fase determinada.
  Stage _undeterminedStage(
    CompetitionDefinition definition,
    Season season,
    int apiRound,
  ) => Stage(
    competitionId: definition.id,
    season: season,
    phase: PhaseKey.undetermined,
    apiRound: apiRound,
    kind: StageKind.regular,
    label: 'Ronda $apiRound',
    order: 0,
  );

  Future<void> _load(
    Emitter<CompetitionFixtureState> emit, {
    bool forceRefresh = false,
  }) async {
    final definition = state.definition;
    final stage = state.stage;
    if (definition == null || stage == null) return;

    await emit.forEach<DataResult<StageMatches>>(
      _watch(definition, stage, forceRefresh: forceRefresh),
      onData: (result) {
        if (state.stage != stage) return state;
        final data = result.data;
        // Un refresco manual sigue en curso mientras solo llegó caché.
        final refreshing =
            forceRefresh &&
            result.origin == DataOrigin.cache &&
            result.refreshError == null;
        final FixtureContent content = data.matches.isEmpty
            ? FixtureEmpty(
                fetchedAt: result.fetchedAt,
                refreshError: result.refreshError,
                isRefreshing: refreshing,
              )
            : FixtureLoaded(
                matches: data,
                origin: result.origin,
                fetchedAt: result.fetchedAt,
                refreshError: result.refreshError,
                isRefreshing: refreshing,
              );
        return state.copyWith(
          content: content,
          undeterminedInRound: data.undeterminedInRound,
        );
      },
      onError: (error, stackTrace) {
        if (error is! Failure) Error.throwWithStackTrace(error, stackTrace);
        final content = state.content;
        return state.copyWith(
          content: switch (content) {
            FixtureLoaded() => FixtureLoaded(
              matches: content.matches,
              origin: content.origin,
              fetchedAt: content.fetchedAt,
              refreshError: error,
            ),
            // Una etapa vacía ya consultada sigue vacía, con el aviso.
            FixtureEmpty(:final fetchedAt?) => FixtureEmpty(
              fetchedAt: fetchedAt,
              refreshError: error,
            ),
            _ => FixtureFailure(error),
          },
        );
      },
    );

    switch (state.content) {
      case final FixtureLoaded content when content.isRefreshing:
        emit(state.copyWith(content: content.copyWith(isRefreshing: false)));
      case final FixtureEmpty content when content.isRefreshing:
        emit(state.copyWith(content: content.copyWith(isRefreshing: false)));
      case _:
    }

    final next = RoundNavigator.next(state.stages, stage);
    if (next != null) unawaited(_watch.prefetch(definition, next));
  }
}
