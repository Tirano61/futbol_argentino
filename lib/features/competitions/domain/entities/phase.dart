/// Fase de una temporada.
enum PhaseKey {
  apertura('Apertura'),
  clausura('Clausura'),
  regular('Fase regular'),
  unica('Copa'),

  /// Copas internacionales: fases previas (Libertadores: Fases 1 a 3;
  /// Sudamericana: Primera fase).
  qualifying('Fases previas'),
  groups('Fase de grupos'),

  /// Copas internacionales: desde los playoffs u octavos hasta la final
  /// (no confundir con [StageKind.knockout], que también tienen las
  /// fases previas).
  knockoutStage('Eliminatorias'),

  /// No hay evidencia suficiente para ubicar el partido (D6).
  undetermined('Sin fase determinada');

  const PhaseKey(this.label);

  final String label;
}

/// Tipo de etapa dentro de una fase.
enum StageKind { regular, knockout }
