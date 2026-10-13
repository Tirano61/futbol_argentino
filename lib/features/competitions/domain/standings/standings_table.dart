import 'package:equatable/equatable.dart';

import '../../../matches/domain/entities/match.dart';
import 'tie_breaker.dart';

enum StandingsKind {
  /// Tabla de la temporada (Primera: Tabla General Anual).
  annual,

  /// Tabla de una zona de un torneo.
  zone,
}

/// Por qué un partido del alcance de la tabla no está sumado.
enum UncountedReason {
  /// Todavía no se jugó (o no llegó el resultado).
  notPlayed,

  /// En juego: se suma al terminar.
  inPlay,
  postponed,
  suspended,
  cancelled,

  /// Terminado según la API, pero sin resultado.
  noResult,

  /// No se pudo ubicar en un torneo (sin fase determinada): excluido.
  undetermined,
}

final class UncountedMatch extends Equatable {
  const UncountedMatch({required this.match, required this.reason});

  final Match match;
  final UncountedReason reason;

  @override
  List<Object?> get props => [match.id, reason];
}

/// Qué datos hay detrás de la tabla.
final class StandingsCoverage extends Equatable {
  const StandingsCoverage({
    required this.roundsQueried,
    required this.roundsTotal,
    required this.counted,
    required this.scheduled,
    this.uncounted = const [],
  });

  /// Fechas de la API guardadas («12 de 16 fechas consultadas»).
  final int roundsQueried;
  final int roundsTotal;

  /// Partidos sumados (terminados con resultado).
  final int counted;

  /// Partidos guardados del alcance de la tabla (sumados o no).
  final int scheduled;

  /// Partidos guardados que no se suman, con el motivo (los sin fase
  /// determinada no entran en [scheduled]).
  final List<UncountedMatch> uncounted;

  bool get isComplete =>
      roundsQueried == roundsTotal && counted == scheduled && uncounted.isEmpty;

  @override
  List<Object?> get props => [
    roundsQueried,
    roundsTotal,
    counted,
    scheduled,
    uncounted,
  ];
}

/// Tabla calculada por la app según el reglamento de la competición.
final class StandingsTable extends Equatable {
  const StandingsTable({
    required this.key,
    required this.title,
    required this.shortTitle,
    required this.kind,
    required this.rows,
    required this.coverage,
    required this.notes,
    this.sharedNote,
  });

  /// Identificador estable (`anual`, `apertura-a`…).
  final String key;

  /// «Tabla Anual 2026», «Apertura 2026 · Zona A».
  final String title;

  /// Para el selector: «Tabla Anual 2026», «Apertura · Zona A».
  final String shortTitle;
  final StandingsKind kind;
  final List<StandingsRow> rows;
  final StandingsCoverage coverage;

  /// Reglas con el artículo citado y aclaraciones (siempre visibles).
  final List<String> notes;

  /// Por qué hay posiciones compartidas, si las hay.
  final String? sharedNote;

  bool get hasSharedPositions => rows.any((r) => r.isShared);

  @override
  List<Object?> get props => [
    key,
    title,
    shortTitle,
    kind,
    rows,
    coverage,
    notes,
    sharedNote,
  ];
}
