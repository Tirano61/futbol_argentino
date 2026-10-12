part of 'history_probe_bloc.dart';

sealed class HistoryProbeEvent {
  const HistoryProbeEvent();
}

/// Completa la temporada de una competición.
final class HistoryProbeStarted extends HistoryProbeEvent {
  const HistoryProbeStarted({
    required this.competitionId,
    required this.season,
    this.forceRefresh = false,
  });

  final int competitionId;
  final Season season;

  /// Pide también las rondas vencidas cerradas o históricas.
  final bool forceRefresh;
}

/// Descarta las rondas que faltan (termina la que está en curso).
final class HistoryProbeCancelled extends HistoryProbeEvent {
  const HistoryProbeCancelled();
}

/// Relee las temporadas guardadas.
final class HistoryProbeSummaryRequested extends HistoryProbeEvent {
  const HistoryProbeSummaryRequested();
}
