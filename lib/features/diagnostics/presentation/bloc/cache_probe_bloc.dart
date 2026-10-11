import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/data_result.dart';
import '../../../matches/domain/repositories/match_repository.dart';

part 'cache_probe_event.dart';
part 'cache_probe_state.dart';

/// Prueba de la caché (Fase 3): consulta una ronda con el repositorio real
/// y registra cada emisión (caché, red, error de actualización).
class CacheProbeBloc extends Bloc<CacheProbeEvent, CacheProbeState> {
  CacheProbeBloc(this._repository, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc()),
      super(const CacheProbeState()) {
    on<CacheProbeRequested>(_onRequested, transformer: droppable());
  }

  /// Primera División 2026, fecha 12 (Apertura y Clausura).
  static const query = RoundQuery(
    competitionId: 4406,
    season: '2026',
    apiRound: 12,
    expectedMinimum: 15,
  );

  final MatchRepository _repository;
  final DateTime Function() _now;

  Future<void> _onRequested(
    CacheProbeRequested event,
    Emitter<CacheProbeState> emit,
  ) async {
    final run = state.runs + 1;
    emit(state.copyWith(running: true, runs: run));
    try {
      await for (final result in _repository.watchRound(
        query,
        forceRefresh: event.forceRefresh,
      )) {
        emit(
          state.withEntry(
            CacheProbeEntry(
              run: run,
              forced: event.forceRefresh,
              receivedAt: _now(),
              origin: result.origin,
              fetchedAt: result.fetchedAt,
              count: result.data.length,
              error: result.refreshError,
            ),
          ),
        );
      }
    } on Failure catch (failure) {
      emit(
        state.withEntry(
          CacheProbeEntry(
            run: run,
            forced: event.forceRefresh,
            receivedAt: _now(),
            error: failure,
          ),
        ),
      );
    }
    emit(state.copyWith(running: false));
  }
}
