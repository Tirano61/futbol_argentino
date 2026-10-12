import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase_assignment.dart';
import '../entities/season.dart';
import 'phase_resolver.dart';
import 'stage_labeler.dart';

/// Competición, fase y etapa visibles de un partido.
typedef MatchContextLabels = ({
  String competitionName,
  String? phase,
  String stage,
});

/// Etiquetas de partidos guardados sueltos (ficha de equipo, «Tus equipos»).
///
/// La fase se calcula con la ronda guardada completa (consistencia e
/// inferencia), sin red, y se recuerda por ronda.
final class StoredMatchLabeler {
  StoredMatchLabeler(
    this._matches, {
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _catalog = catalog;

  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;
  final _byRound = <RoundQuery, Map<int, PhaseAssignment>>{};

  /// Olvida la fase calculada de una ronda (se volvió a descargar).
  void invalidate(RoundQuery query) => _byRound.remove(query);

  /// [current]: temporada actual; de otra temporada, la competición lleva
  /// el año («Primera División 2025»).
  Future<MatchContextLabels> describe(
    Match m, {
    required Season current,
  }) async {
    final definition = _catalog
        .where((d) => d.id == m.competitionId)
        .firstOrNull;
    final season = Season.tryParse(m.season);
    if (definition == null || season == null) {
      return (
        competitionName: m.competitionName,
        phase: null,
        stage: 'Ronda ${m.apiRound}',
      );
    }

    final query = RoundQuery(
      competitionId: m.competitionId,
      season: m.season,
      apiRound: m.apiRound,
    );
    var assigned = _byRound[query];
    if (assigned == null || !assigned.containsKey(m.id)) {
      final round = await _matches.storedRound(query);
      assigned = _byRound[query] = PhaseResolver(definition).classifyRound(
        season: season,
        apiRound: m.apiRound,
        matches: [
          for (final r in round)
            if (r.id != m.id) r,
          m,
        ],
      );
    }
    final labels = StageLabeler.describe(
      definition,
      m.apiRound,
      assigned[m.id]!,
    );
    return (
      competitionName: season == current
          ? definition.name
          : '${definition.name} ${m.season}',
      phase: labels.phase,
      stage: labels.stage,
    );
  }
}
