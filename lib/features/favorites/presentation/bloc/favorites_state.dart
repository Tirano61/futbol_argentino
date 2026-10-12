part of 'favorites_bloc.dart';

sealed class FavoritesState extends Equatable {
  const FavoritesState();

  /// Favoritos por nombre (vacío mientras carga).
  List<FavoriteTeam> get teams => const [];

  bool contains(int teamId) => teams.any((t) => t.teamId == teamId);

  @override
  List<Object?> get props => [];
}

/// Todavía no se leyó la base local.
final class FavoritesLoading extends FavoritesState {
  const FavoritesLoading();
}

final class FavoritesLoaded extends FavoritesState {
  const FavoritesLoaded(this.teams);

  @override
  final List<FavoriteTeam> teams;

  @override
  List<Object?> get props => [teams];
}
