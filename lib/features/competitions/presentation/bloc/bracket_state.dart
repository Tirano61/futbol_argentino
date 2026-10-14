part of 'bracket_bloc.dart';

sealed class BracketState extends Equatable {
  const BracketState();

  /// Se están descargando rondas.
  bool get isBusy => switch (this) {
    BracketInitial() || BracketLoading() => true,
    BracketLoaded(:final view, :final isRefreshing) =>
      isRefreshing || view.progress.isRunning,
    BracketUnavailable() || BracketFailure() => false,
  };

  @override
  List<Object?> get props => [];
}

final class BracketInitial extends BracketState {
  const BracketInitial();
}

/// Todavía no hay partidos de eliminatoria guardados.
final class BracketLoading extends BracketState {
  const BracketLoading();
}

/// Cuadros de las fases con eliminatorias guardadas (puede no haber
/// ninguna); se siguen completando mientras `view.progress.isRunning`.
final class BracketLoaded extends BracketState {
  const BracketLoaded(this.view, {this.isRefreshing = false});

  final BracketView view;

  /// Refresco manual en curso (hasta su primera emisión).
  final bool isRefreshing;

  @override
  List<Object?> get props => [view, isRefreshing];
}

/// La competición no tiene un cuadro verificado.
final class BracketUnavailable extends BracketState {
  const BracketUnavailable(this.view);

  final BracketView view;

  @override
  List<Object?> get props => [view];
}

/// Sin partidos guardados y sin poder consultarlos.
final class BracketFailure extends BracketState {
  const BracketFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
