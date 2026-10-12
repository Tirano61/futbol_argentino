import 'package:equatable/equatable.dart';

import '../error/failure.dart';

/// Avance de una descarga de rondas en segundo plano (P2): la ficha de un
/// equipo o una temporada completa.
final class SyncProgress extends Equatable {
  const SyncProgress({
    this.done = 0,
    this.total = 0,
    this.isRunning = true,
    this.failure,
    this.fetched = 0,
  });

  /// Rondas al día (vigentes, que no hace falta volver a pedir o recién
  /// descargadas).
  final int done;

  /// Rondas a revisar; `0` mientras todavía no se sabe cuáles son.
  final int total;
  final bool isRunning;

  /// La descarga se detuvo por este error (se muestran los guardados).
  final Failure? failure;

  /// Consultas a la red de esta carga; `0` si todo estaba al día.
  final int fetched;

  @override
  List<Object?> get props => [done, total, isRunning, failure, fetched];
}
