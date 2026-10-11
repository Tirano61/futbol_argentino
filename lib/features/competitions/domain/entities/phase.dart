/// Fase de una temporada.
enum PhaseKey {
  apertura('Apertura'),
  clausura('Clausura'),
  regular('Fase regular'),
  unica('Copa'),

  /// No hay evidencia suficiente para ubicar el partido (D6).
  undetermined('Sin fase determinada');

  const PhaseKey(this.label);

  final String label;
}

/// Tipo de etapa dentro de una fase.
enum StageKind { regular, knockout }
