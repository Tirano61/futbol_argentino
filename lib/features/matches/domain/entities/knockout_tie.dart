import 'package:equatable/equatable.dart';

import 'match.dart';
import 'score.dart';
import 'team_ref.dart';

/// Llave de eliminación: un partido único o una serie de ida y vuelta.
///
/// La API no tiene un id de serie: las piernas se emparejan por los dos
/// equipos dentro de la etapa (ver `TiePairing`).
final class KnockoutTie extends Equatable {
  /// [legs] en orden cronológico (la primera es la ida), al menos una.
  KnockoutTie({required this.legs, required this.expectedLegs})
    : assert(legs.isNotEmpty);

  /// Llave de un solo partido.
  KnockoutTie.single(Match match) : legs = [match], expectedLegs = 1;

  final List<Match> legs;

  /// 1: partido único; 2: ida y vuelta.
  final int expectedLegs;

  /// Local de la ida: el primero de la llave en el cuadro y en el global.
  TeamRef get first => legs.first.home;
  TeamRef get second => legs.first.away;

  bool get isSeries => expectedLegs > 1;

  /// Están todas las piernas y terminaron.
  bool get isComplete =>
      legs.length == expectedLegs && legs.every((m) => m.status.isFinished);

  /// La pierna que define la llave (la vuelta, o el partido único).
  Match get decisive => legs.last;

  /// La pierna que conviene abrir: la primera que no terminó, o la última.
  Match get current =>
      legs.where((m) => !m.status.isFinished).firstOrNull ?? legs.last;

  bool involvesTeam(int teamId) => legs.first.involvesTeam(teamId);

  /// Goles de [leg] en el orden de la llave ([first], [second]); `null` si
  /// la pierna no empezó o no tiene marcador.
  Score? scoreOf(Match leg) {
    final score = leg.score;
    if (score == null || !(leg.status.isFinished || leg.status.isInPlay)) {
      return null;
    }
    return leg.home.id == first.id
        ? score
        : Score(home: score.away, away: score.home);
  }

  /// Tanda de [decisive] en el orden de la llave, si la API la informa.
  Score? get penalties {
    final p = decisive.penalties;
    if (p == null) return null;
    return decisive.home.id == first.id ? p : Score(home: p.away, away: p.home);
  }

  /// Suma de las piernas que empezaron, en el orden de la llave; `null` si
  /// ninguna empezó.
  Score? get partialAggregate {
    Score? total;
    for (final leg in legs) {
      final s = scoreOf(leg);
      if (s == null) continue;
      total = Score(
        home: (total?.home ?? 0) + s.home,
        away: (total?.away ?? 0) + s.away,
      );
    }
    return total;
  }

  /// Resultado global, solo si la llave está completa ([isComplete]) y
  /// todas las piernas tienen marcador.
  Score? get aggregate => isComplete && legs.every((m) => m.score != null)
      ? partialAggregate
      : null;

  /// [m] se juega después de la llave: con horario conocido, posterior al
  /// inicio de [decisive] (para la evidencia de quién avanzó).
  bool isBefore(Match m) {
    final end = decisive.kickoff.utc;
    final start = m.kickoff.utc;
    return end != null &&
        start != null &&
        start.isAfter(end) &&
        !legs.any((leg) => leg.id == m.id);
  }

  @override
  List<Object?> get props => [legs, expectedLegs];
}
