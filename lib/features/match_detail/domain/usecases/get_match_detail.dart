import '../../../../core/error/failure.dart';
import '../../../../core/result/data_result.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/entities/phase.dart';
import '../../../competitions/domain/entities/phase_assignment.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../competitions/domain/knockout/knockout_bracket.dart';
import '../../../competitions/domain/services/phase_resolver.dart';
import '../../../competitions/domain/services/stage_labeler.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/tie_outcome.dart';
import '../entities/match_detail.dart';

/// Partido + fase y etapa. La fase necesita la ronda completa (consistencia
/// e inferencia), así que se usa la ronda guardada; si no hay ni red ni
/// caché para la ronda, se clasifica solo con el partido.
class GetMatchDetail {
  const GetMatchDetail(this._matches);

  final MatchRepository _matches;

  /// Lanza `Failure` si no hay datos guardados del partido y falla la red.
  Future<DataResult<MatchDetail>> call(
    int matchId, {
    bool forceRefresh = false,
  }) async {
    final result = await _matches.getMatch(matchId, forceRefresh: forceRefresh);
    final match = result.data;
    final definition = CompetitionCatalog.byId(match.competitionId);
    final season = Season.tryParse(match.season);
    if (definition == null || season == null) {
      return result.map(
        (m) => MatchDetail(match: m, competitionName: m.competitionName),
      );
    }

    final round = await _roundOf(match);
    final phase = PhaseResolver(definition).classifyRound(
      season: season,
      apiRound: match.apiRound,
      matches: round,
    )[match.id]!;
    final advancement = await _advancement(definition, season, match, phase);

    return result.map(
      (m) => MatchDetail(
        match: m,
        competitionName: definition.name,
        phase: phase,
        stageLabel: phase.isDetermined
            ? StageLabeler.label(
                definition,
                season,
                phase.phase,
                m.apiRound,
                phase.stageKind,
              )
            : 'Ronda ${m.apiRound}',
        advancement: advancement,
      ),
    );
  }

  /// Quién avanzó en un empate de eliminación: la tanda que informa la API
  /// o, si no la informa, el cuadro armado con lo guardado (el equipo que
  /// juega la ronda siguiente). Sin red.
  Future<TieOutcome?> _advancement(
    CompetitionDefinition definition,
    Season season,
    Match match,
    PhaseAssignment phase,
  ) async {
    final score = match.score;
    if (!phase.isDetermined ||
        phase.stageKind != StageKind.knockout ||
        !match.status.isFinished ||
        score == null ||
        score.home != score.away) {
      return null;
    }
    if (TieOutcome.of(match) case final outcome?) return outcome;

    final stored = await _matches.storedSeason(
      match.competitionId,
      match.season,
    );
    final bracket = KnockoutBracketBuilder.forSeason(
      definition: definition,
      season: season,
      matches: [
        for (final m in stored)
          if (m.id != match.id) m,
        match,
      ],
    )[phase.phase];
    for (final round in bracket?.rounds ?? const <BracketRoundView>[]) {
      for (final slot in round.slots) {
        if (slot.match?.id == match.id) return slot.outcome;
      }
    }
    return null;
  }

  Future<List<Match>> _roundOf(Match match) async {
    List<Match> round;
    try {
      // La primera emisión es la caché si existe (sin esperar refresco).
      final first = await _matches
          .watchRound(
            RoundQuery(
              competitionId: match.competitionId,
              season: match.season,
              apiRound: match.apiRound,
            ),
          )
          .first;
      round = first.data;
    } on Failure {
      round = const [];
    }
    return [
      for (final m in round)
        if (m.id != match.id) m,
      match,
    ];
  }
}
