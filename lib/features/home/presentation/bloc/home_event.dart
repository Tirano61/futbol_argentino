part of 'home_bloc.dart';

sealed class HomeEvent {
  const HomeEvent();
}

/// Carga inicial: lo guardado y, si venció, la red (prioridad P1).
final class HomeStarted extends HomeEvent {
  const HomeStarted();
}

/// Refresco manual (pull-to-refresh o botón): ignora la vigencia, P0.
final class HomeRefreshRequested extends HomeEvent {
  const HomeRefreshRequested();
}
