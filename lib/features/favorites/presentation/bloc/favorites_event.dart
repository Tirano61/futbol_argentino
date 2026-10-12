part of 'favorites_bloc.dart';

sealed class FavoritesEvent {
  const FavoritesEvent();
}

/// Empieza a seguir los favoritos guardados (al abrir la app).
final class FavoritesSubscribed extends FavoritesEvent {
  const FavoritesSubscribed();
}

/// Agrega el equipo a favoritos o lo quita si ya estaba.
final class FavoriteToggled extends FavoritesEvent {
  const FavoriteToggled(this.team);

  final TeamRef team;
}
