import '../entities/knockout_tie.dart';
import '../entities/match.dart';
import 'match_grouping.dart';

/// Llaves de una etapa de eliminación y los partidos que no se pudieron
/// emparejar.
typedef TiePairs = ({List<KnockoutTie> ties, List<Match> unpaired});

/// Arma las llaves de una etapa: la API no tiene un id de serie, así que
/// las piernas son los partidos con el mismo par de equipos.
abstract final class TiePairing {
  /// [matches]: los partidos de una sola etapa. [legs]: 1 (partido único)
  /// o 2 (ida y vuelta).
  ///
  /// - Una serie con una sola pierna guardada queda como llave incompleta
  ///   (la otra todavía no está en la API).
  /// - Más de [legs] partidos con el mismo par de equipos: el dato no
  ///   cierra y esos partidos van a [TiePairs.unpaired] (nunca se elige
  ///   uno).
  /// - Llaves en el orden de su primera pierna.
  static TiePairs pair(Iterable<Match> matches, {required int legs}) {
    final sorted = MatchGrouping.dedupe(matches)..sort(byKickoff);
    if (legs <= 1) {
      return (
        ties: [for (final m in sorted) KnockoutTie.single(m)],
        unpaired: const <Match>[],
      );
    }
    final byPair = <(int, int), List<Match>>{};
    for (final m in sorted) {
      final key = m.home.id < m.away.id
          ? (m.home.id, m.away.id)
          : (m.away.id, m.home.id);
      (byPair[key] ??= []).add(m);
    }
    final ties = <KnockoutTie>[];
    final unpaired = <Match>[];
    for (final group in byPair.values) {
      if (group.length > legs) {
        unpaired.addAll(group);
      } else {
        ties.add(KnockoutTie(legs: group, expectedLegs: legs));
      }
    }
    ties.sort((a, b) => byKickoff(a.legs.first, b.legs.first));
    unpaired.sort(byKickoff);
    return (ties: ties, unpaired: unpaired);
  }

  /// Por horario (UTC; sin horario al final) y, a igualdad, por `idEvent`.
  static int byKickoff(Match a, Match b) {
    final x = a.kickoff.utc;
    final y = b.kickoff.utc;
    if (x != null && y != null && x != y) return x.compareTo(y);
    if (x == null && y != null) return 1;
    if (x != null && y == null) return -1;
    return a.id.compareTo(b.id);
  }
}
