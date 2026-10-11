import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/data_result.dart';
import '../../domain/entities/match_detail.dart';
import '../../domain/usecases/get_match_detail.dart';

part 'match_detail_event.dart';
part 'match_detail_state.dart';

class MatchDetailBloc extends Bloc<MatchDetailEvent, MatchDetailState> {
  MatchDetailBloc(this._getMatchDetail) : super(const MatchDetailInitial()) {
    on<MatchDetailEvent>(_onEvent, transformer: droppable());
  }

  final GetMatchDetail _getMatchDetail;
  int? _matchId;

  Future<void> _onEvent(
    MatchDetailEvent event,
    Emitter<MatchDetailState> emit,
  ) async {
    final forceRefresh = event is MatchDetailRefreshRequested;
    if (event case MatchDetailStarted(:final matchId)) _matchId = matchId;
    final matchId = _matchId;
    if (matchId == null) return;

    final current = state;
    emit(
      current is MatchDetailLoaded
          ? current.copyWith(isRefreshing: true)
          : const MatchDetailLoading(),
    );
    try {
      final result = await _getMatchDetail(matchId, forceRefresh: forceRefresh);
      emit(MatchDetailLoaded(result));
    } on Failure catch (failure) {
      emit(
        current is MatchDetailLoaded
            ? MatchDetailLoaded(
                DataResult(
                  data: current.result.data,
                  origin: DataOrigin.cache,
                  fetchedAt: current.result.fetchedAt,
                  refreshError: failure,
                ),
              )
            : MatchDetailFailure(failure),
      );
    }
  }
}
