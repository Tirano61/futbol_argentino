import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/api_query_result.dart';
import '../../domain/repositories/diagnostics_repository.dart';

part 'api_test_event.dart';
part 'api_test_state.dart';

class ApiTestBloc extends Bloc<ApiTestEvent, ApiTestState> {
  ApiTestBloc(this._repository) : super(const ApiTestInitial()) {
    on<ApiQueryRequested>(_onQueryRequested);
  }

  // Primera Nacional de Argentina, fecha 33, temporada 2026.
  static const leagueId = 4616;
  static const round = 33;
  static const season = 2026;

  final DiagnosticsRepository _repository;

  Future<void> _onQueryRequested(
    ApiQueryRequested event,
    Emitter<ApiTestState> emit,
  ) async {
    emit(const ApiTestLoading());
    try {
      final result = await _repository.fetchRound(
        leagueId: leagueId,
        round: round,
        season: season,
      );
      debugPrint(
        'TheSportsDB OK: HTTP ${result.statusCode}, ${result.elapsedMs} ms, '
        '${result.matches.length} partidos',
      );
      emit(ApiTestSuccess(result));
    } on Failure catch (failure) {
      debugPrint('TheSportsDB ERROR $failure');
      emit(ApiTestFailure(failure));
    }
  }
}
