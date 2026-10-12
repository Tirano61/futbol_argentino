import 'package:equatable/equatable.dart';

import '../../../../core/sync/sync_progress.dart';
import '../../../matches/domain/entities/match.dart';
import 'season.dart';

/// Qué pasa con una ronda al completar una temporada.
enum RoundCompletionStatus {
  /// No está guardada: se pide.
  missing,

  /// Guardada y vencida, y todavía puede cambiar: se pide.
  stale,

  /// Guardada y vigente: no se pide.
  fresh,

  /// Cerrada (todo terminado y con resultado): venció, pero no se vuelve a
  /// pedir salvo con un refresco manual.
  settled,

  /// De una temporada anterior ya terminada, guardada y completa: no se
  /// vuelve a pedir salvo con un refresco manual.
  historic,

  /// Se descargó en esta carga.
  fetched;

  bool get needsFetch => this == missing || this == stale;
}

final class SeasonRound extends Equatable {
  const SeasonRound({required this.apiRound, required this.status});

  final int apiRound;
  final RoundCompletionStatus status;

  @override
  List<Object?> get props => [apiRound, status];
}

/// Una temporada de una competición a medida que se completa: lo guardado,
/// el estado de cada ronda y el avance de la descarga.
final class SeasonCompletion extends Equatable {
  const SeasonCompletion({
    required this.competitionId,
    required this.season,
    required this.matches,
    required this.rounds,
    required this.progress,
  });

  final int competitionId;
  final Season season;

  /// Partidos visibles guardados de la temporada (todas sus rondas).
  final List<Match> matches;

  /// En el orden en que se revisan.
  final List<SeasonRound> rounds;
  final SyncProgress progress;

  @override
  List<Object?> get props => [competitionId, season, matches, rounds, progress];
}
