import '../entities/knockout_tie.dart';
import '../entities/match.dart';
import '../entities/match_status.dart';
import '../entities/team_ref.dart';

/// De dónde sale quién avanzó en un partido de eliminación.
enum TieOutcomeSource {
  /// Ganó en los 90 minutos o en el alargue.
  score,

  /// Ganó la tanda de penales que informa la API.
  penalties,

  /// La API no informa cómo terminó la llave, pero solo uno de los dos
  /// equipos juega un partido posterior de la misma eliminatoria.
  laterMatch,

  /// Serie de ida y vuelta: hizo más goles en el global.
  aggregate,
}

/// Quién avanzó en una llave de eliminación: un partido único o una serie
/// de ida y vuelta.
final class TieOutcome {
  const TieOutcome({required this.winner, required this.source});

  final TeamRef winner;
  final TieOutcomeSource source;

  /// Ganador de [m], o `null` si no hay evidencia.
  ///
  /// [laterMatches]: partidos de la misma eliminatoria posteriores a [m]
  /// (se usan solo si el resultado no alcanza: un empate sin la tanda, como
  /// los 32avos de la Copa 2026). Nunca se adivina: si ninguno de los dos
  /// equipos (o los dos) aparece después, no hay ganador.
  static TieOutcome? of(Match m, {Iterable<Match> laterMatches = const []}) {
    if (!m.status.isFinished) return null;
    final score = m.score;
    if (score != null && score.home != score.away) {
      return TieOutcome(
        winner: score.home > score.away ? m.home : m.away,
        source: TieOutcomeSource.score,
      );
    }
    final penalties = m.penalties;
    if (m.status.decidedBy == MatchDecision.penalties &&
        penalties != null &&
        penalties.home != penalties.away) {
      return TieOutcome(
        winner: penalties.home > penalties.away ? m.home : m.away,
        source: TieOutcomeSource.penalties,
      );
    }

    bool playsLater(TeamRef team) => laterMatches.any(
      (later) => later.id != m.id && later.involvesTeam(team.id),
    );
    final home = playsLater(m.home);
    final away = playsLater(m.away);
    if (home == away) return null;
    return TieOutcome(
      winner: home ? m.home : m.away,
      source: TieOutcomeSource.laterMatch,
    );
  }

  /// Ganador de [tie], o `null` si no hay evidencia.
  ///
  /// Un partido único sigue exactamente [of]. En una serie de ida y
  /// vuelta (reglamentos CONMEBOL: global y, si persiste, penales; sin
  /// alargue ni gol de visitante):
  /// 1. Global distinto → [TieOutcomeSource.aggregate].
  /// 2. Global igual → la tanda de la vuelta, si es `PEN` y la API la
  ///    informa sin empate.
  /// 3. Si no, el único de los dos que juega un partido de [laterMatches]
  ///    posterior a la serie (2025 no informa los penales; la
  ///    Sudamericana 2026 a veces da `PEN` sin la tanda).
  ///
  /// Un dato contradictorio (`PEN` en la ida, o en la vuelta con el global
  /// distinto) no usa ni el global ni la tanda: solo el paso 3.
  static TieOutcome? ofTie(
    KnockoutTie tie, {
    Iterable<Match> laterMatches = const [],
  }) {
    if (!tie.isSeries) return of(tie.decisive, laterMatches: laterMatches);
    if (!tie.legs.every((m) => m.status.isFinished)) return null;

    bool byPenalties(Match m) => m.status.decidedBy == MatchDecision.penalties;
    final contradictoryLeg = tie.legs
        .take(tie.legs.length - 1)
        .any(byPenalties);
    final aggregate = tie.aggregate;
    if (aggregate != null && !contradictoryLeg) {
      final shootout = byPenalties(tie.decisive);
      if (aggregate.home != aggregate.away) {
        if (!shootout) {
          return TieOutcome(
            winner: aggregate.home > aggregate.away ? tie.first : tie.second,
            source: TieOutcomeSource.aggregate,
          );
        }
      } else if (shootout) {
        final p = tie.penalties;
        if (p != null && p.home != p.away) {
          return TieOutcome(
            winner: p.home > p.away ? tie.first : tie.second,
            source: TieOutcomeSource.penalties,
          );
        }
      }
    }

    final later = laterMatches.where(tie.isBefore);
    bool playsLater(TeamRef team) => later.any((m) => m.involvesTeam(team.id));
    final first = playsLater(tie.first);
    final second = playsLater(tie.second);
    if (first == second) return null;
    return TieOutcome(
      winner: first ? tie.first : tie.second,
      source: TieOutcomeSource.laterMatch,
    );
  }
}
