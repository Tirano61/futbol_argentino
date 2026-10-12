part of 'history_probe_bloc.dart';

final class HistoryProbeState {
  const HistoryProbeState({
    this.competitionId,
    this.season,
    this.forced = false,
    this.completion,
    this.running = false,
    this.cancelled = false,
    this.summaries = const [],
  });

  /// Última temporada pedida.
  final int? competitionId;
  final Season? season;
  final bool forced;
  final SeasonCompletion? completion;
  final bool running;
  final bool cancelled;

  /// Temporadas guardadas, por competición.
  final List<StoredSeasonSummary> summaries;

  HistoryProbeState copyWith({
    SeasonCompletion? completion,
    bool? running,
    bool? cancelled,
    List<StoredSeasonSummary>? summaries,
  }) => HistoryProbeState(
    competitionId: competitionId,
    season: season,
    forced: forced,
    completion: completion ?? this.completion,
    running: running ?? this.running,
    cancelled: cancelled ?? this.cancelled,
    summaries: summaries ?? this.summaries,
  );
}
