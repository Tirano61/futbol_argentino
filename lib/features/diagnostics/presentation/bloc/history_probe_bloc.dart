import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/sync/cancel_token.dart';
import '../../../../core/time/clock.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../competitions/domain/entities/season_completion.dart';
import '../../../competitions/domain/usecases/complete_rounds.dart';
import '../../../matches/domain/repositories/match_repository.dart';

part 'history_probe_event.dart';
part 'history_probe_state.dart';

/// Prueba del historial a pedido (Fase 12): completa una temporada con
/// [CompleteRounds] (P2), muestra el estado de cada ronda y las temporadas
/// guardadas.
class HistoryProbeBloc extends Bloc<HistoryProbeEvent, HistoryProbeState> {
  HistoryProbeBloc({
    required CompleteRounds completeRounds,
    required MatchRepository matches,
    required Clock clock,
  }) : _completeRounds = completeRounds,
       _matches = matches,
       _clock = clock,
       super(const HistoryProbeState()) {
    on<HistoryProbeStarted>(_onStarted, transformer: restartable());
    // Aparte: si pasara por `restartable`, esperaría a que termine la
    // carga en curso.
    on<HistoryProbeCancelled>(_onCancelled);
    on<HistoryProbeSummaryRequested>(_onSummary);
  }

  final CompleteRounds _completeRounds;
  final MatchRepository _matches;
  final Clock _clock;
  CancelToken? _token;

  Future<void> _onStarted(
    HistoryProbeStarted event,
    Emitter<HistoryProbeState> emit,
  ) async {
    _token?.cancel();
    final token = _token = CancelToken();
    emit(
      HistoryProbeState(
        competitionId: event.competitionId,
        season: event.season,
        forced: event.forceRefresh,
        running: true,
        summaries: state.summaries,
      ),
    );
    await emit.forEach<SeasonCompletion>(
      _completeRounds(
        event.competitionId,
        event.season,
        now: _clock.now(),
        cancelToken: token,
        forceRefresh: event.forceRefresh,
      ),
      onData: (c) => state.copyWith(completion: c, running: true),
    );
    emit(
      state.copyWith(
        running: false,
        cancelled: token.isCancelled,
        summaries: await _matches.storedSeasons(),
      ),
    );
  }

  void _onCancelled(
    HistoryProbeCancelled event,
    Emitter<HistoryProbeState> emit,
  ) => _token?.cancel();

  Future<void> _onSummary(
    HistoryProbeSummaryRequested event,
    Emitter<HistoryProbeState> emit,
  ) async => emit(state.copyWith(summaries: await _matches.storedSeasons()));

  @override
  Future<void> close() {
    _token?.cancel();
    return super.close();
  }
}
