import 'package:equatable/equatable.dart';

import '../../../competitions/domain/entities/phase_assignment.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/services/tie_outcome.dart';

/// Partido con su contexto de competición para el detalle.
final class MatchDetail extends Equatable {
  const MatchDetail({
    required this.match,
    required this.competitionName,
    this.phase,
    this.stageLabel,
    this.advancement,
  });

  final Match match;

  /// Nombre del catálogo (o el de la API si no está en el catálogo).
  final String competitionName;

  /// `null` si la competición no está en el catálogo.
  final PhaseAssignment? phase;

  /// «Fecha 12», «Cuartos de final», «Ronda 16»…
  final String? stageLabel;

  /// Partido de eliminación terminado en empate (penales): quién avanzó,
  /// si se sabe. `null` en el resto (el marcador ya lo dice).
  final TieOutcome? advancement;

  @override
  List<Object?> get props => [
    match,
    competitionName,
    phase,
    stageLabel,
    advancement?.winner,
    advancement?.source,
  ];
}
