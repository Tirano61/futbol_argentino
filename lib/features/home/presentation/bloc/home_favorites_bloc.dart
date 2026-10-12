import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/time/clock.dart';
import '../../domain/entities/favorite_team_overview.dart';
import '../../domain/usecases/watch_favorite_teams.dart';

part 'home_favorites_event.dart';
part 'home_favorites_state.dart';

/// «Tus equipos» del Inicio. Va aparte del `HomeBloc`: no hace peticiones
/// y se actualiza solo (favoritos o partidos guardados nuevos).
class HomeFavoritesBloc extends Bloc<HomeFavoritesEvent, HomeFavoritesState> {
  HomeFavoritesBloc({
    required WatchFavoriteTeams watchFavoriteTeams,
    required Clock clock,
  }) : _watchFavoriteTeams = watchFavoriteTeams,
       _clock = clock,
       super(const HomeFavoritesLoading()) {
    on<HomeFavoritesStarted>(_onStarted, transformer: restartable());
  }

  final WatchFavoriteTeams _watchFavoriteTeams;
  final Clock _clock;

  Future<void> _onStarted(
    HomeFavoritesStarted event,
    Emitter<HomeFavoritesState> emit,
  ) => emit.forEach<List<FavoriteTeamOverview>>(
    _watchFavoriteTeams(now: _clock.now),
    onData: HomeFavoritesLoaded.new,
    // El Inicio espera esta sección: un error no puede dejarlo cargando.
    onError: (error, stackTrace) => const HomeFavoritesUnavailable(),
  );
}
