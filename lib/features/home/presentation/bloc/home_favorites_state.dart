part of 'home_favorites_bloc.dart';

sealed class HomeFavoritesState extends Equatable {
  const HomeFavoritesState();

  @override
  List<Object?> get props => [];
}

/// Todavía no se leyó lo guardado.
final class HomeFavoritesLoading extends HomeFavoritesState {
  const HomeFavoritesLoading();
}

final class HomeFavoritesLoaded extends HomeFavoritesState {
  const HomeFavoritesLoaded(this.teams);

  /// Favoritos por nombre; vacío si no hay ninguno.
  final List<FavoriteTeamOverview> teams;

  @override
  List<Object?> get props => [teams];
}

/// No se pudo leer lo guardado (falla de la base local).
final class HomeFavoritesUnavailable extends HomeFavoritesState {
  const HomeFavoritesUnavailable();
}
