import '../../../../core/error/failure.dart';
import '../../../../core/result/data_result.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../competitions/domain/services/phase_resolver.dart';
import '../../../competitions/domain/services/stage_labeler.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
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

    return result.map(
      (m) => MatchDetail(
        match: m,
        competitionName: definition.name,
        phase: phase,
        stageLabel: phase.isDetermined
            ? StageLabeler.label(definition, m.apiRound, phase.stageKind)
            : 'Ronda ${m.apiRound}',
      ),
    );
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
