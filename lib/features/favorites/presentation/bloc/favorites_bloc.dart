import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/time/clock.dart';
import '../../../matches/domain/entities/team_ref.dart';
import '../../domain/entities/favorite_team.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/usecases/toggle_favorite.dart';

part 'favorites_event.dart';
part 'favorites_state.dart';

/// Favoritos de toda la app (se crea una vez, arriba del router): la
/// estrella de cada pantalla y la lista de Favoritos leen este estado.
///
/// La suscripción a lo guardado va en su propio handler (`restartable`);
/// los toques, en otro `sequential`: uno por vez, en el orden en que se
/// hicieron.
class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  FavoritesBloc({required FavoritesRepository favorites, required Clock clock})
    : _favorites = favorites,
      _toggle = ToggleFavorite(favorites),
      _clock = clock,
      super(const FavoritesLoading()) {
    on<FavoritesSubscribed>(_onSubscribed, transformer: restartable());
    on<FavoriteToggled>(_onToggled, transformer: sequential());
  }

  final FavoritesRepository _favorites;
  final ToggleFavorite _toggle;
  final Clock _clock;

  Future<void> _onSubscribed(
    FavoritesSubscribed event,
    Emitter<FavoritesState> emit,
  ) => emit.forEach<List<FavoriteTeam>>(
    _favorites.watchAll(),
    onData: FavoritesLoaded.new,
  );

  Future<void> _onToggled(
    FavoriteToggled event,
    Emitter<FavoritesState> emit,
  ) async {
    // La lista se actualiza sola por la suscripción.
    await _toggle(event.team, now: _clock.now());
  }
}
