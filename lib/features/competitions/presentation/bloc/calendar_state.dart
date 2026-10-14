part of 'calendar_bloc.dart';

sealed class CalendarState extends Equatable {
  const CalendarState();

  /// Se está leyendo lo guardado o descargando fechas.
  bool get isBusy => switch (this) {
    CalendarInitial() || CalendarLoading() => true,
    CalendarLoaded(:final view, :final isRefreshing) =>
      isRefreshing || view.progress.isRunning,
  };

  @override
  List<Object?> get props => [];
}

final class CalendarInitial extends CalendarState {
  const CalendarInitial();
}

/// Leyendo lo guardado.
final class CalendarLoading extends CalendarState {
  const CalendarLoading();
}

/// Lo guardado; se sigue completando mientras `view.progress.isRunning`.
final class CalendarLoaded extends CalendarState {
  const CalendarLoaded(this.view, {this.isRefreshing = false});

  final CompetitionCalendar view;

  /// Pedido en curso («Completar» o «Actualizar»), hasta su primera
  /// emisión.
  final bool isRefreshing;

  @override
  List<Object?> get props => [view, isRefreshing];
}
