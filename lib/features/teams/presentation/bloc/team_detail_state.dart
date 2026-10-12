part of 'team_detail_bloc.dart';

sealed class TeamDetailState extends Equatable {
  const TeamDetailState();

  /// Se están descargando datos del equipo.
  bool get isBusy => switch (this) {
    TeamDetailInitial() || TeamDetailLoading() => true,
    TeamDetailLoaded(:final detail) => detail.progress.isRunning,
    TeamDetailFailure() => false,
  };

  @override
  List<Object?> get props => [];
}

final class TeamDetailInitial extends TeamDetailState {
  const TeamDetailInitial();
}

/// Todavía no se sabe nada del equipo.
final class TeamDetailLoading extends TeamDetailState {
  const TeamDetailLoading();
}

/// Hay datos del equipo; los partidos se siguen completando mientras
/// `detail.progress.isRunning`.
final class TeamDetailLoaded extends TeamDetailState {
  const TeamDetailLoaded(this.detail);

  final TeamDetail detail;

  @override
  List<Object?> get props => [detail];
}

/// Sin datos guardados del equipo y sin poder consultarlos.
final class TeamDetailFailure extends TeamDetailState {
  const TeamDetailFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
