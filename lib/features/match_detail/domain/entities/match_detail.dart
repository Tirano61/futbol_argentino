import 'package:equatable/equatable.dart';

import '../../../competitions/domain/entities/phase_assignment.dart';
import '../../../matches/domain/entities/match.dart';

/// Partido con su contexto de competición para el detalle.
final class MatchDetail extends Equatable {
  const MatchDetail({
    required this.match,
    required this.competitionName,
    this.phase,
    this.stageLabel,
  });

  final Match match;

  /// Nombre del catálogo (o el de la API si no está en el catálogo).
  final String competitionName;

  /// `null` si la competición no está en el catálogo.
  final PhaseAssignment? phase;

  /// «Fecha 12», «Cuartos de final», «Ronda 16»…
  final String? stageLabel;

  @override
  List<Object?> get props => [match, competitionName, phase, stageLabel];
}
