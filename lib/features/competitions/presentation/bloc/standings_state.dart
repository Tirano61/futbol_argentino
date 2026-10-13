part of 'standings_bloc.dart';

sealed class StandingsState extends Equatable {
  const StandingsState();

  /// Se están descargando fechas.
  bool get isBusy => switch (this) {
    StandingsInitial() || StandingsLoading() => true,
    StandingsLoaded(:final view, :final isRefreshing) =>
      isRefreshing || view.progress.isRunning,
    StandingsUnavailable() || StandingsFailure() => false,
  };

  @override
  List<Object?> get props => [];
}

final class StandingsInitial extends StandingsState {
  const StandingsInitial();
}

/// Todavía no hay partidos guardados de la temporada.
final class StandingsLoading extends StandingsState {
  const StandingsLoading();
}

/// Hay tablas; se siguen completando mientras `view.progress.isRunning`.
final class StandingsLoaded extends StandingsState {
  const StandingsLoaded(this.view, {this.isRefreshing = false});

  final StandingsView view;

  /// Refresco manual en curso (hasta su primera emisión).
  final bool isRefreshing;

  @override
  List<Object?> get props => [view, isRefreshing];
}

/// La competición no tiene tablas verificadas en esa temporada.
final class StandingsUnavailable extends StandingsState {
  const StandingsUnavailable(this.view);

  final StandingsView view;

  @override
  List<Object?> get props => [view];
}

/// Sin partidos guardados y sin poder consultarlos.
final class StandingsFailure extends StandingsState {
  const StandingsFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
