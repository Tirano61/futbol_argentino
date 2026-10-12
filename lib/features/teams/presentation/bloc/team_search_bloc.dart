import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/time/clock.dart';
import '../../domain/entities/team_summary.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/services/team_index.dart';
import '../../domain/usecases/ensure_team_index.dart';
import '../../domain/usecases/search_teams_online.dart';

part 'team_search_event.dart';
part 'team_search_state.dart';

/// Buscador de equipos: índice local (sin red) y, si no encuentra nada,
/// búsqueda en línea.
///
/// Los cambios de búsqueda comparten un handler `restartable` con espera
/// ([debounce]): cada tecla cancela la búsqueda anterior, así una respuesta
/// en línea vieja nunca pisa a la nueva. La carga del índice va aparte y,
/// al terminar, repite la búsqueda actual.
class TeamSearchBloc extends Bloc<TeamSearchEvent, TeamSearchState> {
  TeamSearchBloc({
    required TeamRepository teams,
    required EnsureTeamIndex ensureIndex,
    required SearchTeamsOnline searchOnline,
    required Clock clock,
    this.debounce = const Duration(milliseconds: 350),
  }) : _teams = teams,
       _ensureIndex = ensureIndex,
       _searchOnline = searchOnline,
       _clock = clock,
       super(const TeamSearchState()) {
    on<TeamSearchStarted>(_onStarted, transformer: droppable());
    on<TeamSearchQueryEvent>(_onQuery, transformer: restartable());
  }

  final TeamRepository _teams;
  final EnsureTeamIndex _ensureIndex;
  final SearchTeamsOnline _searchOnline;
  final Clock _clock;
  final Duration debounce;

  var _index = TeamIndex(const []);

  /// La búsqueda actual espera el índice (estaba vacío).
  var _waitingForIndex = false;

  Future<void> _onStarted(
    TeamSearchStarted event,
    Emitter<TeamSearchState> emit,
  ) async {
    _index = TeamIndex(await _teams.storedTeams());
    emit(
      state.copyWith(
        indexSize: _index.length,
        isIndexing: true,
        query: event.initialQuery.trim().isEmpty ? null : event.initialQuery,
      ),
    );
    if (state.query.trim().isNotEmpty) add(const _TeamIndexChanged());

    final failure = await _ensureIndex(now: _clock.now());
    _index = TeamIndex(await _teams.storedTeams());
    emit(
      state.copyWith(
        indexSize: _index.length,
        isIndexing: false,
        indexFailure: () => failure,
      ),
    );
    // Se repite la búsqueda solo si el índice nuevo cambia el resultado:
    // así no se cancela ni se repite una búsqueda en línea en curso.
    final query = state.query;
    if (!isClosed &&
        query.trim().isNotEmpty &&
        (_waitingForIndex || _index.search(query).isNotEmpty)) {
      add(const _TeamIndexChanged());
    }
  }

  Future<void> _onQuery(
    TeamSearchQueryEvent event,
    Emitter<TeamSearchState> emit,
  ) async {
    switch (event) {
      case TeamSearchCleared():
        emit(state.copyWith(query: '', results: const TeamSearchIdle()));
        return;
      case TeamSearchQueryChanged(:final query):
        emit(state.copyWith(query: query));
        if (query.trim().isEmpty) {
          emit(state.copyWith(results: const TeamSearchIdle()));
          return;
        }
        // Debounce: si llega otra tecla antes, este handler se cancela.
        await Future<void>.delayed(debounce);
        if (emit.isDone) return;
      case _TeamIndexChanged():
        if (state.query.trim().isEmpty) return;
    }

    final query = state.query;
    final local = _index.search(query);
    _waitingForIndex = false;
    if (local.isNotEmpty) {
      emit(state.copyWith(results: TeamSearchFound(local)));
      return;
    }
    if (state.isIndexing && _index.isEmpty) {
      // Primera vez: se espera el índice (repite la búsqueda al terminar).
      _waitingForIndex = true;
      emit(state.copyWith(results: const TeamSearchSearching()));
      return;
    }
    if (!_searchOnline.accepts(query)) {
      emit(state.copyWith(results: const TeamSearchNoResults()));
      return;
    }

    emit(state.copyWith(results: const TeamSearchSearching()));
    try {
      final online = await _searchOnline(query);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          results: online.isEmpty
              ? const TeamSearchNoResults()
              : TeamSearchFound(online, isOnline: true),
        ),
      );
    } on Failure catch (failure) {
      if (emit.isDone) return;
      emit(
        state.copyWith(results: TeamSearchNoResults(onlineFailure: failure)),
      );
    }
  }
}
