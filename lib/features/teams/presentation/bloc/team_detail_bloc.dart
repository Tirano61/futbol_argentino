import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/time/clock.dart';
import '../../domain/entities/team_detail.dart';
import '../../domain/usecases/watch_team_detail.dart';

part 'team_detail_event.dart';
part 'team_detail_state.dart';

/// Ficha de un equipo.
///
/// `restartable`: un refresco reemplaza a la carga en curso. Cada carga
/// tiene su [CancelToken]: al reemplazarla, al cerrar la ficha o al dejar
/// de verse se cancelan sus rondas pendientes (la sincronización P2 se
/// detiene). Al volver a verse sigue con las que faltan.
class TeamDetailBloc extends Bloc<TeamDetailEvent, TeamDetailState> {
  TeamDetailBloc({
    required WatchTeamDetail watchTeamDetail,
    required Clock clock,
  }) : _watch = watchTeamDetail,
       _clock = clock,
       super(const TeamDetailInitial()) {
    on<TeamDetailLoadEvent>(_onLoad, transformer: restartable());
    // Aparte: solo cancela la descarga, y la carga en curso termina sola.
    on<TeamDetailPaused>(_onPaused);
  }

  final WatchTeamDetail _watch;
  final Clock _clock;
  int? _teamId;
  CancelToken? _sync;

  /// Se pausó con la descarga a medias.
  bool _interrupted = false;

  void _onPaused(TeamDetailPaused event, Emitter<TeamDetailState> emit) {
    if (!state.isBusy) return;
    _interrupted = true;
    _sync?.cancel();
  }

  Future<void> _onLoad(
    TeamDetailLoadEvent event,
    Emitter<TeamDetailState> emit,
  ) async {
    switch (event) {
      case TeamDetailResumed() when !_interrupted:
        return;
      case TeamDetailStarted(:final teamId):
        _teamId = teamId;
      case TeamDetailResumed() || TeamDetailRefreshRequested():
    }
    final teamId = _teamId;
    if (teamId == null) return;

    _interrupted = false;
    _sync?.cancel();
    final token = _sync = CancelToken();
    if (state is! TeamDetailLoaded) emit(const TeamDetailLoading());

    await emit.forEach<TeamDetail>(
      _watch(
        teamId,
        now: _clock.now(),
        cancelToken: token,
        forceRefresh: event is TeamDetailRefreshRequested,
      ),
      onData: (detail) {
        if (detail.team != null) return TeamDetailLoaded(detail);
        if (detail.progress.isRunning) return const TeamDetailLoading();
        return TeamDetailFailure(
          detail.infoError ??
              NotFoundFailure(detail: 'Sin datos del equipo $teamId'),
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
