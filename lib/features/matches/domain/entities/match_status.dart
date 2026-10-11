import 'package:equatable/equatable.dart';

enum MatchStatusKind {
  scheduled,
  live,
  halfTime,
  finished,
  postponed,
  cancelled,
  abandoned,
  suspended,
  unknown,
}

/// Cómo se definió un partido finalizado.
enum MatchDecision { regular, extraTime, penalties }

final class MatchStatus extends Equatable {
  const MatchStatus({
    required this.kind,
    this.decidedBy = MatchDecision.regular,
    this.raw,
  });

  const MatchStatus.scheduled()
    : kind = MatchStatusKind.scheduled,
      decidedBy = MatchDecision.regular,
      raw = null;

  final MatchStatusKind kind;
  final MatchDecision decidedBy;

  /// Código original de la API (`strStatus`), para depurar y para mostrar
  /// estados desconocidos tal cual.
  final String? raw;

  bool get isFinished => kind == MatchStatusKind.finished;
  bool get isInPlay =>
      kind == MatchStatusKind.live || kind == MatchStatusKind.halfTime;
  bool get isScheduled => kind == MatchStatusKind.scheduled;

  @override
  List<Object?> get props => [kind, decidedBy, raw];
}
