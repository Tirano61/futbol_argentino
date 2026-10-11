import 'package:equatable/equatable.dart';

import 'phase.dart';

enum PhaseSource {
  /// Según las ventanas cargadas en el catálogo (datos verificados).
  catalog,

  /// Deducida de las fechas de la ronda (temporada sin catálogo).
  inferred,

  /// Sin evidencia suficiente.
  undetermined,
}

/// Fase y tipo de etapa de un partido, con la fuente de la decisión.
final class PhaseAssignment extends Equatable {
  const PhaseAssignment({
    required this.phase,
    required this.stageKind,
    required this.source,
  });

  const PhaseAssignment.undetermined()
    : phase = PhaseKey.undetermined,
      stageKind = StageKind.regular,
      source = PhaseSource.undetermined;

  final PhaseKey phase;
  final StageKind stageKind;
  final PhaseSource source;

  bool get isDetermined => source != PhaseSource.undetermined;

  @override
  List<Object?> get props => [phase, stageKind, source];
}
