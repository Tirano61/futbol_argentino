import '../../../matches/domain/entities/team_ref.dart';
import '../entities/favorite_team.dart';
import '../repositories/favorites_repository.dart';

/// Agrega el equipo a favoritos o lo quita si ya estaba.
///
/// Consulta lo guardado (no lo que muestra la pantalla): dos toques
/// seguidos agregan y quitan aunque la lista todavía no se haya
/// actualizado.
class ToggleFavorite {
  const ToggleFavorite(this._favorites);

  final FavoritesRepository _favorites;

  /// Devuelve `true` si el equipo quedó como favorito.
  Future<bool> call(TeamRef team, {required DateTime now}) async {
    if (await _favorites.contains(team.id)) {
      await _favorites.remove(team.id);
      return false;
    }
    await _favorites.save(FavoriteTeam.fromRef(team, addedAt: now));
    return true;
  }
}
