part of 'home_favorites_bloc.dart';

sealed class HomeFavoritesEvent {
  const HomeFavoritesEvent();
}

/// Empieza a seguir los favoritos y sus partidos guardados.
final class HomeFavoritesStarted extends HomeFavoritesEvent {
  const HomeFavoritesStarted();
}
