import '../entities/favorite_team.dart';

/// Equipos favoritos, guardados solo en este dispositivo (sin red).
///
/// A diferencia de los repositorios de datos de la API, no devuelve
/// `DataResult`: los datos son siempre locales y no tienen vigencia.
abstract interface class FavoritesRepository {
  /// Favoritos por nombre; emite enseguida y cada vez que cambian.
  Stream<List<FavoriteTeam>> watchAll();

  Future<bool> contains(int teamId);

  /// Agrega el equipo o actualiza su nombre y escudo.
  Future<void> save(FavoriteTeam team);

  Future<void> remove(int teamId);
}
