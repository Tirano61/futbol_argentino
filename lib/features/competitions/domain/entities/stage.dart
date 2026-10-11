import 'package:equatable/equatable.dart';

import 'phase.dart';
import 'season.dart';

/// Etapa navegable de una fase: «Fecha 12», «Octavos de final»…
///
/// Una etapa corresponde a una ronda de la API (`apiRound`) filtrada por
/// fase y tipo: en Primera, la ronda 16 contiene la «Fecha 16» del Apertura,
/// los octavos del Apertura y la «Fecha 16» del Clausura.
final class Stage extends Equatable {
  const Stage({
    required this.competitionId,
    required this.season,
    required this.phase,
    required this.apiRound,
    required this.kind,
    required this.label,
    required this.order,
  });

  final int competitionId;
  final Season season;
  final PhaseKey phase;
  final int apiRound;
  final StageKind kind;
  final String label;

  /// Posición dentro de la fase (para anterior/siguiente).
  final int order;

  @override
  List<Object?> get props => [competitionId, season, phase, apiRound, kind];

  @override
  String toString() =>
      'Stage($competitionId, $season, ${phase.name}, r$apiRound, '
      '${kind.name})';
}
