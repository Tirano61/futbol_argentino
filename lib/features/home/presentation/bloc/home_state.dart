part of 'home_bloc.dart';

sealed class HomeState extends Equatable {
  const HomeState();

  /// Hay una carga en curso.
  bool get isBusy => switch (this) {
    HomeInitial() || HomeLoading() => true,
    HomeLoaded(:final feed) => feed.isLoading,
    HomeFailure() => false,
  };

  @override
  List<Object?> get props => [];
}

final class HomeInitial extends HomeState {
  const HomeInitial();
}

/// Todavía no hay nada para mostrar.
final class HomeLoading extends HomeState {
  const HomeLoading();
}

/// Hay datos de al menos una competición. Mientras `feed.isLoading`, se
/// siguen actualizando las demás.
final class HomeLoaded extends HomeState {
  const HomeLoaded(this.feed);

  final HomeFeed feed;

  @override
  List<Object?> get props => [feed];
}

/// Ninguna competición se pudo cargar y no hay nada guardado.
final class HomeFailure extends HomeState {
  const HomeFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
