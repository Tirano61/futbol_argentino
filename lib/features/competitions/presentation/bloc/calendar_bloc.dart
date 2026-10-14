import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/sync/cancel_token.dart';
import '../../../../core/time/clock.dart';
import '../../domain/entities/season.dart';
import '../../domain/usecases/watch_competition_calendar.dart';

part 'calendar_event.dart';
part 'calendar_state.dart';

/// Calendario de la competición y temporada elegidas.
///
/// Al abrirse muestra solo lo guardado (sin red); las rondas que faltan se
/// descargan cuando se pide («Completar» o «Actualizar»).
///
/// `restartable`: otra competición, temporada o un pedido reemplazan a la
/// carga en curso. Cada descarga tiene su [CancelToken]: al reemplazarla,
/// al cerrar la pantalla o al dejar de verse la vista se cancelan sus
/// fechas pendientes. Al volver a verse sigue con las que faltan.
class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  CalendarBloc({
    required WatchCompetitionCalendar watchCalendar,
    required Clock clock,
  }) : _watch = watchCalendar,
       _clock = clock,
       super(const CalendarInitial()) {
    on<CalendarLoadEvent>(_onLoad, transformer: restartable());
    // Aparte: pasar por `restartable` cancelaría la carga en curso aunque
    // no haya nada que pausar o retomar.
    on<CalendarPaused>(_onPaused);
    on<CalendarResumed>(_onResumed);
  }

  final WatchCompetitionCalendar _watch;
  final Clock _clock;
  ({int competitionId, Season season})? _target;
  CancelToken? _sync;

  /// Se pausó con la descarga a medias.
  bool _interrupted = false;

  /// Se pidió volver a leer lo guardado durante una carga: se hace al
  /// terminarla (cortarla para releer no sirve: la lectura dura poco y una
  /// descarga ya relee con cada fecha).
  bool _reloadWhenDone = false;

  void _onPaused(CalendarPaused event, Emitter<CalendarState> emit) {
    if (!state.isBusy) return;
    _interrupted = true;
    _sync?.cancel();
  }

  void _onResumed(CalendarResumed event, Emitter<CalendarState> emit) {
    if (_interrupted) {
      add(const _CalendarContinued());
    } else if (state.isBusy) {
      _reloadWhenDone = true;
    } else {
      // Otras vistas pudieron guardar partidos mientras no se veía.
      add(const _CalendarReloaded());
    }
  }

  Future<void> _onLoad(
    CalendarLoadEvent event,
    Emitter<CalendarState> emit,
  ) async {
    switch (event) {
      case CalendarStarted(:final competitionId, :final season):
        _target = (competitionId: competitionId, season: season);
        _reloadWhenDone = false;
        emit(const CalendarLoading());
      case CalendarCompletionRequested() || CalendarRefreshRequested():
        // Marca el pedido: si todo estaba al día, la emisión final es igual
        // a la anterior y sin esto no se notaría que terminó.
        if (state case CalendarLoaded(:final view)) {
          emit(CalendarLoaded(view, isRefreshing: true));
        }
      case _CalendarContinued() || _CalendarReloaded():
    }
    final target = _target;
    if (target == null) return;

    _interrupted = false;
    _sync?.cancel();
    final token = _sync = CancelToken();

    await emit.forEach<CompetitionCalendar>(
      _watch(
        target.competitionId,
        target.season,
        now: _clock.now(),
        cancelToken: token,
        download: switch (event) {
          CalendarCompletionRequested() ||
          CalendarRefreshRequested() ||
          _CalendarContinued() => true,
          CalendarStarted() || _CalendarReloaded() => false,
        },
        forceRefresh: event is CalendarRefreshRequested,
      ),
      onData: CalendarLoaded.new,
    );
    // Terminó sin que la reemplacen ni la pausen.
    if (_reloadWhenDone && token == _sync && !token.isCancelled) {
      _reloadWhenDone = false;
      add(const _CalendarReloaded());
    }
  }

  @override
  Future<void> close() {
    _sync?.cancel();
    return super.close();
  }
}
