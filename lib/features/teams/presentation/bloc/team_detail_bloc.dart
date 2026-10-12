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
/// tiene su [CancelToken]: al reemplazarla o al cerrar la ficha se
/// cancelan sus rondas pendientes (la sincronización P2 se detiene).
class TeamDetailBloc extends Bloc<TeamDetailEvent, TeamDetailState> {
  TeamDetailBloc({
    required WatchTeamDetail watchTeamDetail,
    required Clock clock,
  }) : _watch = watchTeamDetail,
       _clock = clock,
       super(const TeamDetailInitial()) {
    on<TeamDetailEvent>(_onEvent, transformer: restartable());
  }

  final WatchTeamDetail _watch;
  final Clock _clock;
  int? _teamId;
  CancelToken? _sync;

  Future<void> _onEvent(
    TeamDetailEvent event,
    Emitter<TeamDetailState> emit,
  ) async {
    if (event case TeamDetailStarted(:final teamId)) _teamId = teamId;
    final teamId = _teamId;
    if (teamId == null) return;

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
