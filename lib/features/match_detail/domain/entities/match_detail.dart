import 'package:equatable/equatable.dart';

import '../../../competitions/domain/entities/phase_assignment.dart';
import '../../../matches/domain/entities/knockout_tie.dart';
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
    this.tie,
  });

  final Match match;

  /// Nombre del catálogo (o el de la API si no está en el catálogo).
  final String competitionName;

  /// `null` si la competición no está en el catálogo.
  final PhaseAssignment? phase;

  /// «Fecha 12», «Cuartos de final», «Ronda 16»…
  final String? stageLabel;

  /// Partido de eliminación terminado en empate (penales): quién avanzó,
  /// si se sabe. `null` en el resto (el marcador ya lo dice). En una copa
  /// internacional, quién avanzó en la llave ([tie]), aunque esta pierna
  /// no haya terminado empatada.
  final TieOutcome? advancement;

  /// Llave de eliminación de una copa internacional (Fase D5): el partido
  /// único o la serie de ida y vuelta con las piernas guardadas. `null` en
  /// el resto.
  final KnockoutTie? tie;

  @override
  List<Object?> get props => [
    match,
    competitionName,
    phase,
    stageLabel,
    advancement?.winner,
    advancement?.source,
    tie,
  ];
}
