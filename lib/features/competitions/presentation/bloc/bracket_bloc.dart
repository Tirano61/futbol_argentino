import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/time/clock.dart';
import '../../domain/entities/season.dart';
import '../../domain/usecases/watch_knockout_bracket.dart';

part 'bracket_event.dart';
part 'bracket_state.dart';

/// Cuadro de llaves de la competición y temporada elegidas.
///
/// `restartable`: otra competición, temporada o un refresco reemplazan a la
/// carga en curso. Cada carga tiene su [CancelToken]: al reemplazarla, al
/// cerrar la pantalla o al dejar de verse la vista se cancelan sus rondas
/// pendientes. Al volver a verse sigue con las que faltan.
class BracketBloc extends Bloc<BracketEvent, BracketState> {
  BracketBloc({
    required WatchKnockoutBracket watchBracket,
    required Clock clock,
  }) : _watch = watchBracket,
       _clock = clock,
       super(const BracketInitial()) {
    on<BracketLoadEvent>(_onLoad, transformer: restartable());
    // Aparte: pasar por `restartable` cancelaría la carga en curso aunque
    // no haya nada que pausar o retomar.
    on<BracketPaused>(_onPaused);
    on<BracketResumed>(_onResumed);
  }

  final WatchKnockoutBracket _watch;
  final Clock _clock;
  ({int competitionId, Season season})? _target;
  CancelToken? _sync;

  /// Se pausó con la descarga a medias.
  bool _interrupted = false;

  void _onPaused(BracketPaused event, Emitter<BracketState> emit) {
    if (!state.isBusy) return;
    _interrupted = true;
    _sync?.cancel();
  }

  void _onResumed(BracketResumed event, Emitter<BracketState> emit) {
    if (_interrupted) add(const _BracketContinued());
  }

  Future<void> _onLoad(
    BracketLoadEvent event,
    Emitter<BracketState> emit,
  ) async {
    switch (event) {
      case BracketStarted(:final competitionId, :final season):
        _target = (competitionId: competitionId, season: season);
        emit(const BracketLoading());
      case BracketRefreshRequested():
        // Marca el refresco: si todo estaba al día, la emisión final es
        // igual a la anterior y sin esto no se notaría que terminó.
        if (state case BracketLoaded(:final view)) {
          emit(BracketLoaded(view, isRefreshing: true));
        }
      case _BracketContinued():
    }
    final target = _target;
    if (target == null) return;

    _interrupted = false;
    _sync?.cancel();
    final token = _sync = CancelToken();

    await emit.forEach<BracketView>(
      _watch(
        target.competitionId,
        target.season,
        now: _clock.now(),
        cancelToken: token,
        forceRefresh: event is BracketRefreshRequested,
      ),
      onData: (view) {
        if (!view.isAvailable) return BracketUnavailable(view);
        if (view.brackets.isNotEmpty) return BracketLoaded(view);
        if (view.progress.isRunning) return const BracketLoading();
        // Sin eliminatorias guardadas: es un estado válido (el Clausura
        // todavía no las jugó) salvo que no se haya podido consultar.
        final failure = view.progress.failure;
        return failure == null ? BracketLoaded(view) : BracketFailure(failure);
      },
    );
  }

  @override
  Future<void> close() {
    _sync?.cancel();
    return super.close();
  }
}
