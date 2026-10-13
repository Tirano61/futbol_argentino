import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/time/clock.dart';
import '../../domain/entities/season.dart';
import '../../domain/usecases/watch_standings.dart';

part 'standings_event.dart';
part 'standings_state.dart';

/// Tablas de la competición y temporada elegidas.
///
/// `restartable`: otra competición, temporada o un refresco reemplazan a la
/// carga en curso. Cada carga tiene su [CancelToken]: al reemplazarla, al
/// cerrar la pantalla o al dejar de verse la vista se cancelan sus fechas
/// pendientes. Al volver a verse sigue con las que faltan.
class StandingsBloc extends Bloc<StandingsEvent, StandingsState> {
  StandingsBloc({required WatchStandings watchStandings, required Clock clock})
    : _watch = watchStandings,
      _clock = clock,
      super(const StandingsInitial()) {
    on<StandingsLoadEvent>(_onLoad, transformer: restartable());
    // Aparte: pasar por `restartable` cancelaría la carga en curso aunque
    // no haya nada que pausar o retomar.
    on<StandingsPaused>(_onPaused);
    on<StandingsResumed>(_onResumed);
  }

  final WatchStandings _watch;
  final Clock _clock;
  ({int competitionId, Season season})? _target;
  CancelToken? _sync;

  /// Se pausó con la descarga a medias.
  bool _interrupted = false;

  void _onPaused(StandingsPaused event, Emitter<StandingsState> emit) {
    if (!state.isBusy) return;
    _interrupted = true;
    _sync?.cancel();
  }

  void _onResumed(StandingsResumed event, Emitter<StandingsState> emit) {
    if (_interrupted) add(const _StandingsContinued());
  }

  Future<void> _onLoad(
    StandingsLoadEvent event,
    Emitter<StandingsState> emit,
  ) async {
    switch (event) {
      case StandingsStarted(:final competitionId, :final season):
        _target = (competitionId: competitionId, season: season);
        emit(const StandingsLoading());
      case StandingsRefreshRequested():
        // Marca el refresco: si todo estaba al día, la emisión final es
        // igual a la anterior y sin esto no se notaría que terminó.
        if (state case StandingsLoaded(:final view)) {
          emit(StandingsLoaded(view, isRefreshing: true));
        }
      case _StandingsContinued():
    }
    final target = _target;
    if (target == null) return;

    _interrupted = false;
    _sync?.cancel();
    final token = _sync = CancelToken();

    await emit.forEach<StandingsView>(
      _watch(
        target.competitionId,
        target.season,
        now: _clock.now(),
        cancelToken: token,
        forceRefresh: event is StandingsRefreshRequested,
      ),
      onData: (view) {
        if (!view.isAvailable) return StandingsUnavailable(view);
        if (view.hasMatches) return StandingsLoaded(view);
        if (view.progress.isRunning) return const StandingsLoading();
        return StandingsFailure(
          view.progress.failure ??
              const NotFoundFailure(detail: 'Sin partidos de la temporada'),
        );
      },
    );
  }

  @override
  Future<void> close() {
    _sync?.cancel();
    return super.close();
  }
}
